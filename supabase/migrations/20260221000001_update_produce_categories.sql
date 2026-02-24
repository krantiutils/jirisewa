-- Update produce_categories with Kalimati market data: grouped categories, default_unit, price ranges
-- Also add `unit` column to produce_listings
-- Prices sourced from kalimatimarket.gov.np (Falgun 08, 2082)

-- 1. Add new columns to produce_categories
ALTER TABLE produce_categories
  ADD COLUMN IF NOT EXISTS default_unit text NOT NULL DEFAULT 'kg',
  ADD COLUMN IF NOT EXISTS price_min numeric(10,2),
  ADD COLUMN IF NOT EXISTS price_max numeric(10,2),
  ADD COLUMN IF NOT EXISTS group_en text NOT NULL DEFAULT 'Other',
  ADD COLUMN IF NOT EXISTS group_ne text NOT NULL DEFAULT 'अन्य';

-- 2. Add unit column to produce_listings
ALTER TABLE produce_listings
  ADD COLUMN IF NOT EXISTS unit text NOT NULL DEFAULT 'kg';

-- 3. Replace all categories with Kalimati market data
DELETE FROM produce_categories;

INSERT INTO produce_categories (name_en, name_ne, icon, sort_order, default_unit, price_min, price_max, group_en, group_ne) VALUES
-- ═══ Vegetables ═══
('Tomato (Large)',       'गोलभेडा (ठूलो)',    '🍅', 100, 'kg', 60, 70,     'Vegetables', 'तरकारी'),
('Tomato (Small)',       'गोलभेडा (सानो)',    '🍅', 101, 'kg', 30, 55,     'Vegetables', 'तरकारी'),
('Potato',               'आलु',              '🥔', 102, 'kg', 22, 26,     'Vegetables', 'तरकारी'),
('Onion (Dried)',        'प्याज (सुकेको)',     '🧅', 103, 'kg', 36, 38,     'Vegetables', 'तरकारी'),
('Green Onion',          'हरियो प्याज',       '🧅', 104, 'kg', 30, 40,     'Vegetables', 'तरकारी'),
('Carrot',               'गाजर',             '🥕', 105, 'kg', 40, 60,     'Vegetables', 'तरकारी'),
('Cabbage',              'बन्दा',             '🥬', 106, 'kg', 28, 50,     'Vegetables', 'तरकारी'),
('Red Cabbage',          'रातो बन्दा',        '🥬', 107, 'kg', 60, 80,     'Vegetables', 'तरकारी'),
('Cauliflower',          'काउली',             '🥦', 108, 'kg', 20, 50,     'Vegetables', 'तरकारी'),
('Broccoli',             'ब्रोकाउली',         '🥦', 109, 'kg', 30, 45,     'Vegetables', 'तरकारी'),
('Radish (White)',       'मूला (सेतो)',       '🥕', 110, 'kg', 10, 20,     'Vegetables', 'तरकारी'),
('Radish (Red)',         'मूला (रातो)',       '🥕', 111, 'kg', 25, 35,     'Vegetables', 'तरकारी'),
('Eggplant',             'भन्टा',             '🍆', 112, 'kg', 45, 55,     'Vegetables', 'तरकारी'),
('Cucumber',             'काक्रो',            '🥒', 113, 'kg', 65, 160,    'Vegetables', 'तरकारी'),
('Bitter Gourd',         'करेला',             '🥒', 114, 'kg', 160, 180,   'Vegetables', 'तरकारी'),
('Bottle Gourd',         'लौका',              '🥒', 115, 'kg', 90, 100,    'Vegetables', 'तरकारी'),
('Ridge Gourd',          'घिरौला',            '🥒', 116, 'kg', 130, 140,   'Vegetables', 'तरकारी'),
('Pumpkin',              'फर्सी',             '🎃', 117, 'kg', 15, 55,     'Vegetables', 'तरकारी'),
('Squash',               'स्कूस',             '🥒', 118, 'kg', 50, 60,     'Vegetables', 'तरकारी'),
('Okra',                 'भिण्डी',            '🌿', 119, 'kg', 100, 120,   'Vegetables', 'तरकारी'),
('Sweet Potato',         'सखरखण्ड',           '🍠', 120, 'kg', 60, 70,     'Vegetables', 'तरकारी'),
('Taro',                 'पिंडालू',           '🍠', 121, 'kg', 55, 65,     'Vegetables', 'तरकारी'),
('Yam',                  'तरुल',              '🍠', 122, 'kg', 60, 80,     'Vegetables', 'तरकारी'),
('Turnip',               'सलगम',              '🥕', 123, 'kg', 40, 50,     'Vegetables', 'तरकारी'),
('Beetroot',             'चुकुन्दर',          '🥕', 124, 'kg', 55, 65,     'Vegetables', 'तरकारी'),
('Bamboo Shoot',         'तामा',              '🎋', 125, 'kg', 110, 130,   'Vegetables', 'तरकारी'),

