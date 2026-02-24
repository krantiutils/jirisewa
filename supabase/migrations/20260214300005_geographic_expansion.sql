-- ==========================================================
-- Geographic Expansion — location-agnostic marketplace
-- Adds municipalities, service_areas, and region-based pricing
-- ==========================================================

-- ==========================================================
-- municipalities — all Nepal local units (gaunpalika/nagarpalika)
-- ==========================================================
CREATE TABLE municipalities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en text NOT NULL,
    name_ne text NOT NULL,
    district text NOT NULL,
    province integer NOT NULL CHECK (province >= 1 AND province <= 7),
    center geography(Point, 4326),
    population integer,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_municipalities_name ON municipalities (name_en);
CREATE INDEX idx_municipalities_district ON municipalities (district);
CREATE INDEX idx_municipalities_province ON municipalities (province);
CREATE INDEX idx_municipalities_center ON municipalities USING GIST (center);

-- Full-text search index for autocomplete
CREATE INDEX idx_municipalities_search ON municipalities
    USING GIN (to_tsvector('simple', name_en || ' ' || name_ne || ' ' || district));

-- ==========================================================
-- service_areas — admin-defined coverage regions
-- ==========================================================
CREATE TABLE service_areas (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    name_ne text NOT NULL,
    center_point geography(Point, 4326) NOT NULL,
    radius_km numeric(10,2) NOT NULL DEFAULT 50,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_service_areas_center ON service_areas USING GIST (center_point);
CREATE INDEX idx_service_areas_active ON service_areas (is_active) WHERE is_active = true;

CREATE TRIGGER service_areas_updated_at
    BEFORE UPDATE ON service_areas
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- Add municipality references to existing tables
-- ==========================================================

-- produce_listings: which municipality the produce is in
ALTER TABLE produce_listings
    ADD COLUMN municipality_id uuid REFERENCES municipalities(id) ON DELETE SET NULL;

CREATE INDEX idx_listings_municipality ON produce_listings (municipality_id);

-- rider_trips: origin and destination municipalities
ALTER TABLE rider_trips
    ADD COLUMN origin_municipality_id uuid REFERENCES municipalities(id) ON DELETE SET NULL,
    ADD COLUMN destination_municipality_id uuid REFERENCES municipalities(id) ON DELETE SET NULL;

CREATE INDEX idx_trips_origin_municipality ON rider_trips (origin_municipality_id);
CREATE INDEX idx_trips_destination_municipality ON rider_trips (destination_municipality_id);

-- ==========================================================
-- delivery_rates: region-based pricing multipliers
-- ==========================================================
ALTER TABLE delivery_rates
    ADD COLUMN region_multiplier numeric(4,2) NOT NULL DEFAULT 1.00,
    ADD COLUMN applies_to_province integer;

-- ==========================================================
-- RLS policies for new tables
-- ==========================================================
ALTER TABLE municipalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_areas ENABLE ROW LEVEL SECURITY;

-- Municipalities are public read
CREATE POLICY municipalities_select ON municipalities
    FOR SELECT TO authenticated USING (true);

-- Allow anon reads too (for public marketplace)
CREATE POLICY municipalities_select_anon ON municipalities
    FOR SELECT TO anon USING (true);

-- Service areas are public read
CREATE POLICY service_areas_select ON service_areas
    FOR SELECT TO authenticated USING (true);

CREATE POLICY service_areas_select_anon ON service_areas
    FOR SELECT TO anon USING (true);

-- Only service role (admin) can insert/update municipalities and service_areas
-- (no policies needed for service_role — it bypasses RLS)

-- ==========================================================
-- search_municipalities — autocomplete RPC for municipality picker
-- ==========================================================
CREATE OR REPLACE FUNCTION search_municipalities(
    p_query text DEFAULT NULL,
    p_province integer DEFAULT NULL,
    p_district text DEFAULT NULL,
    p_limit integer DEFAULT 20
)
RETURNS TABLE (
    id uuid,
    name_en text,
    name_ne text,
    district text,
    province integer,
    center_lat double precision,
    center_lng double precision
) AS $$
DECLARE
    safe_query text;
BEGIN
    safe_query := CASE WHEN p_query IS NOT NULL AND length(trim(p_query)) > 0
        THEN replace(replace(replace(trim(p_query), '\', '\\'), '%', '\%'), '_', '\_')
        ELSE NULL END;

    RETURN QUERY
    SELECT
        m.id,
        m.name_en,
        m.name_ne,
        m.district,
        m.province,
        CASE WHEN m.center IS NOT NULL
            THEN ST_Y(m.center::geometry)
            ELSE NULL
        END AS center_lat,
        CASE WHEN m.center IS NOT NULL
            THEN ST_X(m.center::geometry)
            ELSE NULL
        END AS center_lng
    FROM municipalities m
    WHERE (safe_query IS NULL
           OR m.name_en ILIKE '%' || safe_query || '%'
           OR m.name_ne ILIKE '%' || safe_query || '%'
           OR m.district ILIKE '%' || safe_query || '%')
      AND (p_province IS NULL OR m.province = p_province)
      AND (p_district IS NULL OR m.district ILIKE '%' || p_district || '%')
    ORDER BY
        CASE WHEN safe_query IS NOT NULL AND m.name_en ILIKE safe_query || '%' THEN 0
             WHEN safe_query IS NOT NULL AND m.name_en ILIKE '%' || safe_query || '%' THEN 1
             ELSE 2
        END,
        m.name_en ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- ==========================================================
-- Update search_produce_listings to accept municipality filter
-- ==========================================================
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
    p_offset integer DEFAULT 0,
    p_municipality_id uuid DEFAULT NULL
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
    farmer_verified boolean,
    category_name_en text,
    category_name_ne text,
    category_icon text,
    total_count bigint,
    municipality_name_en text,
    municipality_name_ne text
) AS $$
DECLARE
    consumer_point geography;
    radius_m double precision;
    safe_search text;
BEGIN
    consumer_point := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
    radius_m := CASE WHEN p_radius_km IS NOT NULL THEN p_radius_km * 1000 ELSE NULL END;
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
            COALESCE(ur.verified, false) AS farmer_verified,
            pc.name_en AS category_name_en,
            pc.name_ne AS category_name_ne,
            pc.icon AS category_icon,
            m.name_en AS municipality_name_en,
            m.name_ne AS municipality_name_ne
        FROM produce_listings pl
        JOIN users u ON u.id = pl.farmer_id
        JOIN produce_categories pc ON pc.id = pl.category_id
        LEFT JOIN user_roles ur ON ur.user_id = pl.farmer_id AND ur.role = 'farmer'
        LEFT JOIN municipalities m ON m.id = pl.municipality_id
        WHERE pl.is_active = true
          AND (p_category_id IS NULL OR pl.category_id = p_category_id)
          AND (p_min_price IS NULL OR pl.price_per_kg >= p_min_price)
          AND (p_max_price IS NULL OR pl.price_per_kg <= p_max_price)
          AND (safe_search IS NULL OR pl.name_en ILIKE '%' || safe_search || '%'
                                  OR pl.name_ne ILIKE '%' || safe_search || '%')
          AND (radius_m IS NULL OR pl.location IS NULL
               OR ST_DWithin(pl.location, consumer_point, radius_m))
          AND (p_municipality_id IS NULL OR pl.municipality_id = p_municipality_id)
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
        f.farmer_verified,
        f.category_name_en,
        f.category_name_ne,
        f.category_icon,
        c.cnt AS total_count,
        f.municipality_name_en,
        f.municipality_name_ne
    FROM filtered f
    CROSS JOIN counted c
    ORDER BY
        f.farmer_verified DESC,
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

-- ==========================================================
-- Seed municipalities — major local units across all 7 provinces
-- Each province has its key municipalities/sub-metros/metros
-- Full 753 list should be bulk-loaded from official CBS data
-- ==========================================================
INSERT INTO municipalities (name_en, name_ne, district, province, center) VALUES
-- Province 1 (Koshi)
('Biratnagar', 'विराटनगर', 'Morang', 1, ST_SetSRID(ST_MakePoint(87.2718, 26.4525), 4326)::geography),
('Dharan', 'धरान', 'Sunsari', 1, ST_SetSRID(ST_MakePoint(87.2838, 26.8123), 4326)::geography),
('Itahari', 'इटहरी', 'Sunsari', 1, ST_SetSRID(ST_MakePoint(87.2747, 26.6643), 4326)::geography),
('Birtamod', 'बिर्तामोड', 'Jhapa', 1, ST_SetSRID(ST_MakePoint(87.9539, 26.6486), 4326)::geography),
('Damak', 'दमक', 'Jhapa', 1, ST_SetSRID(ST_MakePoint(87.6941, 26.6627), 4326)::geography),
('Inaruwa', 'इनरुवा', 'Sunsari', 1, ST_SetSRID(ST_MakePoint(87.1377, 26.6049), 4326)::geography),
('Ilam', 'इलाम', 'Ilam', 1, ST_SetSRID(ST_MakePoint(87.9273, 26.9095), 4326)::geography),
('Diktel', 'दिक्तेल', 'Khotang', 1, ST_SetSRID(ST_MakePoint(86.7972, 27.2186), 4326)::geography),
('Solukhumbu', 'सोलुखुम्बु', 'Solukhumbu', 1, ST_SetSRID(ST_MakePoint(86.5833, 27.7903), 4326)::geography),
('Okhaldhunga', 'ओखलढुङ्गा', 'Okhaldhunga', 1, ST_SetSRID(ST_MakePoint(86.5006, 27.3147), 4326)::geography),

-- Province 2 (Madhesh)
('Janakpur', 'जनकपुर', 'Dhanusha', 2, ST_SetSRID(ST_MakePoint(85.9260, 26.7288), 4326)::geography),
('Birgunj', 'वीरगञ्ज', 'Parsa', 2, ST_SetSRID(ST_MakePoint(84.8769, 27.0104), 4326)::geography),
('Rajbiraj', 'राजविराज', 'Saptari', 2, ST_SetSRID(ST_MakePoint(86.7452, 26.5393), 4326)::geography),
('Kalaiya', 'कलैया', 'Bara', 2, ST_SetSRID(ST_MakePoint(84.9682, 27.0327), 4326)::geography),
('Gaur', 'गौर', 'Rautahat', 2, ST_SetSRID(ST_MakePoint(85.2801, 26.7619), 4326)::geography),
('Lahan', 'लहान', 'Siraha', 2, ST_SetSRID(ST_MakePoint(86.4819, 26.7127), 4326)::geography),
('Malangwa', 'मलङ्गवा', 'Sarlahi', 2, ST_SetSRID(ST_MakePoint(85.5567, 26.8635), 4326)::geography),
('Jaleshwar', 'जलेश्वर', 'Mahottari', 2, ST_SetSRID(ST_MakePoint(85.8001, 26.6471), 4326)::geography),

-- Bagmati Province (3)
('Kathmandu', 'काठमाडौं', 'Kathmandu', 3, ST_SetSRID(ST_MakePoint(85.3240, 27.7172), 4326)::geography),
('Lalitpur', 'ललितपुर', 'Lalitpur', 3, ST_SetSRID(ST_MakePoint(85.3264, 27.6686), 4326)::geography),
('Bhaktapur', 'भक्तपुर', 'Bhaktapur', 3, ST_SetSRID(ST_MakePoint(85.4280, 27.6710), 4326)::geography),
('Hetauda', 'हेटौंडा', 'Makwanpur', 3, ST_SetSRID(ST_MakePoint(85.0322, 27.4288), 4326)::geography),
('Bharatpur', 'भरतपुर', 'Chitwan', 3, ST_SetSRID(ST_MakePoint(84.4333, 27.6833), 4326)::geography),
('Bidur', 'बिदुर', 'Nuwakot', 3, ST_SetSRID(ST_MakePoint(85.1637, 27.9022), 4326)::geography),
('Dhulikhel', 'धुलिखेल', 'Kavrepalanchok', 3, ST_SetSRID(ST_MakePoint(85.5556, 27.6222), 4326)::geography),
('Chautara', 'चौतारा', 'Sindhupalchok', 3, ST_SetSRID(ST_MakePoint(85.7167, 27.7833), 4326)::geography),
('Jiri', 'जिरी', 'Dolakha', 3, ST_SetSRID(ST_MakePoint(86.2305, 27.6306), 4326)::geography),
('Charikot', 'चरिकोट', 'Dolakha', 3, ST_SetSRID(ST_MakePoint(86.0504, 27.6674), 4326)::geography),
('Sindhuli', 'सिन्धुली', 'Sindhuli', 3, ST_SetSRID(ST_MakePoint(85.9722, 27.2567), 4326)::geography),
('Ramechhap', 'रामेछाप', 'Ramechhap', 3, ST_SetSRID(ST_MakePoint(86.0847, 27.3278), 4326)::geography),

-- Gandaki Province (4)
('Pokhara', 'पोखरा', 'Kaski', 4, ST_SetSRID(ST_MakePoint(83.9856, 28.2096), 4326)::geography),
('Gorkha', 'गोरखा', 'Gorkha', 4, ST_SetSRID(ST_MakePoint(84.6295, 28.0000), 4326)::geography),
('Damauli', 'दमौली', 'Tanahun', 4, ST_SetSRID(ST_MakePoint(84.2729, 27.9686), 4326)::geography),
('Baglung', 'बागलुङ', 'Baglung', 4, ST_SetSRID(ST_MakePoint(83.5956, 28.2694), 4326)::geography),
('Besisahar', 'बेसीसहर', 'Lamjung', 4, ST_SetSRID(ST_MakePoint(84.3919, 28.2350), 4326)::geography),
('Waling', 'वालिङ', 'Syangja', 4, ST_SetSRID(ST_MakePoint(83.7833, 28.0500), 4326)::geography),
('Kushma', 'कुश्मा', 'Parbat', 4, ST_SetSRID(ST_MakePoint(83.5500, 28.2167), 4326)::geography),
('Beni', 'बेनी', 'Myagdi', 4, ST_SetSRID(ST_MakePoint(83.5667, 28.3500), 4326)::geography),

-- Lumbini Province (5)
('Butwal', 'बुटवल', 'Rupandehi', 5, ST_SetSRID(ST_MakePoint(83.4485, 27.7006), 4326)::geography),
('Bhairahawa', 'भैरहवा', 'Rupandehi', 5, ST_SetSRID(ST_MakePoint(83.4515, 27.5063), 4326)::geography),
('Nepalgunj', 'नेपालगन्ज', 'Banke', 5, ST_SetSRID(ST_MakePoint(81.6167, 28.0500), 4326)::geography),
('Tansen', 'तानसेन', 'Palpa', 5, ST_SetSRID(ST_MakePoint(83.5451, 27.8689), 4326)::geography),
('Tulsipur', 'तुलसीपुर', 'Dang', 5, ST_SetSRID(ST_MakePoint(82.2973, 28.1311), 4326)::geography),
('Ghorahi', 'घोराही', 'Dang', 5, ST_SetSRID(ST_MakePoint(82.4884, 28.0453), 4326)::geography),
('Kapilvastu', 'कपिलवस्तु', 'Kapilvastu', 5, ST_SetSRID(ST_MakePoint(83.0576, 27.5693), 4326)::geography),
('Deukhuri', 'देउखुरी', 'Dang', 5, ST_SetSRID(ST_MakePoint(82.3833, 27.9500), 4326)::geography),

-- Karnali Province (6)
('Birendranagar', 'वीरेन्द्रनगर', 'Surkhet', 6, ST_SetSRID(ST_MakePoint(81.6346, 28.6000), 4326)::geography),
('Jumla', 'जुम्ला', 'Jumla', 6, ST_SetSRID(ST_MakePoint(82.1833, 29.2747), 4326)::geography),
('Dailekh', 'दैलेख', 'Dailekh', 6, ST_SetSRID(ST_MakePoint(81.7167, 28.8500), 4326)::geography),
('Dunai', 'दुनै', 'Dolpa', 6, ST_SetSRID(ST_MakePoint(82.8931, 28.9514), 4326)::geography),
('Simikot', 'सिमिकोट', 'Humla', 6, ST_SetSRID(ST_MakePoint(81.8306, 29.9681), 4326)::geography),
('Musikot', 'मुसिकोट', 'Rukum West', 6, ST_SetSRID(ST_MakePoint(82.4833, 28.6333), 4326)::geography),

-- Sudurpashchim Province (7)
('Dhangadhi', 'धनगढी', 'Kailali', 7, ST_SetSRID(ST_MakePoint(80.5962, 28.6946), 4326)::geography),
('Mahendranagar', 'महेन्द्रनगर', 'Kanchanpur', 7, ST_SetSRID(ST_MakePoint(80.1820, 28.9637), 4326)::geography),
('Tikapur', 'टीकापुर', 'Kailali', 7, ST_SetSRID(ST_MakePoint(81.1167, 28.5333), 4326)::geography),
('Dipayal', 'दिपायल', 'Doti', 7, ST_SetSRID(ST_MakePoint(80.9500, 29.2500), 4326)::geography),
('Dadeldhura', 'डडेलधुरा', 'Dadeldhura', 7, ST_SetSRID(ST_MakePoint(80.5833, 29.3000), 4326)::geography),
('Amargadhi', 'अमरगढी', 'Dadeldhura', 7, ST_SetSRID(ST_MakePoint(80.5500, 29.2833), 4326)::geography),
('Bajhang', 'बझाङ', 'Bajhang', 7, ST_SetSRID(ST_MakePoint(81.1833, 29.5333), 4326)::geography),
('Bajura', 'बाजुरा', 'Bajura', 7, ST_SetSRID(ST_MakePoint(81.3500, 29.4500), 4326)::geography);

-- ==========================================================
-- Seed initial service areas for major corridors
-- ==========================================================
INSERT INTO service_areas (name, name_ne, center_point, radius_km) VALUES
('Kathmandu Valley', 'काठमाडौं उपत्यका',
    ST_SetSRID(ST_MakePoint(85.3240, 27.7172), 4326)::geography, 30),
('Jiri-Dolakha', 'जिरी-दोलखा',
    ST_SetSRID(ST_MakePoint(86.2305, 27.6306), 4326)::geography, 25),
('Pokhara Valley', 'पोखरा उपत्यका',
    ST_SetSRID(ST_MakePoint(83.9856, 28.2096), 4326)::geography, 25),
('Biratnagar-Dharan', 'विराटनगर-धरान',
    ST_SetSRID(ST_MakePoint(87.2718, 26.4525), 4326)::geography, 30),
('Chitwan', 'चितवन',
    ST_SetSRID(ST_MakePoint(84.4333, 27.6833), 4326)::geography, 25),
('Lumbini-Butwal', 'लुम्बिनी-बुटवल',
    ST_SetSRID(ST_MakePoint(83.4485, 27.7006), 4326)::geography, 30),
('Nepalgunj', 'नेपालगन्ज',
    ST_SetSRID(ST_MakePoint(81.6167, 28.0500), 4326)::geography, 20),
('Dhangadhi', 'धनगढी',
    ST_SetSRID(ST_MakePoint(80.5962, 28.6946), 4326)::geography, 20);

-- ==========================================================
-- popular_routes — featured corridors for route suggestions
-- ==========================================================
CREATE TABLE popular_routes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    origin_municipality_id uuid NOT NULL REFERENCES municipalities(id) ON DELETE CASCADE,
    destination_municipality_id uuid NOT NULL REFERENCES municipalities(id) ON DELETE CASCADE,
    display_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    trip_count integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (origin_municipality_id, destination_municipality_id)
);

ALTER TABLE popular_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY popular_routes_select ON popular_routes
    FOR SELECT TO authenticated USING (true);
CREATE POLICY popular_routes_select_anon ON popular_routes
    FOR SELECT TO anon USING (true);

-- Seed popular routes using subqueries to look up municipality IDs
INSERT INTO popular_routes (origin_municipality_id, destination_municipality_id, display_order)
SELECT o.id, d.id, 1
FROM municipalities o, municipalities d
WHERE o.name_en = 'Jiri' AND d.name_en = 'Kathmandu';

INSERT INTO popular_routes (origin_municipality_id, destination_municipality_id, display_order)
SELECT o.id, d.id, 2
FROM municipalities o, municipalities d
WHERE o.name_en = 'Kathmandu' AND d.name_en = 'Pokhara';

INSERT INTO popular_routes (origin_municipality_id, destination_municipality_id, display_order)
SELECT o.id, d.id, 3
FROM municipalities o, municipalities d
WHERE o.name_en = 'Biratnagar' AND d.name_en = 'Kathmandu';

INSERT INTO popular_routes (origin_municipality_id, destination_municipality_id, display_order)
SELECT o.id, d.id, 4
FROM municipalities o, municipalities d
WHERE o.name_en = 'Bharatpur' AND d.name_en = 'Kathmandu';

INSERT INTO popular_routes (origin_municipality_id, destination_municipality_id, display_order)
SELECT o.id, d.id, 5
FROM municipalities o, municipalities d
WHERE o.name_en = 'Butwal' AND d.name_en = 'Kathmandu';

INSERT INTO popular_routes (origin_municipality_id, destination_municipality_id, display_order)
SELECT o.id, d.id, 6
FROM municipalities o, municipalities d
WHERE o.name_en = 'Dhangadhi' AND d.name_en = 'Kathmandu';
