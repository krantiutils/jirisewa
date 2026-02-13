-- Trigger function for auto-updating updated_at columns
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================================
-- users — profile table linked to Supabase Auth
-- ==========================================================
CREATE TABLE users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone text UNIQUE NOT NULL,
    name text NOT NULL,
    role app_role NOT NULL,
    avatar_url text,
    location geography(Point, 4326),
    address text,
    municipality text,
    lang app_language NOT NULL DEFAULT 'ne',
    rating_avg numeric(3,2) NOT NULL DEFAULT 0,
    rating_count integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- user_roles — supports multiple roles per user
-- ==========================================================
CREATE TABLE user_roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role app_role NOT NULL,
    farm_name text,
    vehicle_type vehicle_type,
    vehicle_capacity_kg numeric,
    license_photo_url text,
    verified boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, role)
);

-- ==========================================================
-- produce_categories — curated produce catalog
-- ==========================================================
CREATE TABLE produce_categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en text NOT NULL,
    name_ne text NOT NULL,
    icon text,
    sort_order integer NOT NULL DEFAULT 0
);

-- ==========================================================
-- produce_listings — farmer produce for sale
-- ==========================================================
CREATE TABLE produce_listings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    farmer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id uuid NOT NULL REFERENCES produce_categories(id) ON DELETE RESTRICT,
    name_en text NOT NULL,
    name_ne text NOT NULL,
    description text,
    price_per_kg numeric(10,2) NOT NULL,
    available_qty_kg numeric(10,2) NOT NULL,
    freshness_date date,
    location geography(Point, 4326),
    photos text[] DEFAULT '{}',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER produce_listings_updated_at
    BEFORE UPDATE ON produce_listings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- rider_trips — trips posted by riders
-- ==========================================================
CREATE TABLE rider_trips (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    origin geography(Point, 4326) NOT NULL,
    origin_name text NOT NULL,
    destination geography(Point, 4326) NOT NULL,
    destination_name text NOT NULL,
    route geography(LineString, 4326),
    departure_at timestamptz NOT NULL,
    available_capacity_kg numeric(10,2) NOT NULL,
    remaining_capacity_kg numeric(10,2) NOT NULL,
    status trip_status NOT NULL DEFAULT 'scheduled',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER rider_trips_updated_at
    BEFORE UPDATE ON rider_trips
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- orders — consumer orders
-- ==========================================================
CREATE TABLE orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rider_trip_id uuid REFERENCES rider_trips(id) ON DELETE SET NULL,
    rider_id uuid REFERENCES users(id) ON DELETE SET NULL,
    status order_status NOT NULL DEFAULT 'pending',
    delivery_address text NOT NULL,
    delivery_location geography(Point, 4326) NOT NULL,
    total_price numeric(10,2) NOT NULL,
    delivery_fee numeric(10,2) NOT NULL DEFAULT 0,
    payment_method payment_method NOT NULL DEFAULT 'cash',
    payment_status payment_status NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- order_items — line items within an order
-- ==========================================================
CREATE TABLE order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    listing_id uuid NOT NULL REFERENCES produce_listings(id) ON DELETE RESTRICT,
    farmer_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    quantity_kg numeric(10,2) NOT NULL,
    price_per_kg numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    pickup_location geography(Point, 4326),
    pickup_confirmed boolean NOT NULL DEFAULT false,
    pickup_photo_url text,
    delivery_confirmed boolean NOT NULL DEFAULT false
);

-- ==========================================================
-- ratings — post-order ratings between users
-- ==========================================================
CREATE TABLE ratings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    rater_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rated_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    role_rated role_rated NOT NULL,
    score integer NOT NULL CHECK (score >= 1 AND score <= 5),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (order_id, rater_id, rated_id)
);

-- ==========================================================
-- rider_location_log — partitioned time-series, 7-day TTL
-- ==========================================================
CREATE TABLE rider_location_log (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    rider_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trip_id uuid NOT NULL REFERENCES rider_trips(id) ON DELETE CASCADE,
    location geography(Point, 4326) NOT NULL,
    speed_kmh numeric,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);

-- ==========================================================
-- Partition management for rider_location_log
-- ==========================================================

CREATE OR REPLACE FUNCTION create_location_log_partition(target_date date)
RETURNS void AS $$
DECLARE
    partition_name text;
    start_ts timestamptz;
    end_ts timestamptz;
BEGIN
    partition_name := 'rider_location_log_' || to_char(target_date, 'YYYYMMDD');
    start_ts := target_date::timestamptz;
    end_ts := (target_date + interval '1 day')::timestamptz;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF rider_location_log FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_ts, end_ts
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION drop_old_location_log_partitions(days_to_keep integer DEFAULT 7)
RETURNS void AS $$
DECLARE
    rec record;
    cutoff_date date;
    partition_date date;
    date_str text;
BEGIN
    cutoff_date := current_date - days_to_keep;

    FOR rec IN
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename LIKE 'rider_location_log_%'
    LOOP
        date_str := right(rec.tablename, 8);
        BEGIN
            partition_date := to_date(date_str, 'YYYYMMDD');
            IF partition_date < cutoff_date THEN
                EXECUTE format('DROP TABLE IF EXISTS public.%I', rec.tablename);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL; -- skip tables that don't match date pattern
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION maintain_location_log_partitions()
RETURNS void AS $$
DECLARE
    i integer;
BEGIN
    FOR i IN 0..3 LOOP
        PERFORM create_location_log_partition(current_date + i);
    END LOOP;
    PERFORM drop_old_location_log_partitions(7);
END;
$$ LANGUAGE plpgsql;

-- Create initial partitions (today + 3 days ahead)
SELECT maintain_location_log_partitions();

-- To schedule daily maintenance, enable pg_cron and run:
-- SELECT cron.schedule('maintain-location-partitions', '0 0 * * *', 'SELECT maintain_location_log_partitions()');
