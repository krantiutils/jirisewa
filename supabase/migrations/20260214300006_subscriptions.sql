-- Subscription boxes: weekly recurring produce delivery
-- Enables consumers to subscribe to weekly produce boxes from their favorite farmers.

-- ==========================================================
-- New enums for subscription management
-- ==========================================================
CREATE TYPE subscription_frequency AS ENUM (
    'weekly',
    'biweekly',
    'monthly'
);

CREATE TYPE subscription_status AS ENUM (
    'active',
    'paused',
    'cancelled'
);

CREATE TYPE subscription_delivery_status AS ENUM (
    'scheduled',
    'order_created',
    'delivered',
    'skipped'
);

-- ==========================================================
-- subscription_plans — farmer-defined recurring produce boxes
-- ==========================================================
CREATE TABLE subscription_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    farmer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name_en text NOT NULL,
    name_ne text NOT NULL,
    description_en text,
    description_ne text,
    price numeric(10,2) NOT NULL CHECK (price > 0),
    frequency subscription_frequency NOT NULL DEFAULT 'weekly',
    items jsonb NOT NULL DEFAULT '[]',
    max_subscribers integer NOT NULL DEFAULT 50 CHECK (max_subscribers > 0),
    delivery_day integer NOT NULL DEFAULT 0 CHECK (delivery_day >= 0 AND delivery_day <= 6),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER subscription_plans_updated_at
    BEFORE UPDATE ON subscription_plans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- items jsonb schema: [{"category_en": "Vegetables", "category_ne": "तरकारी", "approx_kg": 5}, ...]

-- ==========================================================
-- subscriptions — consumer subscription to a farmer's plan
-- ==========================================================
CREATE TABLE subscriptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id uuid NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    consumer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status subscription_status NOT NULL DEFAULT 'active',
    next_delivery_date date NOT NULL,
    payment_method payment_method NOT NULL DEFAULT 'cash',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    paused_at timestamptz,
    cancelled_at timestamptz,
    UNIQUE (plan_id, consumer_id)
);

CREATE TRIGGER subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- subscription_deliveries — tracks each delivery cycle
-- ==========================================================
CREATE TABLE subscription_deliveries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id uuid NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
    scheduled_date date NOT NULL,
    actual_items jsonb,
    status subscription_delivery_status NOT NULL DEFAULT 'scheduled',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER subscription_deliveries_updated_at
    BEFORE UPDATE ON subscription_deliveries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- Indexes
-- ==========================================================
CREATE INDEX idx_subscription_plans_farmer ON subscription_plans (farmer_id) WHERE is_active = true;
CREATE INDEX idx_subscription_plans_active ON subscription_plans (is_active, frequency);
CREATE INDEX idx_subscriptions_plan ON subscriptions (plan_id, status);
CREATE INDEX idx_subscriptions_consumer ON subscriptions (consumer_id, status);
CREATE INDEX idx_subscriptions_next_delivery ON subscriptions (next_delivery_date) WHERE status = 'active';
CREATE INDEX idx_subscription_deliveries_sub ON subscription_deliveries (subscription_id, scheduled_date);
CREATE INDEX idx_subscription_deliveries_date ON subscription_deliveries (scheduled_date, status);

-- ==========================================================
-- RLS
-- ==========================================================
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_deliveries ENABLE ROW LEVEL SECURITY;

-- subscription_plans: public read, farmers manage own
CREATE POLICY subscription_plans_select ON subscription_plans
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY subscription_plans_insert ON subscription_plans
    FOR INSERT TO authenticated
    WITH CHECK (farmer_id = auth.uid());

CREATE POLICY subscription_plans_update ON subscription_plans
    FOR UPDATE TO authenticated
    USING (farmer_id = auth.uid())
    WITH CHECK (farmer_id = auth.uid());

CREATE POLICY subscription_plans_delete ON subscription_plans
    FOR DELETE TO authenticated
    USING (farmer_id = auth.uid());

-- subscriptions: consumers see own, farmers see subscriptions to their plans
CREATE POLICY subscriptions_select ON subscriptions
    FOR SELECT TO authenticated
    USING (
        consumer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM subscription_plans
            WHERE subscription_plans.id = subscriptions.plan_id
              AND subscription_plans.farmer_id = auth.uid()
        )
    );

CREATE POLICY subscriptions_insert ON subscriptions
    FOR INSERT TO authenticated
    WITH CHECK (consumer_id = auth.uid());

CREATE POLICY subscriptions_update ON subscriptions
    FOR UPDATE TO authenticated
    USING (consumer_id = auth.uid());

-- subscription_deliveries: parties can view
CREATE POLICY subscription_deliveries_select ON subscription_deliveries
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM subscriptions
            WHERE subscriptions.id = subscription_deliveries.subscription_id
              AND (
                  subscriptions.consumer_id = auth.uid()
                  OR EXISTS (
                      SELECT 1 FROM subscription_plans
                      WHERE subscription_plans.id = subscriptions.plan_id
                        AND subscription_plans.farmer_id = auth.uid()
                  )
              )
        )
    );

-- Only system (service role) creates deliveries via cron/edge function
