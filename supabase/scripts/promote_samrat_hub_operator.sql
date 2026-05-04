-- Provision samrat@ampixa.com as hub_operator and assign to the Jiri
-- Bazaar pickup hub (replacing the synthetic seed operator).
-- Idempotent: safe to re-run.

DO $$
DECLARE
  v_user_id uuid;
  v_email   text := 'samrat@ampixa.com';
  v_password text := 'codingjokers';
  v_hub_id  uuid := '00000000-0000-4000-a000-000000000b01';  -- Jiri Bazaar
BEGIN
  -- Find existing
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();
    INSERT INTO auth.users (
      id, instance_id, aud, role, email,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, email_confirmed_at,
      encrypted_password, confirmation_token,
      recovery_token, email_change_token_new, email_change
    ) VALUES (
      v_user_id, '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      v_email,
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"name":"Samrat"}'::jsonb,
      now(), now(), now(),
      crypt(v_password, gen_salt('bf')),
      '', '', '', ''
    );
    RAISE NOTICE 'Created auth.users row for % (id=%)', v_email, v_user_id;
  ELSE
    UPDATE auth.users
       SET encrypted_password = crypt(v_password, gen_salt('bf')),
           email_confirmed_at = COALESCE(email_confirmed_at, now())
     WHERE id = v_user_id;
    RAISE NOTICE 'Updated existing auth.users row for % (id=%)', v_email, v_user_id;
  END IF;

  -- user_profiles (role check allows customer/farmer/rider only — use farmer
  -- as a placeholder; the authoritative role lives in users.role).
  INSERT INTO user_profiles (id, email, full_name, role, onboarding_completed)
  VALUES (v_user_id, v_email, 'Samrat', 'farmer', true)
  ON CONFLICT (id) DO UPDATE SET
    email = COALESCE(user_profiles.email, EXCLUDED.email),
    onboarding_completed = true;

  -- users — authoritative app role
  INSERT INTO users (id, phone, name, role)
  VALUES (v_user_id, v_email, 'Samrat', 'hub_operator')
  ON CONFLICT (id) DO UPDATE SET role = 'hub_operator';

  -- user_roles for compatibility with existing role checks
  INSERT INTO user_roles (user_id, role, verification_status)
  VALUES (v_user_id, 'hub_operator', 'approved')
  ON CONFLICT (user_id, role) DO UPDATE SET verification_status = 'approved';

  -- Reassign the Jiri Bazaar hub to samrat
  UPDATE pickup_hubs SET operator_id = v_user_id WHERE id = v_hub_id;

  RAISE NOTICE 'Assigned hub % to user %', v_hub_id, v_email;
END $$;

-- Confirm
SELECT h.id AS hub_id, h.name_en, h.is_active,
       p.email AS operator_email, u.role, u.is_admin
  FROM pickup_hubs h
  LEFT JOIN users u ON u.id = h.operator_id
  LEFT JOIN user_profiles p ON p.id = h.operator_id
 WHERE h.id = '00000000-0000-4000-a000-000000000b01';
