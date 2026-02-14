-- ==========================================================
-- Farmer Verification System
-- Adds verification status tracking, document storage,
-- and marketplace search boost for verified farmers.
-- ==========================================================

-- Enum for verification status
CREATE TYPE verification_status AS ENUM ('unverified', 'pending', 'approved', 'rejected');

-- Add verification_status column to user_roles
ALTER TABLE user_roles ADD COLUMN verification_status verification_status NOT NULL DEFAULT 'unverified';

-- Backfill: verified=true rows become 'approved'
UPDATE user_roles SET verification_status = 'approved' WHERE verified = true;

-- Index for the admin verification queue (pending submissions)
CREATE INDEX idx_user_roles_verification_status
    ON user_roles (verification_status) WHERE role = 'farmer';

-- ==========================================================
-- verification_documents — stores farmer document submissions
-- ==========================================================
CREATE TABLE verification_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_role_id uuid NOT NULL REFERENCES user_roles(id) ON DELETE CASCADE,
    citizenship_photo_url text NOT NULL,
    farm_photo_url text NOT NULL,
    municipality_letter_url text,
    admin_notes text,
    reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER verification_documents_updated_at
    BEFORE UPDATE ON verification_documents
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Index for looking up the latest submission per role
CREATE INDEX idx_verification_docs_role ON verification_documents (user_role_id, created_at DESC);

-- ==========================================================
-- RLS for verification_documents
-- ==========================================================
ALTER TABLE verification_documents ENABLE ROW LEVEL SECURITY;

-- Farmers can view their own submissions
CREATE POLICY verification_docs_select ON verification_documents
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_roles.id = verification_documents.user_role_id
              AND user_roles.user_id = auth.uid()
        )
    );

-- Farmers can insert submissions for their own roles
CREATE POLICY verification_docs_insert ON verification_documents
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_roles.id = verification_documents.user_role_id
              AND user_roles.user_id = auth.uid()
        )
    );

-- Admin can read all verification documents
CREATE POLICY admin_verification_docs_select ON verification_documents
    FOR SELECT TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- Admin can update verification documents (add notes, reviewed_by, etc.)
CREATE POLICY admin_verification_docs_update ON verification_documents
    FOR UPDATE TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- ==========================================================
-- Private storage bucket for verification documents
-- ==========================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'verification-docs',
    'verification-docs',
    false,
    5242880, -- 5MB max (citizenship docs may be larger)
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
);

-- Farmers can upload to their own folder
CREATE POLICY "Farmers upload verification docs"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'verification-docs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Farmers can view their own docs
CREATE POLICY "Farmers view own verification docs"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'verification-docs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Admin can view all verification docs
CREATE POLICY "Admin view all verification docs"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'verification-docs'
        AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
    );

-- ==========================================================
-- Update search_produce_listings to include farmer_verified
-- and boost verified farmers in results
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
    farmer_verified boolean,
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
            pc.icon AS category_icon
        FROM produce_listings pl
        JOIN users u ON u.id = pl.farmer_id
        JOIN produce_categories pc ON pc.id = pl.category_id
        LEFT JOIN user_roles ur ON ur.user_id = pl.farmer_id AND ur.role = 'farmer'
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
        f.farmer_verified,
        f.category_name_en,
        f.category_name_ne,
        f.category_icon,
        c.cnt AS total_count
    FROM filtered f
    CROSS JOIN counted c
    ORDER BY
        -- Verified farmers always rank higher within each sort mode
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
