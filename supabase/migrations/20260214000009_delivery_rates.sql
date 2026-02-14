-- ==========================================================
-- delivery_rates — admin-configurable delivery pricing table
-- ==========================================================
CREATE TABLE delivery_rates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    base_fee_npr numeric(10,2) NOT NULL,
    per_km_rate_npr numeric(10,2) NOT NULL,
    per_kg_rate_npr numeric(10,2) NOT NULL,
    min_fee_npr numeric(10,2) NOT NULL DEFAULT 0,
    max_fee_npr numeric(10,2),  -- NULL means no cap
    is_active boolean NOT NULL DEFAULT true,
    effective_from timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Only one active rate at a time
CREATE UNIQUE INDEX idx_delivery_rates_active
    ON delivery_rates (is_active) WHERE is_active = true;

-- Seed default rates for Nepal
-- Base: NPR 50, Per km: NPR 15, Per kg: NPR 5, Min: NPR 80
INSERT INTO delivery_rates (base_fee_npr, per_km_rate_npr, per_kg_rate_npr, min_fee_npr)
VALUES (50, 15, 5, 80);

-- ==========================================================
-- Add fee breakdown columns to orders
-- ==========================================================
ALTER TABLE orders
    ADD COLUMN delivery_fee_base numeric(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN delivery_fee_distance numeric(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN delivery_fee_weight numeric(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN delivery_distance_km numeric(10,2);
