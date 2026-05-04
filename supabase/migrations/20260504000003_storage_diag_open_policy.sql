-- TEMPORARY DIAGNOSTIC. Drops any restrictive policies and adds an
-- always-true permissive policy on storage.objects for produce-photos.
-- If uploads still fail with "new row violates row-level security
-- policy", the rejection is from somewhere other than the RLS engine
-- (e.g. an app-level check). If they succeed, the previous role-based
-- policies were somehow not matching.
--
-- This will be removed once we understand what's happening.

CREATE POLICY "diag open produce-photos"
  ON storage.objects
  AS PERMISSIVE
  FOR ALL
  USING (bucket_id = 'produce-photos')
  WITH CHECK (bucket_id = 'produce-photos');
