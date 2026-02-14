-- ==========================================================
-- Enable Supabase Realtime on rider_location_log
-- Consumers subscribe to Postgres Changes (INSERT) on this
-- table, filtered by trip_id, to get live rider positions.
-- ==========================================================

-- Add rider_location_log to the supabase_realtime publication
-- so INSERT events are broadcast via Supabase Realtime channels.
ALTER PUBLICATION supabase_realtime ADD TABLE rider_location_log;
