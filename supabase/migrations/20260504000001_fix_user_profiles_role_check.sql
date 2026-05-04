-- =============================================================================
-- Fix schema drift: user_profiles_role_check on prod was
-- ('consumer', 'farmer', 'rider') but the codebase has always used 'customer'
-- as the role string in user_profiles (Header.tsx, dashboardMap, OAuth
-- callback). Realign the constraint with the code so completeOnboarding can
-- insert role='customer' without violating the check.
--
-- This is a no-op on any environment that already matches the original
-- migration 20260217000001 ('customer','farmer','rider').
-- =============================================================================

ALTER TABLE public.user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE public.user_profiles
  ADD CONSTRAINT user_profiles_role_check
  CHECK (role IS NULL OR role IN ('customer', 'farmer', 'rider'));