-- ═══ Leafy Greens ═══
('Spinach',              'पालुङ्गो साग',      '🥬', 150, 'kg', 20, 35,     'Leafy Greens', 'साग'),
('Mustard Greens',       'रायो साग',          '🥬', 151, 'kg', 15, 25,     'Leafy Greens', 'साग'),
('Fenugreek Greens',     'मेथीको साग',        '🌿', 152, 'kg', 30, 40,     'Leafy Greens', 'साग'),
('Cress Greens',         'चमसूरको साग',       '🥬', 153, 'kg', 20, 30,     'Leafy Greens', 'साग'),

-- ═══ Beans & Legumes ═══
('Beans',                'सिमी',              '🫘', 170, 'kg', 100, 130,   'Beans & Legumes', 'सिमी र दाल'),
('Flat Beans',           'टाटे सिमी',         '🫘', 171, 'kg', 60, 70,     'Beans & Legumes', 'सिमी र दाल'),
('Peas',                 'मटर',               '🫛', 172, 'kg', 40, 55,     'Beans & Legumes', 'सिमी र दाल'),

-- ═══ Herbs & Spices ═══
('Green Chili',          'हरियो खुर्सानी',    '🌶️', 180, 'kg', 70, 180,   'Herbs & Spices', 'मसला'),
('Dried Chili',          'सुकेको खुर्सानी',   '🌶️', 181, 'kg', 380, 430,  'Herbs & Spices', 'मसला'),
('Garlic (Nepali)',      'लसुन (नेपाली)',     '🧄', 182, 'kg', 180, 200,   'Herbs & Spices', 'मसला'),
('Ginger',               'अदुवा',             '🫚', 183, 'kg', 100, 120,   'Herbs & Spices', 'मसला'),
('Turmeric',             'बेसार',             '🟡', 184, 'kg', 110, 130,   'Herbs & Spices', 'मसला'),
('Coriander',            'हरियो धनिया',       '🌿', 185, 'kg', 30, 40,     'Herbs & Spices', 'मसला'),
('Mint',                 'पुदिना',            '🌿', 186, 'kg', 300, 350,   'Herbs & Spices', 'मसला'),
('Parsley',              'पार्सले',           '🌿', 187, 'kg', 350, 400,   'Herbs & Spices', 'मसला'),
('Celery',               'सेलरी',             '🌿', 188, 'kg', 150, 180,   'Herbs & Spices', 'मसला'),

-- ═══ Mushrooms ═══
('Mushroom (Kanya)',     'च्याउ (कन्य)',      '🍄', 190, 'kg', 110, 140,   'Mushrooms', 'च्याउ'),
('Mushroom (Button)',    'च्याउ (डल्ले)',     '🍄', 191, 'kg', 450, 500,   'Mushrooms', 'च्याउ'),
('King Mushroom',        'राजा च्याउ',        '🍄', 192, 'kg', 280, 300,   'Mushrooms', 'च्याउ'),
('Shiitake Mushroom',    'सिताके च्याउ',      '🍄', 193, 'kg', 800, 1000,  'Mushrooms', 'च्याउ'),

