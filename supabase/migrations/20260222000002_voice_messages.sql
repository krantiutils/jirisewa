-- Add 'audio' to the message_type enum for voice messages
ALTER TYPE message_type ADD VALUE IF NOT EXISTS 'audio';

-- Create chat-audio storage bucket (public, matching chat-images pattern)
INSERT INTO storage.buckets (id, name, public)
  VALUES ('chat-audio', 'chat-audio', true)
  ON CONFLICT (id) DO NOTHING;

-- Authenticated users can upload audio
CREATE POLICY "Authenticated users can upload chat audio"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'chat-audio');

-- Anyone can listen to chat audio
CREATE POLICY "Anyone can view chat audio"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'chat-audio');
