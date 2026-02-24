-- Fix infinite recursion between orders and order_items RLS policies.
--
-- Problem: orders_select checks order_items (for farmer access),
-- and order_items_select checks orders (for consumer/rider access).
-- PostgreSQL evaluates ALL policy branches, causing infinite recursion.
--
-- Solution: Replace the cross-table EXISTS checks with SECURITY DEFINER
-- helper functions that bypass RLS on the target table.

-- Helper: check if user is a farmer on an order (reads order_items bypassing RLS)
CREATE OR REPLACE FUNCTION is_farmer_on_order(p_order_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM order_items
    WHERE order_items.order_id = p_order_id
      AND order_items.farmer_id = p_user_id
  );
$$;

-- Helper: check if user is consumer or rider on an order (reads orders bypassing RLS)
CREATE OR REPLACE FUNCTION is_party_on_order(p_order_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM orders
    WHERE orders.id = p_order_id
      AND (orders.consumer_id = p_user_id OR orders.rider_id = p_user_id)
  );
$$;

-- Drop and recreate orders_select to use the helper
DROP POLICY IF EXISTS orders_select ON orders;
CREATE POLICY orders_select ON orders
    FOR SELECT TO authenticated
    USING (
        consumer_id = auth.uid()
        OR rider_id = auth.uid()
        OR is_farmer_on_order(id, auth.uid())
    );

-- Drop and recreate order_items_select to use the helper
DROP POLICY IF EXISTS order_items_select ON order_items;
CREATE POLICY order_items_select ON order_items
    FOR SELECT TO authenticated
    USING (
        farmer_id = auth.uid()
        OR is_party_on_order(order_id, auth.uid())
    );

-- Also fix order_items_insert which has same cross-table reference
DROP POLICY IF EXISTS order_items_insert ON order_items;
CREATE POLICY order_items_insert ON order_items
    FOR INSERT TO authenticated
    WITH CHECK (
        is_party_on_order(order_id, auth.uid())
    );

-- Also fix order_items_update
DROP POLICY IF EXISTS order_items_update ON order_items;
CREATE POLICY order_items_update ON order_items
    FOR UPDATE TO authenticated
    USING (
        farmer_id = auth.uid()
        OR is_party_on_order(order_id, auth.uid())
    );

-- ==========================================================
-- Fix bulk_orders / bulk_order_items circular RLS recursion
-- Same pattern: bulk_orders_select checks bulk_order_items,
-- and bulk_order_items_select checks bulk_orders.
-- ==========================================================

-- Helper: check if user is a farmer on a bulk order (reads bulk_order_items bypassing RLS)
CREATE OR REPLACE FUNCTION is_farmer_on_bulk_order(p_bulk_order_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM bulk_order_items
    WHERE bulk_order_items.bulk_order_id = p_bulk_order_id
      AND bulk_order_items.farmer_id = p_user_id
  );
$$;

-- Helper: check if user is the business owner of a bulk order (reads bulk_orders bypassing RLS)
CREATE OR REPLACE FUNCTION is_business_owner_of_bulk_order(p_bulk_order_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM bulk_orders
    JOIN business_profiles ON business_profiles.id = bulk_orders.business_id
    WHERE bulk_orders.id = p_bulk_order_id
      AND business_profiles.user_id = p_user_id
  );
$$;

-- Fix bulk_orders_select
DROP POLICY IF EXISTS bulk_orders_select ON bulk_orders;
CREATE POLICY bulk_orders_select ON bulk_orders
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM business_profiles
            WHERE business_profiles.id = bulk_orders.business_id
              AND business_profiles.user_id = auth.uid()
        )
        OR is_farmer_on_bulk_order(id, auth.uid())
    );

-- Fix bulk_order_items_select
DROP POLICY IF EXISTS bulk_order_items_select ON bulk_order_items;
CREATE POLICY bulk_order_items_select ON bulk_order_items
    FOR SELECT TO authenticated
    USING (
        farmer_id = auth.uid()
        OR is_business_owner_of_bulk_order(bulk_order_id, auth.uid())
    );

-- Fix bulk_order_items_insert
DROP POLICY IF EXISTS bulk_order_items_insert ON bulk_order_items;
CREATE POLICY bulk_order_items_insert ON bulk_order_items
    FOR INSERT TO authenticated
    WITH CHECK (
        is_business_owner_of_bulk_order(bulk_order_id, auth.uid())
    );

-- Fix bulk_order_items_update
DROP POLICY IF EXISTS bulk_order_items_update ON bulk_order_items;
CREATE POLICY bulk_order_items_update ON bulk_order_items
    FOR UPDATE TO authenticated
    USING (
        farmer_id = auth.uid()
        OR is_business_owner_of_bulk_order(bulk_order_id, auth.uid())
    );
