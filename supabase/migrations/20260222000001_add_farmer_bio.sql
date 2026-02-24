-- Add bio field to user_profiles for farmer stories
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS bio text;
