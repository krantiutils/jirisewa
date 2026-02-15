-- Extend accept_order_ping with trip stop insertion for mobile parity.

CREATE OR REPLACE FUNCTION accept_order_ping(p_ping_id uuid)
RETURNS TABLE (
    success boolean,
    message text,
    order_id uuid,
    trip_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ping order_pings%ROWTYPE;
    v_matched_order_id uuid;
    v_next_seq integer;
    v_pickup jsonb;
    v_pickup_lat double precision;
    v_pickup_lng double precision;
    v_pickup_name text;
    v_delivery_lat double precision;
    v_delivery_lng double precision;
    v_delivery_address text;
BEGIN
    SELECT *
    INTO v_ping
    FROM order_pings
    WHERE id = p_ping_id
    FOR UPDATE;

    IF v_ping.id IS NULL THEN
        RETURN QUERY SELECT false, 'Ping not found', NULL::uuid, NULL::uuid;
        RETURN;
    END IF;

    IF auth.uid() IS NULL OR v_ping.rider_id <> auth.uid() THEN
        RETURN QUERY SELECT false, 'You can only accept your own pings', NULL::uuid, NULL::uuid;
        RETURN;
    END IF;

    IF v_ping.status <> 'pending' THEN
        RETURN QUERY SELECT false, 'This ping has already been responded to', v_ping.order_id, v_ping.trip_id;
        RETURN;
    END IF;

    IF v_ping.expires_at < now() THEN
        UPDATE order_pings
        SET status = 'expired', responded_at = now()
        WHERE id = p_ping_id;

        RETURN QUERY SELECT false, 'This ping has expired', v_ping.order_id, v_ping.trip_id;
        RETURN;
    END IF;

    UPDATE orders
    SET
        status = 'matched',
        rider_id = v_ping.rider_id,
        rider_trip_id = v_ping.trip_id
    WHERE id = v_ping.order_id
      AND status = 'pending'
    RETURNING id INTO v_matched_order_id;

    IF v_matched_order_id IS NULL THEN
        UPDATE order_pings
        SET
            status = 'declined',
            responded_at = now()
        WHERE id = p_ping_id;

        RETURN QUERY SELECT false, 'This order was already matched to another rider', v_ping.order_id, v_ping.trip_id;
        RETURN;
    END IF;

    UPDATE order_pings
    SET
        status = 'accepted',
        responded_at = now()
    WHERE id = p_ping_id;

    UPDATE order_pings
    SET
        status = 'expired',
        responded_at = now()
    WHERE order_id = v_ping.order_id
      AND status = 'pending'
      AND id <> p_ping_id;

    UPDATE rider_trips
    SET remaining_capacity_kg = GREATEST(0, remaining_capacity_kg - COALESCE(v_ping.total_weight_kg, 0))
    WHERE id = v_ping.trip_id;

    -- Append pickup and delivery stops at end of current stop list.
    SELECT COALESCE(MAX(sequence_order), -1) + 1
    INTO v_next_seq
    FROM trip_stops
    WHERE trip_id = v_ping.trip_id;

    IF jsonb_typeof(v_ping.pickup_locations) = 'array' THEN
        FOR v_pickup IN
            SELECT value FROM jsonb_array_elements(v_ping.pickup_locations)
        LOOP
            v_pickup_lat := NULLIF(v_pickup->>'lat', '')::double precision;
            v_pickup_lng := NULLIF(v_pickup->>'lng', '')::double precision;
            v_pickup_name := NULLIF(v_pickup->>'farmerName', '');

            IF v_pickup_lat IS NOT NULL AND v_pickup_lng IS NOT NULL THEN
                INSERT INTO trip_stops (
                    trip_id,
                    stop_type,
                    location,
                    address,
                    sequence_order,
                    order_item_ids
                ) VALUES (
                    v_ping.trip_id,
                    'pickup',
                    ST_GeogFromText('POINT(' || v_pickup_lng || ' ' || v_pickup_lat || ')'),
                    v_pickup_name,
                    v_next_seq,
                    '{}'::uuid[]
                );
                v_next_seq := v_next_seq + 1;
            END IF;
        END LOOP;
    END IF;

    IF jsonb_typeof(v_ping.delivery_location) = 'object' THEN
        v_delivery_lat := NULLIF(v_ping.delivery_location->>'lat', '')::double precision;
        v_delivery_lng := NULLIF(v_ping.delivery_location->>'lng', '')::double precision;
        v_delivery_address := NULLIF(v_ping.delivery_location->>'address', '');

        IF v_delivery_lat IS NOT NULL AND v_delivery_lng IS NOT NULL THEN
            INSERT INTO trip_stops (
                trip_id,
                stop_type,
                location,
                address,
                sequence_order,
                order_item_ids
            ) VALUES (
                v_ping.trip_id,
                'delivery',
                ST_GeogFromText('POINT(' || v_delivery_lng || ' ' || v_delivery_lat || ')'),
                v_delivery_address,
                v_next_seq,
                '{}'::uuid[]
            );
        END IF;
    END IF;

    RETURN QUERY SELECT true, 'Ping accepted', v_ping.order_id, v_ping.trip_id;
END;
$$;
