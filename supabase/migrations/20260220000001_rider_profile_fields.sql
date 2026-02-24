-- Add rider-specific fields to user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS vehicle_type text CHECK (vehicle_type IN ('bike','car','truck','bus','other')),
  ADD COLUMN IF NOT EXISTS fixed_route_origin geography(Point, 4326),
  ADD COLUMN IF NOT EXISTS fixed_route_origin_name text,
  ADD COLUMN IF NOT EXISTS fixed_route_destination geography(Point, 4326),
  ADD COLUMN IF NOT EXISTS fixed_route_destination_name text;
