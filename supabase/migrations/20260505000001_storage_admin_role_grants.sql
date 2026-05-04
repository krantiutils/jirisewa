-- Supabase Storage connects to Postgres as supabase_storage_admin, then
-- switches into the JWT role for each request. The storage admin role must be
-- a member of the API roles or object uploads fail before RLS is evaluated.
GRANT anon TO supabase_storage_admin;
GRANT authenticated TO supabase_storage_admin;
GRANT service_role TO supabase_storage_admin;
