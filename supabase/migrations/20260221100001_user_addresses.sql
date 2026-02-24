-- Saved delivery addresses for customers
CREATE TABLE user_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  address_text TEXT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Only one default address per user
CREATE UNIQUE INDEX user_addresses_default_idx
  ON user_addresses (user_id) WHERE is_default = true;

CREATE INDEX user_addresses_user_idx ON user_addresses (user_id);

-- RLS: users manage only their own addresses
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own addresses"
  ON user_addresses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own addresses"
  ON user_addresses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own addresses"
  ON user_addresses FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own addresses"
  ON user_addresses FOR DELETE
  USING (auth.uid() = user_id);

-- Service role bypass for server actions
CREATE POLICY "Service role full access on user_addresses"
  ON user_addresses FOR ALL
  USING (current_setting('role') = 'service_role');
