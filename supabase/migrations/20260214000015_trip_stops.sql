-- Multi-stop route optimization: trip_stops table and rider_trips enhancements.

-- ==========================================================
-- New enum: stop_type — classifies each stop in a trip
-- ==========================================================
CREATE TYPE stop_type AS ENUM ('pickup', 'delivery');

-- ==========================================================
-- trip_stops — individual stops along a rider's optimized route
-- ==========================================================
CREATE TABLE trip_stops (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id uuid NOT NULL REFERENCES rider_trips(id) ON DELETE CASCADE,
    stop_type stop_type NOT NULL,
    location geography(Point, 4326) NOT NULL,
    address text,
    address_ne text,
    sequence_order integer NOT NULL DEFAULT 0,
    estimated_arrival timestamptz,
    actual_arrival timestamptz,
    order_item_ids uuid[] NOT NULL DEFAULT '{}',
    completed boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trip_stops_updated_at
    BEFORE UPDATE ON trip_stops
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_trip_stops_trip ON trip_stops (trip_id, sequence_order);
CREATE INDEX idx_trip_stops_location ON trip_stops USING GIST (location);

-- ==========================================================
-- Alter rider_trips: add multi-stop routing metadata
-- ==========================================================
ALTER TABLE rider_trips
    ADD COLUMN total_stops integer NOT NULL DEFAULT 0,
    ADD COLUMN optimized_route jsonb,
    ADD COLUMN total_distance_km numeric(10,2),
    ADD COLUMN estimated_duration_minutes integer;

-- ==========================================================
-- RLS for trip_stops
-- ==========================================================
ALTER TABLE trip_stops ENABLE ROW LEVEL SECURITY;

-- Riders can view stops on their own trips
CREATE POLICY trip_stops_select ON trip_stops
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM rider_trips
            WHERE rider_trips.id = trip_stops.trip_id
              AND rider_trips.rider_id = auth.uid()
        )
    );

-- Riders can insert stops on their own trips
CREATE POLICY trip_stops_insert ON trip_stops
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM rider_trips
            WHERE rider_trips.id = trip_stops.trip_id
              AND rider_trips.rider_id = auth.uid()
        )
    );

-- Riders can update stops on their own trips
CREATE POLICY trip_stops_update ON trip_stops
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM rider_trips
            WHERE rider_trips.id = trip_stops.trip_id
              AND rider_trips.rider_id = auth.uid()
        )
    );

-- Consumers can view stops relevant to their orders (for tracking)
CREATE POLICY trip_stops_consumer_select ON trip_stops
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM orders
            JOIN rider_trips ON rider_trips.id = orders.rider_trip_id
            WHERE rider_trips.id = trip_stops.trip_id
              AND orders.consumer_id = auth.uid()
        )
    );
