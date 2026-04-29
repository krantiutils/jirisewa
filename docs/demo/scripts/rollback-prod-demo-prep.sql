-- Rollback for prep-prod-for-demo.sh
-- Run interactively, line-by-line, with attention. The schema migrations
-- (pickup_hubs, hub_dropoffs tables, app_role enum extension) are kept in
-- place because reversing enum changes is destructive — the schema itself
-- is harmless if unused. This rollback only reverses the seed data.
--
-- Usage:
--   psql $PROD_DB_URL -f rollback-prod-demo-prep.sql

BEGIN;

-- 1. Demo listings
DELETE FROM produce_listings WHERE id IN (
  '00000000-0000-4000-a000-000000000c01',
  '00000000-0000-4000-a000-000000000c02',
  '00000000-0000-4000-a000-000000000c03'
);

-- 2. Hub dropoffs (in case anything was demoed against prod)
DELETE FROM hub_dropoffs WHERE hub_id = '00000000-0000-4000-a000-000000000b01';

-- 3. The hub itself
DELETE FROM pickup_hubs WHERE id = '00000000-0000-4000-a000-000000000b01';

-- 4. Demo user_roles
DELETE FROM user_roles WHERE user_id IN (
  '00000000-0000-4000-a000-000000000a01',
  '00000000-0000-4000-a000-000000000a02',
  '00000000-0000-4000-a000-000000000a03'
);

-- 5. Demo user_profiles
DELETE FROM user_profiles WHERE id IN (
  '00000000-0000-4000-a000-000000000a01',
  '00000000-0000-4000-a000-000000000a02',
  '00000000-0000-4000-a000-000000000a03'
);

-- 6. Demo public.users rows
DELETE FROM users WHERE id IN (
  '00000000-0000-4000-a000-000000000a01',
  '00000000-0000-4000-a000-000000000a02',
  '00000000-0000-4000-a000-000000000a03'
);

-- 7. Demo auth users — done separately via Supabase Admin API
--    DELETE /auth/v1/admin/users/<id> for each of the three IDs above.
--    Doing it via psql against auth.users is supported but bypasses GoTrue
--    invariants; prefer the API.

-- 8. Counter RPC (optional — keeping it is harmless)
-- DROP FUNCTION IF EXISTS public.jiri_ward_counters_v1();

COMMIT;

-- The hub schema (pickup_hubs / hub_dropoffs tables, hub_operator enum
-- value, RPCs record_hub_dropoff_v1 etc.) is intentionally left in place.
-- These are part of the platform now, not demo-only state. To remove them
-- in a true emergency, see supabase/migrations/20260429000001_pickup_hubs.sql
-- and reverse each statement manually.
