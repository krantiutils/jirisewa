-- Mobile ping actions: atomic accept/decline RPCs for rider app.
-- These functions keep race-sensitive logic in the database.

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

    RETURN QUERY SELECT true, 'Ping accepted', v_ping.order_id, v_ping.trip_id;
END;
$$;

CREATE OR REPLACE FUNCTION decline_order_ping(p_ping_id uuid)
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
        RETURN QUERY SELECT false, 'You can only decline your own pings', NULL::uuid, NULL::uuid;
        RETURN;
    END IF;

    IF v_ping.status <> 'pending' THEN
        RETURN QUERY SELECT false, 'This ping has already been responded to', v_ping.order_id, v_ping.trip_id;
        RETURN;
    END IF;

    UPDATE order_pings
    SET
        status = 'declined',
        responded_at = now()
    WHERE id = p_ping_id;

    RETURN QUERY SELECT true, 'Ping declined', v_ping.order_id, v_ping.trip_id;
END;
$$;

GRANT EXECUTE ON FUNCTION accept_order_ping(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION decline_order_ping(uuid) TO authenticated;
