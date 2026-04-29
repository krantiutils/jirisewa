-- ==========================================================
-- Phase 1 — Aggregation Hubs (origin side)
--
-- A pickup_hub is a managed drop-off / pickup point. Farmers drop
-- produce at a hub; the hub holds inventory until a rider trip or
-- (later, Phase 4) a scheduled truck run picks it up. Listings
-- tagged 'hub_dropoff' or 'both' can be sourced from a hub instead
-- of the farm, which is the unlock for tonnage consolidation and
-- for farmers who can't run their own deliveries.
--
-- This migration is purely additive: existing single-farm-pickup
-- orders continue to work unchanged. Behaviour change happens in
-- the matching RPC (next migration).
-- ==========================================================

-- ----------------------------------------------------------
-- 1. Extend app_role enum with hub_operator
-- ----------------------------------------------------------
-- Note: ALTER TYPE ... ADD VALUE cannot be used in the same
-- transaction as queries that reference the new value, so this
-- runs first and any seeding that references 'hub_operator' must
-- happen in a later migration.
ALTER TYPE app_role ADD VALUE IF NOT EXISTS 'hub_operator';

-- ----------------------------------------------------------
-- 2. pickup_hubs — managed drop-off / pickup points
-- ----------------------------------------------------------
CREATE TABLE pickup_hubs (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en         text NOT NULL,
    name_ne         text NOT NULL,
    municipality_id uuid REFERENCES municipalities(id) ON DELETE SET NULL,
    address         text NOT NULL,
    location        geography(Point, 4326) NOT NULL,
    operator_id     uuid REFERENCES users(id) ON DELETE SET NULL,
    -- 'origin'      = farmer drop-off point (Phase 1: Jiri bazaar)
    -- 'destination' = consumer pickup / hub-to-door staging (Phase 5)
    -- 'transit'     = pure relay (reserved for Phase 4 truck routing)
    hub_type        text NOT NULL CHECK (hub_type IN ('origin','destination','transit')),
    operating_hours jsonb,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER pickup_hubs_updated_at
    BEFORE UPDATE ON pickup_hubs
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_pickup_hubs_municipality ON pickup_hubs (municipality_id) WHERE is_active = true;
CREATE INDEX idx_pickup_hubs_operator     ON pickup_hubs (operator_id)     WHERE is_active = true;
CREATE INDEX idx_pickup_hubs_location_gix ON pickup_hubs USING GIST (location);

-- ----------------------------------------------------------
-- 3. hub_dropoffs — farmer produce parked at a hub
-- ----------------------------------------------------------
CREATE TABLE hub_dropoffs (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hub_id        uuid NOT NULL REFERENCES pickup_hubs(id) ON DELETE RESTRICT,
    farmer_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id    uuid NOT NULL REFERENCES produce_listings(id) ON DELETE RESTRICT,
    quantity_kg   numeric(10,2) NOT NULL CHECK (quantity_kg > 0),
    -- printable label, unique per hub. The dropoff RPC generates it.
    lot_code      text NOT NULL,
    -- dropped_off  = farmer recorded the dropoff, hub hasn't confirmed receipt
    -- in_inventory = hub operator confirmed receipt; available for matching
    -- dispatched   = handed to a rider trip / truck run
    -- expired      = aged past expires_at without dispatch
    -- spoiled      = operator marked as no-good
    status        text NOT NULL DEFAULT 'dropped_off' CHECK (status IN
        ('dropped_off','in_inventory','dispatched','expired','spoiled')),
    dropped_at    timestamptz NOT NULL DEFAULT now(),
    received_at   timestamptz,
    dispatched_at timestamptz,
    -- spoilage horizon. Default 48h; RPC may override per-listing later.
    expires_at    timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
    rider_trip_id uuid REFERENCES rider_trips(id) ON DELETE SET NULL,
    notes         text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hub_id, lot_code)
);

CREATE TRIGGER hub_dropoffs_updated_at
    BEFORE UPDATE ON hub_dropoffs
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_hub_dropoffs_hub_status   ON hub_dropoffs (hub_id, status);
CREATE INDEX idx_hub_dropoffs_farmer       ON hub_dropoffs (farmer_id);
CREATE INDEX idx_hub_dropoffs_listing_live ON hub_dropoffs (listing_id) WHERE status = 'in_inventory';
CREATE INDEX idx_hub_dropoffs_expires_live ON hub_dropoffs (expires_at) WHERE status IN ('dropped_off','in_inventory');

-- ----------------------------------------------------------
-- 4. produce_listings.pickup_mode — how is this listing fulfilled?
-- ----------------------------------------------------------
ALTER TABLE produce_listings ADD COLUMN pickup_mode text NOT NULL DEFAULT 'farm_pickup'
    CHECK (pickup_mode IN ('farm_pickup','hub_dropoff','both'));

-- ----------------------------------------------------------
-- 5. order_items.dropoff_id — link an item to the hub lot it pulled from
-- ----------------------------------------------------------
ALTER TABLE order_items ADD COLUMN dropoff_id uuid REFERENCES hub_dropoffs(id) ON DELETE SET NULL;

CREATE INDEX idx_order_items_dropoff ON order_items (dropoff_id) WHERE dropoff_id IS NOT NULL;

-- ----------------------------------------------------------
-- 6. RLS on pickup_hubs
-- Read: any authenticated user can see active hubs (for pickers).
-- Write: service_role only — admins manage hubs through admin RPCs
-- (added in a later migration alongside admin tooling).
-- ----------------------------------------------------------
ALTER TABLE pickup_hubs ENABLE ROW LEVEL SECURITY;

CREATE POLICY pickup_hubs_select_active ON pickup_hubs
    FOR SELECT TO authenticated
    USING (is_active = true);

-- Operator can read their own hub even if disabled.
CREATE POLICY pickup_hubs_select_operator ON pickup_hubs
    FOR SELECT TO authenticated
    USING (operator_id = auth.uid());

-- ----------------------------------------------------------
-- 7. RLS on hub_dropoffs
-- The RPCs do the writes (SECURITY DEFINER), but reads come from
-- the client, so spell those out:
--   - farmer reads their own dropoffs
--   - hub operator reads dropoffs at their hub
--   - admin reads all (via is_admin flag on users)
-- ----------------------------------------------------------
ALTER TABLE hub_dropoffs ENABLE ROW LEVEL SECURITY;

CREATE POLICY hub_dropoffs_select_farmer ON hub_dropoffs
    FOR SELECT TO authenticated
    USING (farmer_id = auth.uid());

CREATE POLICY hub_dropoffs_select_operator ON hub_dropoffs
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM pickup_hubs h
            WHERE h.id = hub_dropoffs.hub_id
              AND h.operator_id = auth.uid()
        )
    );

-- Service-role bypasses RLS, so trigger-side and RPC-side writes
-- continue to work. No INSERT/UPDATE policies for authenticated —
-- all mutations route through SECURITY DEFINER RPCs.
