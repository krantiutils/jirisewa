-- Seed the Jiri bazaar hub + a default test hub_operator user.
-- Idempotent: safe to re-run.
--
-- Production note: in real deployments the hub operator will sign up
-- via the normal auth flow and an admin assigns them. This seed exists
-- so local dev and the Playwright/integration tests have a known hub
-- and operator to drive scenarios against.

DO $$
DECLARE
    v_municipality_id uuid;
    v_operator_id uuid := '00000000-0000-4000-a000-000000000a01';  -- deterministic
    v_hub_id      uuid := '00000000-0000-4000-a000-000000000b01';
BEGIN
    SELECT id INTO v_municipality_id FROM municipalities
     WHERE name_en = 'Jiri' AND district = 'Dolakha' LIMIT 1;

    -- 1. auth.users (only if missing).
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, email_confirmed_at, encrypted_password, confirmation_token,
        recovery_token, email_change_token_new, email_change
    ) VALUES (
        v_operator_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'jiri-hub-operator@jirisewa.local',
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"name":"Jiri Bazaar Operator"}'::jsonb,
        now(), now(), now(),
        crypt('hub-operator-pw', gen_salt('bf')),
        '', '', '', ''
    ) ON CONFLICT (id) DO NOTHING;

    -- 2. public.users (operator profile).
    INSERT INTO users (
        id, phone, name, role, address, municipality, lang, location
    ) VALUES (
        v_operator_id,
        '+9779800000050',
        'Jiri Bazaar Operator',
        'hub_operator'::app_role,
        'Jiri Bazaar, Dolakha',
        'Jiri',
        'en',
        ST_SetSRID(ST_MakePoint(86.2310, 27.6298), 4326)::geography
    ) ON CONFLICT (id) DO UPDATE
        SET role = EXCLUDED.role,
            municipality = EXCLUDED.municipality,
            location = EXCLUDED.location;

    -- 3. user_roles (operator).
    INSERT INTO user_roles (user_id, role, verified)
    VALUES (v_operator_id, 'hub_operator'::app_role, true)
    ON CONFLICT (user_id, role) DO NOTHING;

    -- 4. pickup_hub for Jiri bazaar.
    INSERT INTO pickup_hubs (
        id, name_en, name_ne, municipality_id, address,
        location, operator_id, hub_type, operating_hours, is_active
    ) VALUES (
        v_hub_id,
        'Jiri Bazaar Hub',
        'जिरी बजार हब',
        v_municipality_id,
        'Jiri Bazaar, Main Square, Dolakha',
        ST_SetSRID(ST_MakePoint(86.2310, 27.6298), 4326)::geography,
        v_operator_id,
        'origin',
        '{"mon":["06:00","18:00"],"tue":["06:00","18:00"],"wed":["06:00","18:00"],"thu":["06:00","18:00"],"fri":["06:00","18:00"],"sat":["06:00","18:00"],"sun":["08:00","14:00"]}'::jsonb,
        true
    ) ON CONFLICT (id) DO UPDATE
        SET operator_id = EXCLUDED.operator_id,
            location = EXCLUDED.location,
            is_active = true;

    RAISE NOTICE 'Seeded Jiri Bazaar Hub: % (operator: %)', v_hub_id, v_operator_id;
END$$;
