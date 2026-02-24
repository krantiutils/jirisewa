-- ==========================================================
-- Bulk Ordering for Businesses
-- Enables restaurants, hotels, and canteens to place large
-- recurring orders directly from farmers.
-- ==========================================================

-- Enum for business types
CREATE TYPE business_type AS ENUM ('restaurant', 'hotel', 'canteen', 'other');

-- Enum for bulk order lifecycle
CREATE TYPE bulk_order_status AS ENUM (
    'draft',       -- Business is building the order
    'submitted',   -- Sent to farmers for quoting
    'quoted',      -- At least one farmer has responded
    'accepted',    -- Business accepted quotes, order confirmed
    'in_progress', -- Fulfillment underway
    'fulfilled',   -- All items delivered
    'cancelled'    -- Cancelled by either party
);

-- Enum for per-item quote status from farmer
CREATE TYPE bulk_item_status AS ENUM (
    'pending',      -- Awaiting farmer response
    'quoted',       -- Farmer provided a quote
    'accepted',     -- Business accepted farmer's quote
    'rejected',     -- Farmer declined to fulfill
    'fulfilled',    -- Item delivered
    'cancelled'     -- Item cancelled
);

-- Enum for delivery schedule frequency
CREATE TYPE delivery_frequency AS ENUM ('once', 'weekly', 'biweekly', 'monthly');

-- ==========================================================
-- business_profiles — registered business accounts
-- ==========================================================
CREATE TABLE business_profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    business_name text NOT NULL,
    business_type business_type NOT NULL,
    registration_number text,
    address text NOT NULL,
    phone text,
    contact_person text,
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

CREATE TRIGGER business_profiles_updated_at
    BEFORE UPDATE ON business_profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_business_profiles_user ON business_profiles (user_id);

-- ==========================================================
-- bulk_orders — large orders placed by businesses
-- ==========================================================
CREATE TABLE bulk_orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES business_profiles(id) ON DELETE CASCADE,
    status bulk_order_status NOT NULL DEFAULT 'draft',
    delivery_address text NOT NULL,
    delivery_location geography(Point, 4326),
    delivery_frequency delivery_frequency NOT NULL DEFAULT 'once',
    delivery_schedule jsonb,  -- e.g. {"day_of_week": "monday", "time": "08:00", "start_date": "2026-03-01"}
    total_amount numeric(10,2) NOT NULL DEFAULT 0,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER bulk_orders_updated_at
    BEFORE UPDATE ON bulk_orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_bulk_orders_business ON bulk_orders (business_id, status);
CREATE INDEX idx_bulk_orders_status ON bulk_orders (status);

-- ==========================================================
-- bulk_order_items — individual produce items in a bulk order
-- ==========================================================
CREATE TABLE bulk_order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bulk_order_id uuid NOT NULL REFERENCES bulk_orders(id) ON DELETE CASCADE,
    produce_listing_id uuid NOT NULL REFERENCES produce_listings(id) ON DELETE RESTRICT,
    farmer_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    quantity_kg numeric(10,2) NOT NULL,
    price_per_kg numeric(10,2) NOT NULL,       -- Requested price (from listing)
    quoted_price_per_kg numeric(10,2),          -- Farmer's quoted price for bulk
    status bulk_item_status NOT NULL DEFAULT 'pending',
    farmer_notes text,                           -- Farmer's notes on the quote
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER bulk_order_items_updated_at
    BEFORE UPDATE ON bulk_order_items
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_bulk_order_items_order ON bulk_order_items (bulk_order_id);
CREATE INDEX idx_bulk_order_items_farmer ON bulk_order_items (farmer_id, status);

-- ==========================================================
-- RLS: business_profiles
-- ==========================================================
ALTER TABLE business_profiles ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can see business profiles (for farmer to view who ordered)
CREATE POLICY business_profiles_select ON business_profiles
    FOR SELECT TO authenticated
    USING (true);

-- Only owner can insert/update their own profile
CREATE POLICY business_profiles_insert ON business_profiles
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY business_profiles_update ON business_profiles
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ==========================================================
-- RLS: bulk_orders
-- ==========================================================
ALTER TABLE bulk_orders ENABLE ROW LEVEL SECURITY;

-- Business owner and involved farmers can view
CREATE POLICY bulk_orders_select ON bulk_orders
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM business_profiles
            WHERE business_profiles.id = bulk_orders.business_id
              AND business_profiles.user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM bulk_order_items
            WHERE bulk_order_items.bulk_order_id = bulk_orders.id
              AND bulk_order_items.farmer_id = auth.uid()
        )
    );

-- Only business owner can create
CREATE POLICY bulk_orders_insert ON bulk_orders
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM business_profiles
            WHERE business_profiles.id = bulk_orders.business_id
              AND business_profiles.user_id = auth.uid()
        )
    );

-- Business owner can update their own orders
CREATE POLICY bulk_orders_update ON bulk_orders
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM business_profiles
            WHERE business_profiles.id = bulk_orders.business_id
              AND business_profiles.user_id = auth.uid()
        )
    );

-- ==========================================================
-- RLS: bulk_order_items
-- ==========================================================
ALTER TABLE bulk_order_items ENABLE ROW LEVEL SECURITY;

-- Business owner and the specific farmer can view items
CREATE POLICY bulk_order_items_select ON bulk_order_items
    FOR SELECT TO authenticated
    USING (
        farmer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM bulk_orders
            JOIN business_profiles ON business_profiles.id = bulk_orders.business_id
            WHERE bulk_orders.id = bulk_order_items.bulk_order_id
              AND business_profiles.user_id = auth.uid()
        )
    );

-- Business owner can insert items into their orders
CREATE POLICY bulk_order_items_insert ON bulk_order_items
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM bulk_orders
            JOIN business_profiles ON business_profiles.id = bulk_orders.business_id
            WHERE bulk_orders.id = bulk_order_items.bulk_order_id
              AND business_profiles.user_id = auth.uid()
        )
    );

-- Farmer can update their own items (quoting), business owner can update too (accepting)
CREATE POLICY bulk_order_items_update ON bulk_order_items
    FOR UPDATE TO authenticated
    USING (
        farmer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM bulk_orders
            JOIN business_profiles ON business_profiles.id = bulk_orders.business_id
            WHERE bulk_orders.id = bulk_order_items.bulk_order_id
              AND business_profiles.user_id = auth.uid()
        )
    );
