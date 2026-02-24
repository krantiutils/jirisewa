-- Fix: allow anon (unauthenticated) users to read users and user_roles tables.
-- The marketplace is public but produce_listings joins to users for farmer info
-- and user_roles for verified badge. Without anon SELECT, these joins return null.

CREATE POLICY users_select_anon ON public.users
  FOR SELECT TO anon USING (true);

CREATE POLICY user_roles_select_anon ON public.user_roles
  FOR SELECT TO anon USING (true);
