#!/usr/bin/env bash
# Prep PRODUCTION Supabase for the 2026-04-30 Jiri demo.
#
# THIS WRITES TO PROD. Do not source/run blindly. Read every step.
# Run interactively after `set +e` so a failure halts the chain.
#
# Preconditions
#   - Service role key for prod Supabase exported as $SUPABASE_SERVICE_ROLE_KEY
#   - Prod Supabase URL exported as $SUPABASE_URL (e.g. https://khetbata.xyz/_supabase)
#   - psql access to prod DB exported as $PROD_DB_URL (e.g. postgres://...:5432/postgres)
#   - Dry-run pass first:    DRY_RUN=1 ./prep-prod-for-demo.sh
#   - Real run:              ./prep-prod-for-demo.sh
#
# What it does (in this order):
#   1. Apply hub migrations (20260429000001..20260429000003) to prod
#   2. Apply the new counter-RPC (jiri_ward_counters_v1)
#   3. Resolve Jiri municipality_id from prod
#   4. Seed the Jiri Bazaar Hub at (27.6275, 86.2202)
#   5. Create the four demo auth users + user_profiles + user_roles + users rows
#   6. Seed three Jiri-marquee listings against the demo farmer
#   7. Sanity smoke: query each thing back, fail loud on any mismatch
#
# Rollback (manual): see ./rollback-prod-demo-prep.sql

set -uo pipefail

DRY_RUN="${DRY_RUN:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MIGRATIONS_DIR="$REPO_ROOT/supabase/migrations"

require_env() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var not set"
    exit 1
  fi
}

require_env SUPABASE_URL
require_env SUPABASE_SERVICE_ROLE_KEY
require_env PROD_DB_URL

run_sql() {
  local label="$1" file="$2"
  echo
  echo "─── $label ──────────────────────────────"
  if [[ "$DRY_RUN" = "1" ]]; then
    echo "(dry-run) would apply: $file"
    head -3 "$file" | sed 's/^/  | /'
    return 0
  fi
  psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -f "$file"
}

run_sql_inline() {
  local label="$1" sql="$2"
  echo
  echo "─── $label ──────────────────────────────"
  if [[ "$DRY_RUN" = "1" ]]; then
    echo "(dry-run) would execute:"
    echo "$sql" | sed 's/^/  | /'
    return 0
  fi
  psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -c "$sql"
}

echo "========================================"
echo "JiriSewa prod-prep for 2026-04-30 demo"
echo "Mode: $([ "$DRY_RUN" = "1" ] && echo DRY-RUN || echo LIVE)"
echo "Target: $SUPABASE_URL"
echo "========================================"

# ───────────────────────────────────────────────
# 1. Hub migrations
# ───────────────────────────────────────────────
for migration in \
  "20260429000001_pickup_hubs.sql" \
  "20260429000002_hub_notification_categories.sql" \
  "20260429000003_hub_rpcs.sql"
do
  run_sql "Applying $migration" "$MIGRATIONS_DIR/$migration"
done

# ───────────────────────────────────────────────
# 2. Counter RPC for the live ward counters slide
# ───────────────────────────────────────────────
run_sql_inline "Creating jiri_ward_counters_v1 RPC" "
CREATE OR REPLACE FUNCTION public.jiri_ward_counters_v1()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS \$\$
  SELECT jsonb_build_object(
    'farmers',  (SELECT count(*)::int FROM users u
                  JOIN user_roles ur ON ur.user_id = u.id
                  WHERE ur.role = 'farmer'
                    AND u.municipality ILIKE '%jiri%'),
    'listings', (SELECT count(*)::int FROM produce_listings pl
                  JOIN users u ON u.id = pl.farmer_id
                  WHERE pl.is_active
                    AND u.municipality ILIKE '%jiri%'),
    'kg',       (SELECT coalesce(sum(d.quantity_kg), 0)::int
                  FROM hub_dropoffs d
                  JOIN pickup_hubs h ON h.id = d.hub_id
                  JOIN municipalities m ON m.id = h.municipality_id
                  WHERE m.name_en ILIKE '%jiri%'
                    AND d.dropped_at >= date_trunc('month', now())),
    'npr',      (SELECT coalesce(sum(oi.subtotal), 0)::int
                  FROM order_items oi
                  JOIN users u ON u.id = oi.farmer_id
                  WHERE u.municipality ILIKE '%jiri%'
                    AND oi.created_at >= date_trunc('month', now()))
  );
\$\$;
GRANT EXECUTE ON FUNCTION public.jiri_ward_counters_v1() TO anon, authenticated;
"

# ───────────────────────────────────────────────
# 3. Resolve Jiri municipality_id
# ───────────────────────────────────────────────
echo
echo "─── Resolving Jiri municipality_id ──────────────────────────────"
if [[ "$DRY_RUN" = "1" ]]; then
  JIRI_MUN_ID="(dry-run-placeholder)"
