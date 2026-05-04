-- Provision (if missing) and promote ashish@ampixa.com to superadmin.
-- Idempotent: safe to re-run.

DO $$
DECLARE
  v_user_id uuid;
  v_phone text;
  v_full_name text;
  v_email text := 'ashish@ampixa.com';
  v_password text := 'codingjokers';
BEGIN
  -- Find existing
  SELECT id INTO v_user_id FROM user_profiles WHERE email = v_email LIMIT 1;
  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    -- Create fresh auth.users row
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
      '{"name":"Ashish"}'::jsonb,
      now(), now(), now(),
      crypt(v_password, gen_salt('bf')),
      '', '', '', ''
    );
    RAISE NOTICE 'Created auth.users row for % (id=%)', v_email, v_user_id;
  ELSE
    -- Reset password + ensure email is confirmed
    UPDATE auth.users
       SET encrypted_password = crypt(v_password, gen_salt('bf')),
           email_confirmed_at = COALESCE(email_confirmed_at, now())
     WHERE id = v_user_id;
    RAISE NOTICE 'Updated existing auth.users row for % (id=%)', v_email, v_user_id;
  END IF;

  -- Make sure user_profiles exists
  INSERT INTO user_profiles (id, email, role, onboarding_completed)
  VALUES (v_user_id, v_email, 'customer', true)
  ON CONFLICT (id) DO UPDATE SET email = COALESCE(user_profiles.email, EXCLUDED.email);

  SELECT COALESCE(full_name, email, 'Ashish') INTO v_full_name FROM user_profiles WHERE id = v_user_id;
  SELECT COALESCE(phone, email) INTO v_phone FROM user_profiles WHERE id = v_user_id;

  -- Ensure users row exists with is_admin = true
  INSERT INTO users (id, phone, name, role, is_admin)
  VALUES (v_user_id, v_phone, v_full_name, 'consumer', true)
  ON CONFLICT (id) DO UPDATE SET is_admin = true;

  RAISE NOTICE 'Promoted % (id=%) to admin', v_email, v_user_id;
END $$;

-- Confirm
SELECT u.id, p.email, u.name, u.role, u.is_admin
  FROM users u
  LEFT JOIN user_profiles p ON p.id = u.id
 WHERE p.email = 'ashish@ampixa.com';
