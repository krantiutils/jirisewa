-- Promote any e2e-farmer-* user to admin and ensure the seeded
-- Jiri Bazaar hub operator is provisioned with a known password.

-- 1. Promote e2e farmer to admin (idempotent — no-op if no match)
UPDATE users SET is_admin = true
 WHERE id IN (
   SELECT u.id FROM users u
   JOIN user_profiles p ON p.id = u.id
   WHERE p.email LIKE 'e2e-farmer-%@jirisewa.test'
 );

-- 2. Provision the hub operator
DO $$
DECLARE
  v_op_id uuid := '00000000-0000-4000-a000-000000000a01';
  v_hub_id uuid := '00000000-0000-4000-a000-000000000b01';
  v_municipality_id uuid;
BEGIN
  INSERT INTO auth.users (
    id, instance_id, aud, role, email,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, email_confirmed_at,
    encrypted_password, confirmation_token,
    recovery_token, email_change_token_new, email_change
  ) VALUES (
    v_op_id, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'jiri-hub-operator@jirisewa.local',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Jiri Bazaar Operator"}'::jsonb,
    now(), now(), now(),
    crypt('hub-operator-pw', gen_salt('bf')),
    '', '', '', ''
  )
  ON CONFLICT (id) DO UPDATE SET
    encrypted_password = crypt('hub-operator-pw', gen_salt('bf')),
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, now());

  INSERT INTO user_profiles (id, email, full_name, role, onboarding_completed)
  VALUES (v_op_id, 'jiri-hub-operator@jirisewa.local',
          'Jiri Bazaar Operator', 'farmer', true)
  ON CONFLICT (id) DO UPDATE SET onboarding_completed = true;

  INSERT INTO users (id, phone, name, role)
  VALUES (v_op_id, 'jiri-hub-operator@jirisewa.local',
          'Jiri Bazaar Operator', 'hub_operator')
  ON CONFLICT (id) DO UPDATE SET role = 'hub_operator';

  INSERT INTO user_roles (user_id, role, verification_status)
  VALUES (v_op_id, 'hub_operator', 'approved')
  ON CONFLICT (user_id, role) DO NOTHING;

  SELECT id INTO v_municipality_id FROM municipalities
   WHERE name_en = 'Jiri' AND district = 'Dolakha' LIMIT 1;
  INSERT INTO pickup_hubs (id, name_en, name_ne, operator_id,
                           municipality_id, address, location, hub_type,
                           is_active)
  VALUES (v_hub_id, 'Jiri Bazaar', 'जिरी बजार', v_op_id,
          v_municipality_id, 'Jiri Bazaar, Dolakha',
          ST_SetSRID(ST_MakePoint(86.230, 27.633), 4326),
          'origin', true)
  ON CONFLICT (id) DO UPDATE SET
    operator_id = v_op_id, is_active = true;
END $$;

-- 3. Confirm
SELECT u.id, p.email, u.role, u.is_admin
  FROM users u
  LEFT JOIN user_profiles p ON p.id = u.id
 WHERE u.is_admin = true OR u.role = 'hub_operator';
