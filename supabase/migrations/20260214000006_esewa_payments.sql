-- eSewa payment integration: escrow tracking and transaction log
-- Adds escrow state to payment_status and creates esewa_transactions table

-- Extend payment_status enum to include escrow state
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'escrowed' AFTER 'pending';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunded' AFTER 'settled';

-- ==========================================================
-- esewa_transactions — tracks eSewa payment lifecycle
-- ==========================================================
CREATE TABLE esewa_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    transaction_uuid text NOT NULL UNIQUE,
    product_code text NOT NULL,
    amount numeric(10,2) NOT NULL,
    tax_amount numeric(10,2) NOT NULL DEFAULT 0,
    service_charge numeric(10,2) NOT NULL DEFAULT 0,
    delivery_charge numeric(10,2) NOT NULL DEFAULT 0,
    total_amount numeric(10,2) NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    esewa_ref_id text,
    esewa_status text,
    verified_at timestamptz,
    escrow_released_at timestamptz,
    refunded_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER esewa_transactions_updated_at
    BEFORE UPDATE ON esewa_transactions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_esewa_transactions_order_id ON esewa_transactions(order_id);
CREATE INDEX idx_esewa_transactions_status ON esewa_transactions(status);
