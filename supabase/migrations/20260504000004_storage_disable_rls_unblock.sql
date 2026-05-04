-- =============================================================================
-- TEMPORARY UNBLOCK. Disables RLS on storage.objects so launch testing
-- (photo uploads, chat images, etc.) can proceed. Re-enable with proper
-- service_role + per-user-folder policies once we understand why the
-- storage v1.37 layer wasn't honoring our existing role-based policy.
--
-- Re-enable later with:
--   ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
-- =============================================================================

ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;
