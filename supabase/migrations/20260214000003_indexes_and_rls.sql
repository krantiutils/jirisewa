-- ==========================================================
-- PostGIS spatial indexes on all geography columns
-- ==========================================================
CREATE INDEX idx_users_location ON users USING GIST (location);
CREATE INDEX idx_listings_location ON produce_listings USING GIST (location);
CREATE INDEX idx_trips_origin ON rider_trips USING GIST (origin);
CREATE INDEX idx_trips_destination ON rider_trips USING GIST (destination);
CREATE INDEX idx_trips_route ON rider_trips USING GIST (route);
CREATE INDEX idx_orders_delivery_location ON orders USING GIST (delivery_location);
CREATE INDEX idx_order_items_pickup_location ON order_items USING GIST (pickup_location);
CREATE INDEX idx_rider_location ON rider_location_log USING GIST (location);

-- ==========================================================
-- Composite indexes for common query patterns
-- ==========================================================
CREATE INDEX idx_listings_active ON produce_listings (is_active, category_id);
CREATE INDEX idx_listings_farmer ON produce_listings (farmer_id) WHERE is_active = true;
CREATE INDEX idx_trips_status ON rider_trips (status, departure_at);
CREATE INDEX idx_trips_rider ON rider_trips (rider_id, status);
CREATE INDEX idx_orders_consumer ON orders (consumer_id, status);
CREATE INDEX idx_orders_rider ON orders (rider_id, status);
CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_order_items_farmer ON order_items (farmer_id);
CREATE INDEX idx_ratings_rated ON ratings (rated_id, role_rated);
CREATE INDEX idx_ratings_order ON ratings (order_id);
CREATE INDEX idx_user_roles_user ON user_roles (user_id);
CREATE INDEX idx_rider_location_trip ON rider_location_log (trip_id, recorded_at DESC);

-- ==========================================================
-- Enable Row Level Security on all tables
-- ==========================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE produce_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE produce_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_location_log ENABLE ROW LEVEL SECURITY;

-- ==========================================================
-- RLS Policies: users
-- Authenticated can read all profiles (marketplace needs this).
-- Users can only modify their own profile.
-- ==========================================================
CREATE POLICY users_select ON users
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY users_insert ON users
    FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

CREATE POLICY users_update ON users
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY users_delete ON users
    FOR DELETE TO authenticated
    USING (id = auth.uid());

-- ==========================================================
-- RLS Policies: user_roles
-- Authenticated can read all roles (show farmer/rider badges).
-- Users can only modify their own roles.
-- ==========================================================
CREATE POLICY user_roles_select ON user_roles
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY user_roles_insert ON user_roles
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY user_roles_update ON user_roles
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY user_roles_delete ON user_roles
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- ==========================================================
-- RLS Policies: produce_categories
-- Public read (anon + authenticated). No client writes.
-- Categories are managed via seed data or admin.
-- ==========================================================
CREATE POLICY categories_select ON produce_categories
    FOR SELECT TO anon, authenticated
    USING (true);

-- ==========================================================
-- RLS Policies: produce_listings
-- Public read (marketplace browsing).
-- Farmers manage their own listings.
-- ==========================================================
CREATE POLICY listings_select ON produce_listings
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY listings_insert ON produce_listings
    FOR INSERT TO authenticated
    WITH CHECK (farmer_id = auth.uid());

CREATE POLICY listings_update ON produce_listings
    FOR UPDATE TO authenticated
    USING (farmer_id = auth.uid())
    WITH CHECK (farmer_id = auth.uid());

CREATE POLICY listings_delete ON produce_listings
    FOR DELETE TO authenticated
    USING (farmer_id = auth.uid());

-- ==========================================================
-- RLS Policies: rider_trips
-- Public read (consumers browse available trips).
-- Riders manage their own trips.
-- ==========================================================
CREATE POLICY trips_select ON rider_trips
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY trips_insert ON rider_trips
    FOR INSERT TO authenticated
    WITH CHECK (rider_id = auth.uid());

CREATE POLICY trips_update ON rider_trips
    FOR UPDATE TO authenticated
    USING (rider_id = auth.uid())
    WITH CHECK (rider_id = auth.uid());

CREATE POLICY trips_delete ON rider_trips
    FOR DELETE TO authenticated
    USING (rider_id = auth.uid());

-- ==========================================================
-- RLS Policies: orders
-- Parties to the order can view (consumer, rider, farmer).
-- Consumer creates. Consumer and rider can update.
-- ==========================================================
CREATE POLICY orders_select ON orders
    FOR SELECT TO authenticated
    USING (
        consumer_id = auth.uid()
        OR rider_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM order_items
            WHERE order_items.order_id = orders.id
              AND order_items.farmer_id = auth.uid()
        )
    );

CREATE POLICY orders_insert ON orders
    FOR INSERT TO authenticated
    WITH CHECK (consumer_id = auth.uid());

CREATE POLICY orders_update ON orders
    FOR UPDATE TO authenticated
    USING (
        consumer_id = auth.uid()
        OR rider_id = auth.uid()
    );

-- ==========================================================
-- RLS Policies: order_items
-- Parties to the parent order can view.
-- Consumer creates (via order placement).
-- Rider and farmer can update (pickup/delivery confirmation).
-- ==========================================================
CREATE POLICY order_items_select ON order_items
    FOR SELECT TO authenticated
    USING (
        farmer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM orders
            WHERE orders.id = order_items.order_id
              AND (orders.consumer_id = auth.uid() OR orders.rider_id = auth.uid())
        )
    );

CREATE POLICY order_items_insert ON order_items
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM orders
            WHERE orders.id = order_items.order_id
              AND orders.consumer_id = auth.uid()
        )
    );

CREATE POLICY order_items_update ON order_items
    FOR UPDATE TO authenticated
    USING (
        farmer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM orders
            WHERE orders.id = order_items.order_id
              AND orders.rider_id = auth.uid()
        )
    );

-- ==========================================================
-- RLS Policies: ratings
-- Public read (transparency). Authenticated users create own.
-- Ratings are immutable — no update or delete.
-- ==========================================================
CREATE POLICY ratings_select ON ratings
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY ratings_insert ON ratings
    FOR INSERT TO authenticated
    WITH CHECK (rater_id = auth.uid());

-- ==========================================================
-- RLS Policies: rider_location_log
-- Riders insert their own location.
-- Consumers with active orders can view their rider's location.
-- ==========================================================
CREATE POLICY location_log_insert ON rider_location_log
    FOR INSERT TO authenticated
    WITH CHECK (rider_id = auth.uid());

CREATE POLICY location_log_select ON rider_location_log
    FOR SELECT TO authenticated
    USING (
        rider_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM orders
            WHERE orders.rider_id = rider_location_log.rider_id
              AND orders.consumer_id = auth.uid()
              AND orders.status IN ('matched', 'picked_up', 'in_transit')
        )
    );
