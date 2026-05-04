-- Promote ashish@ampixa.com to superadmin (and ensure a `users` row exists
-- in case onboarding upserted into user_profiles only).

DO $$
DECLARE
  v_user_id uuid;
  v_phone text;
  v_full_name text;
  v_email text := 'ashish@ampixa.com';
BEGIN
  -- Find by user_profiles.email (set during email signup) first, then by auth.users.email
  SELECT id INTO v_user_id FROM user_profiles WHERE email = v_email LIMIT 1;
  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE NOTICE 'No user found with email %', v_email;
    RETURN;
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