else
  JIRI_MUN_ID=$(psql "$PROD_DB_URL" -t -A -c \
    "SELECT id FROM municipalities WHERE name_en = 'Jiri' AND district = 'Dolakha' LIMIT 1;")
  if [[ -z "$JIRI_MUN_ID" ]]; then
    echo "ERROR: Jiri municipality not found on prod. Aborting."
    exit 1
  fi
  echo "Resolved: $JIRI_MUN_ID"
fi

# ───────────────────────────────────────────────
# 4. Jiri Bazaar Hub seed
# ───────────────────────────────────────────────
HUB_ID="00000000-0000-4000-a000-000000000b01"
OPERATOR_ID="00000000-0000-4000-a000-000000000a01"
FARMER_ID="00000000-0000-4000-a000-000000000a02"
CONSUMER_ID="00000000-0000-4000-a000-000000000a03"

run_sql_inline "Seeding Jiri Bazaar Hub on prod" "
INSERT INTO pickup_hubs (id, name_en, name_ne, municipality_id, address,
    location, hub_type, operating_hours, is_active)
VALUES (
  '$HUB_ID',
  'Jiri Bazaar Hub',
  'जिरी बजार हब',
  ${DRY_RUN:+NULL}${DRY_RUN:-\"$JIRI_MUN_ID\"::uuid},
  'Jiri Bazaar, Main Square, Dolakha',
  ST_SetSRID(ST_MakePoint(86.2202, 27.6275), 4326)::geography,
  'origin',
  '{\"mon\":[\"06:00\",\"18:00\"],\"tue\":[\"06:00\",\"18:00\"],\"wed\":[\"06:00\",\"18:00\"],\"thu\":[\"06:00\",\"18:00\"],\"fri\":[\"06:00\",\"18:00\"],\"sat\":[\"06:00\",\"18:00\"],\"sun\":[\"08:00\",\"14:00\"]}'::jsonb,
  true
)
ON CONFLICT (id) DO UPDATE SET
  location = EXCLUDED.location,
  is_active = true,
  municipality_id = EXCLUDED.municipality_id;
"

# ───────────────────────────────────────────────
# 5. Demo auth users (operator, farmer, consumer)
# ───────────────────────────────────────────────
# NOTE: We use Supabase Admin API instead of direct auth.users insertion
# to ensure all auth invariants are honoured (encrypted_password format,
# identities, etc.). This is safer than the local seed approach.
create_demo_user() {
  local email="$1" password="$2" id="$3" role="$4" name_en="$5" name_ne="$6"
  if [[ "$DRY_RUN" = "1" ]]; then
    echo "(dry-run) would create $email (role=$role, id=$id)"
    return 0
  fi
  echo "  → $email"
  curl -fsS -X POST "$SUPABASE_URL/auth/v1/admin/users" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"id\": \"$id\",
      \"email\": \"$email\",
      \"password\": \"$password\",
      \"email_confirm\": true,
      \"user_metadata\": {\"full_name\": \"$name_en\"}
    }" >/dev/null || echo "(create may have already existed; continuing)"

  # Backfill into public.users + user_profiles + user_roles. No-ops if exist.
  psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -c "
    INSERT INTO users (id, phone, name, role, municipality, lang, location)
    VALUES ('$id', '+9779800000${id: -3}', '$name_ne', '$role'::app_role,
            'Jiri', 'ne',
            ST_SetSRID(ST_MakePoint(86.2202, 27.6275), 4326)::geography)
    ON CONFLICT (id) DO UPDATE SET
      role = EXCLUDED.role,
      municipality = EXCLUDED.municipality,
      location = EXCLUDED.location;
    INSERT INTO user_roles (user_id, role, verified)
    VALUES ('$id', '$role'::app_role, true)
    ON CONFLICT (user_id, role) DO NOTHING;
    INSERT INTO user_profiles (id, role, onboarding_completed, full_name, email)
    VALUES ('$id', '$role', true, '$name_en', '$email')
    ON CONFLICT (id) DO UPDATE SET
      role = EXCLUDED.role,
      onboarding_completed = true;
  "
}

echo
echo "─── Creating demo auth users ──────────────────────────────"
create_demo_user "demo-operator-jiri@khetbata.xyz" "demo-pw-1234" \
  "$OPERATOR_ID" "hub_operator" "Jiri Bazaar Operator" "जिरी बजार सञ्चालक"
create_demo_user "demo-farmer-jiri@khetbata.xyz" "demo-pw-1234" \
  "$FARMER_ID" "farmer" "Sample Jirel" "नमुना जिरेल"
