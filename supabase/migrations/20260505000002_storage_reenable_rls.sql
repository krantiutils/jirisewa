-- The earlier diagnostic disable (20260504000004) is no longer needed: the
-- real fix shipped in 20260505000001 grants supabase_storage_admin
-- membership in anon/authenticated/service_role so the JWT-role switch
-- succeeds and the existing RLS policies do their job. Re-enable RLS.

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop the diagnostic open-everything policy.
DROP POLICY IF EXISTS "diag open produce-photos" ON storage.objects;
