-- Per-order earnings tracking for farmers and riders
CREATE TABLE earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL CHECK (role IN ('farmer', 'rider')),
  order_id UUID NOT NULL REFERENCES orders(id),
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'settled', 'disputed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at TIMESTAMPTZ,
  settled_by UUID REFERENCES auth.users(id)
);

CREATE INDEX earnings_user_status_idx ON earnings (user_id, status);
CREATE UNIQUE INDEX earnings_order_user_role_idx ON earnings (order_id, user_id, role);

-- Withdrawal requests
CREATE TABLE payout_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  method TEXT NOT NULL CHECK (method IN ('esewa', 'khalti', 'bank')),
  account_details JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'rejected')),
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  processed_by UUID REFERENCES auth.users(id)
);

CREATE INDEX payout_requests_user_idx ON payout_requests (user_id, status);
CREATE INDEX payout_requests_pending_idx ON payout_requests (status, created_at)
  WHERE status IN ('pending', 'processing');

-- RLS
ALTER TABLE earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own earnings"
  ON earnings FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role full access on earnings"
  ON earnings FOR ALL USING (current_setting('role') = 'service_role');

CREATE POLICY "Users can view own payout requests"
  ON payout_requests FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own payout requests"
  ON payout_requests FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on payout_requests"
  ON payout_requests FOR ALL USING (current_setting('role') = 'service_role');

-- Auto-create earnings when order is delivered
CREATE OR REPLACE FUNCTION create_earnings_on_delivery()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    -- Farmer earnings: sum of subtotals per farmer
    INSERT INTO earnings (user_id, role, order_id, amount)
    SELECT oi.farmer_id, 'farmer', NEW.id, SUM(oi.subtotal)
    FROM order_items oi
    WHERE oi.order_id = NEW.id
    GROUP BY oi.farmer_id
    ON CONFLICT (order_id, user_id, role) DO NOTHING;

    -- Rider earnings: delivery fee
    IF NEW.rider_id IS NOT NULL AND COALESCE(NEW.delivery_fee, 0) > 0 THEN
      INSERT INTO earnings (user_id, role, order_id, amount)
      VALUES (NEW.rider_id, 'rider', NEW.id, NEW.delivery_fee)
      ON CONFLICT (order_id, user_id, role) DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_earnings_on_delivery
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION create_earnings_on_delivery();
