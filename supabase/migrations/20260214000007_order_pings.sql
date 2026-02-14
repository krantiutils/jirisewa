-- ==========================================================
-- Order Pings — Real-time rider matching for in-transit trips
-- ==========================================================

-- Enum for ping lifecycle status
CREATE TYPE ping_status AS ENUM ('pending', 'accepted', 'declined', 'expired');

-- ==========================================================
-- order_pings — tracks which riders were pinged for which orders
-- ==========================================================
CREATE TABLE order_pings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    rider_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trip_id uuid NOT NULL REFERENCES rider_trips(id) ON DELETE CASCADE,

    -- Snapshot fields (denormalized for fast rendering in rider UI)
    pickup_locations jsonb NOT NULL DEFAULT '[]'::jsonb,
    delivery_location jsonb NOT NULL,
    total_weight_kg numeric NOT NULL DEFAULT 0,
    estimated_earnings numeric NOT NULL DEFAULT 0,
    detour_distance_m numeric NOT NULL DEFAULT 0,

    -- Lifecycle
    status ping_status NOT NULL DEFAULT 'pending',
    expires_at timestamptz NOT NULL,
    responded_at timestamptz,

    created_at timestamptz NOT NULL DEFAULT now(),

    -- One ping per rider per order
    CONSTRAINT order_pings_unique_rider_order UNIQUE (order_id, rider_id)
);

-- ==========================================================
-- Indexes
-- ==========================================================

-- Lookup pings by order + status (for expiring all pings when order is accepted/cancelled)
CREATE INDEX idx_order_pings_order_status ON order_pings (order_id, status);

-- Rider's pending pings (for realtime subscription and listing)
CREATE INDEX idx_order_pings_rider_pending ON order_pings (rider_id, status)
    WHERE status = 'pending';

-- Expiry scan (for background job or on-read expiry checks)
CREATE INDEX idx_order_pings_expires ON order_pings (expires_at)
    WHERE status = 'pending';

-- ==========================================================
-- Enable RLS
-- ==========================================================
ALTER TABLE order_pings ENABLE ROW LEVEL SECURITY;

-- Riders can see their own pings
CREATE POLICY order_pings_select ON order_pings
    FOR SELECT TO authenticated
    USING (rider_id = auth.uid());

-- Riders can update their own pings (accept/decline)
CREATE POLICY order_pings_update ON order_pings
    FOR UPDATE TO authenticated
    USING (rider_id = auth.uid())
    WITH CHECK (rider_id = auth.uid());

-- Server-side inserts (via service role) — no INSERT policy needed for authenticated
-- because findAndPingRiders uses service role client

-- ==========================================================
-- Enable Supabase Realtime for order_pings
-- ==========================================================
ALTER PUBLICATION supabase_realtime ADD TABLE order_pings;

-- ==========================================================
-- find_eligible_riders — PostGIS RPC for spatial rider matching
--
-- Finds in_transit trips whose remaining route passes near
-- ALL pickup locations AND the delivery location.
-- ==========================================================
CREATE OR REPLACE FUNCTION find_eligible_riders(
    p_order_id uuid,
    p_max_detour_m numeric DEFAULT 5000,
    p_max_results integer DEFAULT 10
)
RETURNS TABLE (
    trip_id uuid,
    rider_id uuid,
    remaining_capacity_kg numeric,
    detour_distance_m numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_delivery_location geography;
    v_total_weight_kg numeric;
    v_pickup_locations geography[];
    v_pickup_count integer;
BEGIN
    -- 1. Get the order's delivery location
    SELECT o.delivery_location::geography
    INTO v_delivery_location
    FROM orders o
    WHERE o.id = p_order_id;

    IF v_delivery_location IS NULL THEN
        RAISE EXCEPTION 'Order % not found or has no delivery location', p_order_id;
    END IF;

    -- 2. Get total weight and pickup locations from order items
    SELECT
        COALESCE(SUM(oi.quantity_kg), 0),
        ARRAY_AGG(oi.pickup_location::geography) FILTER (WHERE oi.pickup_location IS NOT NULL)
    INTO v_total_weight_kg, v_pickup_locations
    FROM order_items oi
    WHERE oi.order_id = p_order_id;

    v_pickup_count := COALESCE(array_length(v_pickup_locations, 1), 0);

    -- If no pickup locations have coordinates, we can't do spatial matching
    IF v_pickup_count = 0 THEN
        RETURN;
    END IF;

    -- 3. Find eligible riders
    RETURN QUERY
    WITH eligible_trips AS (
        SELECT
            rt.id AS e_trip_id,
            rt.rider_id AS e_rider_id,
            rt.remaining_capacity_kg AS e_remaining_capacity_kg,
            rt.route
        FROM rider_trips rt
        WHERE rt.status = 'in_transit'
          AND rt.remaining_capacity_kg >= v_total_weight_kg
          AND rt.route IS NOT NULL
          -- Exclude riders already pinged for this order
          AND NOT EXISTS (
              SELECT 1 FROM order_pings op
              WHERE op.order_id = p_order_id
                AND op.rider_id = rt.rider_id
          )
    ),
    trips_with_progress AS (
        SELECT
            et.*,
            -- Get rider's latest location to determine route progress
            COALESCE(
                (
                    SELECT ST_LineLocatePoint(
                        et.route::geometry,
                        ll.location::geometry
                    )
                    FROM rider_location_log ll
                    WHERE ll.trip_id = et.e_trip_id
                      AND ll.rider_id = et.e_rider_id
                    ORDER BY ll.recorded_at DESC
                    LIMIT 1
                ),
                0.0  -- Default to start of route if no location log
            ) AS route_progress
        FROM eligible_trips et
    ),
    trips_with_remaining AS (
        SELECT
            tp.*,
            -- Extract the remaining portion of the route
            CASE
                WHEN tp.route_progress >= 0.99 THEN NULL  -- Already at destination
                ELSE ST_LineSubstring(
                    tp.route::geometry,
                    tp.route_progress,
                    1.0
                )::geography
            END AS remaining_route
        FROM trips_with_progress tp
    ),
    spatial_check AS (
        SELECT
            tr.e_trip_id,
            tr.e_rider_id,
            tr.e_remaining_capacity_kg,
            tr.remaining_route,
            -- Check delivery location is near remaining route
            ST_DWithin(
                tr.remaining_route,
                v_delivery_location,
                p_max_detour_m
            ) AS delivery_near,
            -- Count how many pickup locations are near remaining route
            (
                SELECT COUNT(*)
                FROM unnest(v_pickup_locations) AS pl(geog)
                WHERE ST_DWithin(tr.remaining_route, pl.geog, p_max_detour_m)
            ) AS pickups_near_count
        FROM trips_with_remaining tr
        WHERE tr.remaining_route IS NOT NULL
    )
    SELECT
        sc.e_trip_id,
        sc.e_rider_id,
        sc.e_remaining_capacity_kg,
        -- Approximate detour as sum of distances from route to each point
        (
            SELECT COALESCE(SUM(ST_Distance(sc.remaining_route, pl.geog)), 0)
            FROM unnest(v_pickup_locations) AS pl(geog)
        ) + ST_Distance(sc.remaining_route, v_delivery_location) AS detour_est
    FROM spatial_check sc
    WHERE sc.delivery_near = true
      AND sc.pickups_near_count = v_pickup_count  -- ALL pickups must be near
    ORDER BY detour_est ASC
    LIMIT p_max_results;
END;
$$;
