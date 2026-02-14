-- Multi-farmer order support: per-item pickup tracking, sub-order splitting,
-- delivery fee calculation, and farmer payout tracking.

-- ==========================================================
-- New enum: order_item_status — tracks individual item pickup state
-- ==========================================================
CREATE TYPE order_item_status AS ENUM (
    'pending_pickup',
    'picked_up',
    'unavailable'
);

-- ==========================================================
-- New enum: payout_status — tracks per-farmer payment state
-- ==========================================================
CREATE TYPE payout_status AS ENUM (
    'pending',
    'settled',
    'refunded'
);

-- ==========================================================
-- Alter order_items: add pickup sequencing and per-item status
-- ==========================================================
ALTER TABLE order_items
    ADD COLUMN pickup_status order_item_status NOT NULL DEFAULT 'pending_pickup',
    ADD COLUMN pickup_sequence integer NOT NULL DEFAULT 0,
    ADD COLUMN pickup_confirmed_at timestamptz;

-- ==========================================================
-- Alter orders: add parent_order_id for sub-order splitting
-- and delivery_fee_breakdown for transparency
-- ==========================================================
ALTER TABLE orders
    ADD COLUMN parent_order_id uuid REFERENCES orders(id) ON DELETE SET NULL;

-- Index for finding sub-orders of a parent
CREATE INDEX idx_orders_parent ON orders (parent_order_id) WHERE parent_order_id IS NOT NULL;

-- ==========================================================
-- farmer_payouts — tracks how much each farmer is owed per order
-- ==========================================================
CREATE TABLE farmer_payouts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    farmer_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount numeric(10,2) NOT NULL,
    status payout_status NOT NULL DEFAULT 'pending',
    settled_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (order_id, farmer_id)
);

CREATE TRIGGER farmer_payouts_updated_at
    BEFORE UPDATE ON farmer_payouts
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_farmer_payouts_order ON farmer_payouts (order_id);
CREATE INDEX idx_farmer_payouts_farmer ON farmer_payouts (farmer_id, status);

-- ==========================================================
-- RLS for farmer_payouts
-- ==========================================================
ALTER TABLE farmer_payouts ENABLE ROW LEVEL SECURITY;

-- Farmers can see their own payouts
CREATE POLICY farmer_payouts_select ON farmer_payouts
    FOR SELECT TO authenticated
    USING (
        farmer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM orders
            WHERE orders.id = farmer_payouts.order_id
              AND (orders.consumer_id = auth.uid() OR orders.rider_id = auth.uid())
        )
    );

-- Only system (service role) creates payouts — no client insert policy needed
-- Consumer insert is via the order placement flow (service role client)

-- ==========================================================
-- PostGIS helper: check if a point is within max_distance of a trip route
-- ==========================================================
CREATE OR REPLACE FUNCTION check_point_near_route(
    trip_id uuid,
    point_wkt text,
    max_distance_meters double precision
)
RETURNS integer AS $$
    SELECT COUNT(*)::integer
    FROM rider_trips
    WHERE id = trip_id
      AND route IS NOT NULL
      AND ST_DWithin(
          route,
          ST_GeogFromText(point_wkt),
          max_distance_meters
      );
$$ LANGUAGE sql STABLE;

-- ==========================================================
-- PostGIS helper: locate a point's fraction along a trip route
-- Returns 0.0 (at origin) to 1.0 (at destination)
-- ==========================================================
CREATE OR REPLACE FUNCTION locate_point_on_route(
    trip_id uuid,
    point_wkt text
)
RETURNS double precision AS $$
    SELECT ST_LineLocatePoint(
        route::geometry,
        ST_GeogFromText(point_wkt)::geometry
    )
    FROM rider_trips
    WHERE id = trip_id
      AND route IS NOT NULL;
$$ LANGUAGE sql STABLE;
