-- Chat feature: conversations and messages for consumer↔rider and consumer↔farmer messaging
-- Part of ts-jzgj

-- Enum for message content types
DO $$ BEGIN
  CREATE TYPE message_type AS ENUM ('text', 'image', 'location');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Chat conversations table
CREATE TABLE IF NOT EXISTS chat_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  participant_ids uuid[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Unique constraint: one conversation per unique pair of participants per order
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_conversations_order_participants
  ON chat_conversations (order_id, participant_ids);

-- Index for listing conversations by participant
CREATE INDEX IF NOT EXISTS idx_chat_conversations_participants
  ON chat_conversations USING GIN (participant_ids);

-- Chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content text NOT NULL,
  message_type message_type NOT NULL DEFAULT 'text',
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for fetching messages in a conversation (chronological)
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation
  ON chat_messages (conversation_id, created_at ASC);

-- Index for counting unread messages for a user
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread
  ON chat_messages (conversation_id, read_at) WHERE read_at IS NULL;

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Conversations: only participants can see their conversations
CREATE POLICY "Users can view their own conversations"
  ON chat_conversations FOR SELECT
  USING (auth.uid() = ANY(participant_ids));

CREATE POLICY "Users can create conversations they participate in"
  ON chat_conversations FOR INSERT
  WITH CHECK (auth.uid() = ANY(participant_ids));

-- Messages: only conversation participants can read/write
CREATE POLICY "Conversation participants can view messages"
  ON chat_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM chat_conversations
      WHERE chat_conversations.id = chat_messages.conversation_id
        AND auth.uid() = ANY(chat_conversations.participant_ids)
    )
  );

CREATE POLICY "Conversation participants can send messages"
  ON chat_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM chat_conversations
      WHERE chat_conversations.id = chat_messages.conversation_id
        AND auth.uid() = ANY(chat_conversations.participant_ids)
    )
  );

CREATE POLICY "Recipients can mark messages as read"
  ON chat_messages FOR UPDATE
  USING (
    sender_id != auth.uid()
    AND EXISTS (
      SELECT 1 FROM chat_conversations
      WHERE chat_conversations.id = chat_messages.conversation_id
        AND auth.uid() = ANY(chat_conversations.participant_ids)
    )
  )
  WITH CHECK (
    -- Only allow updating read_at
    sender_id != auth.uid()
  );

-- ============================================================
-- Realtime: enable for live message updates
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;

-- ============================================================
-- Storage bucket for chat images
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
  VALUES ('chat-images', 'chat-images', true)
  ON CONFLICT (id) DO NOTHING;

-- Storage policies for chat images
CREATE POLICY "Authenticated users can upload chat images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'chat-images');

CREATE POLICY "Anyone can view chat images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'chat-images');
