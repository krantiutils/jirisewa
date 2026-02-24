-- Batch ETA calculation for marketplace produce cards.
-- Returns estimated delivery minutes per listing based on farmer location.
CREATE OR REPLACE FUNCTION batch_delivery_etas(
  p_listing_ids UUID[],
  p_delivery_point TEXT,
  p_avg_speed_kmh NUMERIC DEFAULT 30,
  p_pickup_buffer_min INTEGER DEFAULT 15
)
RETURNS TABLE (listing_id UUID, eta_minutes INTEGER)
LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT
    pl.id AS listing_id,
    (p_pickup_buffer_min + CEIL(
      ST_Distance(u.farm_location, p_delivery_point::GEOGRAPHY) / 1000.0
      / p_avg_speed_kmh * 60
    ))::INTEGER AS eta_minutes
  FROM produce_listings pl
  JOIN users u ON u.id = pl.farmer_id
  WHERE pl.id = ANY(p_listing_ids)
    AND u.farm_location IS NOT NULL;
$$;
