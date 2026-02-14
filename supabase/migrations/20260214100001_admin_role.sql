-- ==========================================================
-- Add admin flag to users table
-- ==========================================================
ALTER TABLE users ADD COLUMN is_admin boolean NOT NULL DEFAULT false;

-- Index for fast admin lookups
CREATE INDEX idx_users_is_admin ON users (is_admin) WHERE is_admin = true;

-- ==========================================================
-- Admin RLS policies: admins can read ALL data on all tables
-- ==========================================================

-- Admin can read all orders (not just their own)
CREATE POLICY admin_orders_select ON orders
    FOR SELECT TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can update any order (force-resolve, cancel, etc.)
CREATE POLICY admin_orders_update ON orders
    FOR UPDATE TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can read all order items
CREATE POLICY admin_order_items_select ON order_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can update order items (for dispute resolution)
CREATE POLICY admin_order_items_update ON order_items
    FOR UPDATE TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can update any user (ban, suspend, verify)
CREATE POLICY admin_users_update ON users
    FOR UPDATE TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can update any user_role (verify farmers/riders)
CREATE POLICY admin_user_roles_update ON user_roles
    FOR UPDATE TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can read rider location logs
CREATE POLICY admin_location_log_select ON rider_location_log
    FOR SELECT TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can update produce listings (moderate content)
CREATE POLICY admin_listings_update ON produce_listings
    FOR UPDATE TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can delete produce listings (content moderation)
CREATE POLICY admin_listings_delete ON produce_listings
    FOR DELETE TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );
