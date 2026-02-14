-- Khalti and connectIPS payment integration
-- Adds connectips to payment_method enum, creates khalti_transactions and connectips_transactions tables

-- Extend payment_method enum to include connectips
ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'connectips' AFTER 'khalti';

-- ==========================================================
-- khalti_transactions — tracks Khalti payment lifecycle
-- ==========================================================
CREATE TABLE khalti_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    purchase_order_id text NOT NULL UNIQUE,
    pidx text,
    amount_paisa integer NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    khalti_status text,
    transaction_id text,
    khalti_fee integer,
    refunded boolean NOT NULL DEFAULT false,
    verified_at timestamptz,
    escrow_released_at timestamptz,
    refunded_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER khalti_transactions_updated_at
    BEFORE UPDATE ON khalti_transactions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_khalti_transactions_order_id ON khalti_transactions(order_id);
CREATE INDEX idx_khalti_transactions_status ON khalti_transactions(status);
CREATE INDEX idx_khalti_transactions_pidx ON khalti_transactions(pidx);

-- ==========================================================
-- connectips_transactions — tracks connectIPS payment lifecycle
-- ==========================================================
CREATE TABLE connectips_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    txn_id text NOT NULL UNIQUE,
    reference_id text NOT NULL,
    amount_paisa integer NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    connectips_status text,
    verified_at timestamptz,
    escrow_released_at timestamptz,
    refunded_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER connectips_transactions_updated_at
    BEFORE UPDATE ON connectips_transactions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_connectips_transactions_order_id ON connectips_transactions(order_id);
CREATE INDEX idx_connectips_transactions_status ON connectips_transactions(status);
CREATE UNIQUE INDEX idx_connectips_transactions_reference_id ON connectips_transactions(reference_id);
