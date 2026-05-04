-- =============================================================================
-- Self-hosted Supabase Storage runs all requests through Postgres as
-- supabase_storage_admin (NOT BYPASSRLS) and evaluates storage.objects RLS
-- against the JWT role claim. Our existing produce-photos policy only
-- allows TO authenticated, so server actions hitting storage with the
-- service_role JWT see "new row violates row-level security policy."
--
-- Add a permissive ALL policy for service_role on every bucket the app
-- uses, so server actions / admin code can bypass per-user folder rules
-- when needed (uploads, cleanup, migration tooling).
-- =============================================================================

-- produce-photos
CREATE POLICY "service_role full access produce-photos"
  ON storage.objects
  AS PERMISSIVE
  FOR ALL
  USING (bucket_id = 'produce-photos' AND auth.role() = 'service_role')
  WITH CHECK (bucket_id = 'produce-photos' AND auth.role() = 'service_role');

-- chat-images / chat-audio (other public buckets we already use)
CREATE POLICY "service_role full access chat-images"
  ON storage.objects
  AS PERMISSIVE
  FOR ALL
  USING (bucket_id = 'chat-images' AND auth.role() = 'service_role')
  WITH CHECK (bucket_id = 'chat-images' AND auth.role() = 'service_role');

CREATE POLICY "service_role full access chat-audio"
  ON storage.objects
  AS PERMISSIVE
  FOR ALL
  USING (bucket_id = 'chat-audio' AND auth.role() = 'service_role')
  WITH CHECK (bucket_id = 'chat-audio' AND auth.role() = 'service_role');

-- verification-docs (private bucket, but admins use service role)
CREATE POLICY "service_role full access verification-docs"
  ON storage.objects
  AS PERMISSIVE
  FOR ALL
  USING (bucket_id = 'verification-docs' AND auth.role() = 'service_role')
  WITH CHECK (bucket_id = 'verification-docs' AND auth.role() = 'service_role');
