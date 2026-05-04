-- =============================================================================
-- wipe_userdata.sql — DESTRUCTIVE
--
-- Removes all user-generated rows so prior demo state can't influence the
-- launch. Preserves seed data (produce_categories, municipalities,
-- service_areas, popular_routes, delivery_rates) and the seeded Jiri bazaar
-- hub + its operator user (so pickup_hubs FK stays valid).
--
-- This file is NOT in supabase/migrations/ on purpose — it must be applied
-- manually, never by the auto-migrator.
--
-- To apply on prod:
--   docker compose -f docker-compose.prod.yml --env-file .env.docker exec -T db \
--     psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/scripts/wipe_userdata.sql
--
-- To apply locally:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/wipe_userdata.sql
-- =============================================================================

BEGIN;

-- Hub operator UUID seeded by supabase/seed/002_jiri_bazaar_hub.sql.
-- Keep it so pickup_hubs.operator_id remains valid.
\set hub_operator_id '''00000000-0000-4000-a000-000000000a01'''

-- Order matters: leaf tables first, then parents.

-- chat / messaging
DELETE FROM chat_messages;
DELETE FROM chat_conversations;

-- notifications / devices
DELETE FROM notifications;
DELETE FROM notification_preferences;
DELETE FROM user_devices;

-- pings / trip stops
DELETE FROM order_pings;
DELETE FROM trip_stops;

-- order line items + payment + payouts
DELETE FROM order_items;
DELETE FROM farmer_payouts;
DELETE FROM esewa_transactions;
DELETE FROM khalti_transactions;
DELETE FROM connectips_transactions;
DELETE FROM orders;

-- ratings
DELETE FROM ratings;

-- subscriptions
DELETE FROM subscription_deliveries;
DELETE FROM subscriptions;
DELETE FROM subscription_plans;

-- B2B
DELETE FROM bulk_order_items;
DELETE FROM bulk_orders;
DELETE FROM business_profiles;

-- verification / addresses
DELETE FROM verification_documents;
DELETE FROM user_addresses;

-- listings + rider trips + tracking
DELETE FROM produce_listings;
DELETE FROM rider_location_log;
DELETE FROM rider_trips;

-- hub-side ops (keep pickup_hubs row itself, drop drop-offs/inventory)
DELETE FROM hub_dropoffs;

-- earnings + payout requests
DELETE FROM payout_requests;
DELETE FROM earnings;

-- user roles + profiles + auth (preserve seeded hub operator)
DELETE FROM user_roles    WHERE user_id != :hub_operator_id;
DELETE FROM user_profiles WHERE id      != :hub_operator_id;
DELETE FROM users         WHERE id      != :hub_operator_id;
DELETE FROM auth.users    WHERE id      != :hub_operator_id;

COMMIT;

-- Sanity check: counts after wipe (should be 0 except seeded tables).
\echo
\echo === Post-wipe row counts ===
SELECT 'auth.users'           AS tbl, COUNT(*) FROM auth.users
UNION ALL SELECT 'users',                COUNT(*) FROM users
UNION ALL SELECT 'user_profiles',        COUNT(*) FROM user_profiles
UNION ALL SELECT 'orders',               COUNT(*) FROM orders
UNION ALL SELECT 'produce_listings',     COUNT(*) FROM produce_listings
UNION ALL SELECT 'rider_trips',          COUNT(*) FROM rider_trips
UNION ALL SELECT 'produce_categories',   COUNT(*) FROM produce_categories
UNION ALL SELECT 'municipalities',       COUNT(*) FROM municipalities
UNION ALL SELECT 'pickup_hubs',          COUNT(*) FROM pickup_hubs;
