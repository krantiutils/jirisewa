-- RPC function for searching produce listings with PostGIS distance calculations.
-- Called from the Next.js web app to power the marketplace browse/filter/sort.

CREATE OR REPLACE FUNCTION search_produce_listings(
    p_lat double precision,
    p_lng double precision,
    p_radius_km double precision DEFAULT NULL,
    p_category_id uuid DEFAULT NULL,
    p_min_price numeric DEFAULT NULL,
    p_max_price numeric DEFAULT NULL,
    p_search text DEFAULT NULL,
    p_sort_by text DEFAULT 'distance',
    p_limit integer DEFAULT 12,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    id uuid,
    farmer_id uuid,
    category_id uuid,
    name_en text,
    name_ne text,
    description text,
    price_per_kg numeric,
    available_qty_kg numeric,
    freshness_date date,
    location text,
    photos text[],
    is_active boolean,
    created_at timestamptz,
    updated_at timestamptz,
    distance_km double precision,
    farmer_name text,
    farmer_avatar_url text,
    farmer_rating_avg numeric,
    farmer_rating_count integer,
    category_name_en text,
    category_name_ne text,
    category_icon text,
    total_count bigint
) AS $$
DECLARE
    consumer_point geography;
    radius_m double precision;
    safe_search text;
BEGIN
    consumer_point := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
    radius_m := CASE WHEN p_radius_km IS NOT NULL THEN p_radius_km * 1000 ELSE NULL END;
    -- Escape LIKE metacharacters in search input
    safe_search := CASE WHEN p_search IS NOT NULL
        THEN replace(replace(replace(p_search, '\', '\\'), '%', '\%'), '_', '\_')
        ELSE NULL END;

    RETURN QUERY
    WITH filtered AS (
        SELECT
            pl.id,
            pl.farmer_id,
            pl.category_id,
            pl.name_en,
            pl.name_ne,
            pl.description,
            pl.price_per_kg,
            pl.available_qty_kg,
            pl.freshness_date,
            ST_AsText(pl.location) AS location,
            pl.photos,
            pl.is_active,
            pl.created_at,
            pl.updated_at,
            ST_Distance(pl.location, consumer_point) / 1000.0 AS distance_km,
            u.name AS farmer_name,
            u.avatar_url AS farmer_avatar_url,
            u.rating_avg AS farmer_rating_avg,
            u.rating_count AS farmer_rating_count,
            pc.name_en AS category_name_en,
            pc.name_ne AS category_name_ne,
            pc.icon AS category_icon
        FROM produce_listings pl
        JOIN users u ON u.id = pl.farmer_id
        JOIN produce_categories pc ON pc.id = pl.category_id
        WHERE pl.is_active = true
          AND (p_category_id IS NULL OR pl.category_id = p_category_id)
          AND (p_min_price IS NULL OR pl.price_per_kg >= p_min_price)
          AND (p_max_price IS NULL OR pl.price_per_kg <= p_max_price)
          AND (safe_search IS NULL OR pl.name_en ILIKE '%' || safe_search || '%'
                                  OR pl.name_ne ILIKE '%' || safe_search || '%')
          AND (radius_m IS NULL OR pl.location IS NULL
               OR ST_DWithin(pl.location, consumer_point, radius_m))
    ),
    counted AS (
        SELECT count(*) AS cnt FROM filtered
    )
    SELECT
        f.id,
        f.farmer_id,
        f.category_id,
        f.name_en,
        f.name_ne,
        f.description,
        f.price_per_kg,
        f.available_qty_kg,
        f.freshness_date,
        f.location,
        f.photos,
        f.is_active,
        f.created_at,
        f.updated_at,
        f.distance_km,
        f.farmer_name,
        f.farmer_avatar_url,
        f.farmer_rating_avg,
        f.farmer_rating_count,
        f.category_name_en,
        f.category_name_ne,
        f.category_icon,
        c.cnt AS total_count
    FROM filtered f
    CROSS JOIN counted c
    ORDER BY
        CASE WHEN p_sort_by = 'distance' THEN f.distance_km END ASC NULLS LAST,
        CASE WHEN p_sort_by = 'price_asc' THEN f.price_per_kg END ASC,
        CASE WHEN p_sort_by = 'price_desc' THEN f.price_per_kg END DESC,
        CASE WHEN p_sort_by = 'freshness' THEN f.freshness_date END DESC NULLS LAST,
        CASE WHEN p_sort_by = 'rating' THEN f.farmer_rating_avg END DESC,
        f.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE;