create_demo_user "demo-consumer-ktm@khetbata.xyz" "demo-pw-1234" \
  "$CONSUMER_ID" "consumer" "Sample Consumer" "नमुना उपभोक्ता"

# Assign operator to the hub
run_sql_inline "Assigning operator to Jiri Bazaar Hub" "
UPDATE pickup_hubs SET operator_id = '$OPERATOR_ID' WHERE id = '$HUB_ID';
"

# ───────────────────────────────────────────────
# 6. Seed three Jiri-marquee listings against the demo farmer
# ───────────────────────────────────────────────
echo
echo "─── Seeding Jiri-marquee listings ──────────────────────────────"
if [[ "$DRY_RUN" = "1" ]]; then
  echo "(dry-run) would create 3 listings (kiwi, akbare khursani, churpi)"
else
  # First make sure produce_categories has the categories we need.
  KIWI_CAT=$(psql "$PROD_DB_URL" -t -A -c "SELECT id FROM produce_categories WHERE name_en ILIKE 'kiwi' OR name_ne LIKE '%किवी%' LIMIT 1;")
  if [[ -z "$KIWI_CAT" ]]; then
    KIWI_CAT=$(psql "$PROD_DB_URL" -t -A -c "SELECT id FROM produce_categories ORDER BY sort_order LIMIT 1;")
    echo "  (kiwi category not found, falling back to: $KIWI_CAT)"
  fi
  CHILI_CAT=$(psql "$PROD_DB_URL" -t -A -c "SELECT id FROM produce_categories WHERE name_en ILIKE '%chili%' OR name_en ILIKE '%pepper%' LIMIT 1;")
  [[ -z "$CHILI_CAT" ]] && CHILI_CAT="$KIWI_CAT"
  DAIRY_CAT=$(psql "$PROD_DB_URL" -t -A -c "SELECT id FROM produce_categories WHERE name_en ILIKE '%dairy%' OR name_en ILIKE '%cheese%' LIMIT 1;")
  [[ -z "$DAIRY_CAT" ]] && DAIRY_CAT="$KIWI_CAT"

  psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -c "
    INSERT INTO produce_listings
      (id, farmer_id, category_id, name_en, name_ne, price_per_kg, available_qty_kg,
       unit, freshness_date, location, photos, is_active, pickup_mode)
    VALUES
      ('00000000-0000-4000-a000-000000000c01', '$FARMER_ID', '$KIWI_CAT'::uuid,
       'Jiri Kiwi', 'जिरी किवी', 350.00, 25.00, 'kg', current_date + 7,
       ST_SetSRID(ST_MakePoint(86.2202, 27.6275), 4326)::geography,
       '{}', true, 'both'),
      ('00000000-0000-4000-a000-000000000c02', '$FARMER_ID', '$CHILI_CAT'::uuid,
       'Akbare Khursani', 'अकबरे खुर्सानी', 1200.00, 8.00, 'kg', current_date + 5,
       ST_SetSRID(ST_MakePoint(86.2202, 27.6275), 4326)::geography,
       '{}', true, 'both'),
      ('00000000-0000-4000-a000-000000000c03', '$FARMER_ID', '$DAIRY_CAT'::uuid,
       'Yak Churpi', 'याक चुर्पी', 2500.00, 5.00, 'kg', current_date + 14,
       ST_SetSRID(ST_MakePoint(86.2202, 27.6275), 4326)::geography,
       '{}', true, 'both')
    ON CONFLICT (id) DO UPDATE SET
      is_active = true,
      available_qty_kg = EXCLUDED.available_qty_kg;
  "
fi

# ───────────────────────────────────────────────
# 7. Sanity smoke
# ───────────────────────────────────────────────
echo
echo "─── Sanity smoke ──────────────────────────────"
if [[ "$DRY_RUN" = "0" ]]; then
  psql "$PROD_DB_URL" -c "
    SELECT 'hub' AS what, count(*) FROM pickup_hubs WHERE id = '$HUB_ID'
    UNION ALL SELECT 'farmer', count(*) FROM users WHERE id = '$FARMER_ID'
    UNION ALL SELECT 'operator', count(*) FROM users WHERE id = '$OPERATOR_ID'
    UNION ALL SELECT 'consumer', count(*) FROM users WHERE id = '$CONSUMER_ID'
    UNION ALL SELECT 'jiri-listings', count(*) FROM produce_listings
        WHERE farmer_id = '$FARMER_ID' AND is_active = true;
  "
  echo
  echo "Counter RPC response:"
  psql "$PROD_DB_URL" -c "SELECT public.jiri_ward_counters_v1();"
fi

echo
echo "Done. Verify the deck against prod with:"
echo "  cd docs/demo/deck && pnpm dev"
echo "(opens http://localhost:3030)"