-- ═══ Fruits ═══
('Apple',                'स्याउ',             '🍎', 200, 'kg', 200, 300,   'Fruits', 'फलफूल'),
('Banana',               'केरा',              '🍌', 201, 'dozen', 170, 190, 'Fruits', 'फलफूल'),
('Orange',               'सुन्तला',           '🍊', 202, 'kg', 150, 170,   'Fruits', 'फलफूल'),
('Mandarin',             'किनु',              '🍊', 203, 'kg', 110, 130,   'Fruits', 'फलफूल'),
('Lime',                 'कागती',             '🍋', 204, 'kg', 220, 240,   'Fruits', 'फलफूल'),
('Pomegranate',          'अनार',              '🍎', 205, 'kg', 300, 330,   'Fruits', 'फलफूल'),
('Grape (Green)',        'अंगुर (हरियो)',     '🍇', 206, 'kg', 240, 260,   'Fruits', 'फलफूल'),
('Grape (Black)',        'अंगुर (कालो)',      '🍇', 207, 'kg', 350, 400,   'Fruits', 'फलफूल'),
('Watermelon',           'तरबुजा',            '🍉', 208, 'kg', 80, 90,     'Fruits', 'फलफूल'),
('Pineapple',            'भुइँकटहर',          '🍍', 209, 'piece', 135, 145, 'Fruits', 'फलफूल'),
('Strawberry',           'स्ट्रबेरी',          '🍓', 210, 'kg', 400, 500,   'Fruits', 'फलफूल'),
('Kiwi',                 'किवी',              '🥝', 211, 'kg', 230, 260,   'Fruits', 'फलफूल'),
('Avocado',              'एभोकाडो',           '🥑', 212, 'kg', 250, 350,   'Fruits', 'फलफूल'),
('Pear (Chinese)',       'नासपाती',           '🍐', 213, 'kg', 220, 250,   'Fruits', 'फलफूल'),
('Papaya',               'मेवा',              '🍈', 214, 'kg', 50, 110,    'Fruits', 'फलफूल'),
('Guava',                'अम्बा',             '🍈', 215, 'kg', 50, 110,    'Fruits', 'फलफूल'),
('Amla',                 'अमला',              '🟢', 216, 'kg', 90, 100,    'Fruits', 'फलफूल'),
('Mango',                'आँप',               '🥭', 217, 'kg', NULL, NULL, 'Fruits', 'फलफूल'),

-- ═══ Grains & Cereals ═══
('Rice',                 'चामल',              '🌾', 300, 'kg', NULL, NULL, 'Grains & Cereals', 'अन्न'),
('Wheat',                'गहुँ',              '🌾', 301, 'kg', NULL, NULL, 'Grains & Cereals', 'अन्न'),
('Maize',                'मकै',               '🌽', 302, 'kg', NULL, NULL, 'Grains & Cereals', 'अन्न'),
('Millet',               'कोदो',              '🌾', 303, 'kg', NULL, NULL, 'Grains & Cereals', 'अन्न'),

-- ═══ Dairy ═══
('Milk',                 'दूध',               '🥛', 400, 'liter', NULL, NULL, 'Dairy', 'दुग्ध'),
('Curd',                 'दही',               '🥛', 401, 'kg', NULL, NULL,    'Dairy', 'दुग्ध'),
('Ghee',                 'घिउ',               '🧈', 402, 'kg', NULL, NULL,    'Dairy', 'दुग्ध'),

-- ═══ Other / Processed ═══
('Honey',                'मह',                '🍯', 500, 'kg', NULL, NULL,    'Other', 'अन्य'),
('Jaggery',              'शक्खर',             '🟤', 501, 'kg', NULL, NULL,    'Other', 'अन्य'),
('Tofu',                 'टोफु',              '🧈', 502, 'kg', 130, 150,     'Other', 'अन्य'),
('Gundruk',              'गुन्द्रुक',          '🥬', 503, 'kg', 280, 300,     'Other', 'अन्य'),
('Dried Fish',           'सुकेको माछा',       '🐟', 504, 'kg', 800, 1000,    'Other', 'अन्य');

-- 4. Drop and recreate search_produce_listings RPC to add unit column
DROP FUNCTION IF EXISTS search_produce_listings(
    double precision, double precision, double precision,
    uuid, numeric, numeric, text, text, integer, integer, uuid
);

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
    unit text,
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
            pl.unit,
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
        f.unit,
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
