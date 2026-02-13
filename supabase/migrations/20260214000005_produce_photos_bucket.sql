-- Create storage bucket for produce listing photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'produce-photos',
  'produce-photos',
  true,
  1048576, -- 1MB max per file (client compresses before upload)
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Farmers can upload produce photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'produce-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow authenticated users to update/delete their own photos
CREATE POLICY "Farmers can manage own produce photos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'produce-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Farmers can delete own produce photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'produce-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public read access for produce photos (marketplace browsing)
CREATE POLICY "Anyone can view produce photos"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'produce-photos');
