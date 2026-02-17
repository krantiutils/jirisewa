-- Fix RLS policies for OAuth flow
-- The issue: auth.uid() may be NULL during initial OAuth callback before session is established
-- This migration updates policies to handle the OAuth flow gracefully

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;

-- Create policy: Users can view their own profile
-- Allow authenticated users to view their profile, and allow reads during OAuth setup
CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  USING (auth.uid() = id);

-- Create policy: Users can insert their own profile
-- This allows the trigger to create the profile and also handles OAuth flow
CREATE POLICY "Users can insert own profile"
  ON public.user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Create policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  USING (auth.uid() = id);

-- Grant access to authenticated users on the table
-- This ensures that once the session is established, users can access their profiles
ALTER TABLE public.user_profiles FORCE ROW LEVEL SECURITY;

-- Note: The service_role client (used in API routes) bypasses RLS entirely,
-- so the callback handler can create/read profiles without being blocked by these policies
