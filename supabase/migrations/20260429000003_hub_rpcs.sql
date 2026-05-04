-- Phase 1 — Aggregation Hubs: RPCs, hub-aware order placement, and
-- notification triggers.
--
-- This migration:
--   1. Adds a lot-code generator (collision-resistant short codes per hub).
--   2. Adds farmer-callable record_hub_dropoff_v1 (creates a dropoff).
--   3. Adds operator-callable mark_dropoff_received_v1 (dropped_off→in_inventory).
--   4. Adds dispatch_dropoff_v1 (in_inventory→dispatched, called when a rider
--      confirms hub pickup or when a trip is matched to the dropoff).
--   5. Updates place_order_v1: when an item's listing has pickup_mode in
--      ('hub_dropoff','both') and a live in_inventory dropoff exists for
--      that listing, link the order_item to the dropoff and use the hub
--      location as pickup_location. Matcher path unchanged downstream.
--   6. Adds expire_stale_dropoffs_v1 — a scheduler-callable function to
--      flip dropoffs past expires_at to status='expired'. Wired to pg_cron
--      in a follow-up env-specific migration (not here, since pg_cron may
--      not be installed on every environment).
--   7. Adds trigger trg_hub_dropoff_notify on hub_dropoffs that fires
--      create_notification on status transitions.

-- ---------------------------------------------------------------------------
-- 1. Lot code generator
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_hub_lot_code(p_hub_id uuid)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- omit I,O,0,1
    v_code text;
    v_len  int := 6;
    v_attempts int := 0;
    v_max_attempts int := 20;
BEGIN
    LOOP
        v_code := '';
        FOR i IN 1..v_len LOOP
            v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
        END LOOP;

        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM hub_dropoffs WHERE hub_id = p_hub_id AND lot_code = v_code
        );

        v_attempts := v_attempts + 1;
        IF v_attempts >= v_max_attempts THEN
            -- Fall back to longer code if collisions persist (extremely unlikely
            -- at 32^6 ≈ 1B codespace per hub).
            v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1)
                              || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
            EXIT;
        END IF;
    END LOOP;

    RETURN v_code;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_hub_lot_code(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_hub_lot_code(uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 2. record_hub_dropoff_v1 — farmer-callable
-- ---------------------------------------------------------------------------
-- Permissions: caller must be the farmer who owns the listing.
-- Returns: { dropoff_id, lot_code, expires_at }
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_hub_dropoff_v1(
    p_hub_id uuid,
    p_listing_id uuid,
    p_quantity_kg numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_listing record;
    v_hub record;
    v_dropoff_id uuid;
    v_lot_code text;
    v_expires_at timestamptz;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;
    IF p_quantity_kg IS NULL OR p_quantity_kg <= 0 THEN
        RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE = '22023';
    END IF;

    SELECT id, farmer_id, is_active, pickup_mode INTO v_listing
      FROM produce_listings WHERE id = p_listing_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Listing % not found', p_listing_id USING ERRCODE = 'P0002';
    END IF;
    IF v_listing.farmer_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the listing owner can record a dropoff' USING ERRCODE = '42501';
    END IF;
    IF NOT v_listing.is_active THEN
        RAISE EXCEPTION 'Listing is inactive' USING ERRCODE = '22023';
    END IF;

    SELECT id, is_active, hub_type INTO v_hub
      FROM pickup_hubs WHERE id = p_hub_id;
    IF NOT FOUND OR NOT v_hub.is_active THEN
        RAISE EXCEPTION 'Hub not found or inactive' USING ERRCODE = 'P0002';
    END IF;
    IF v_hub.hub_type NOT IN ('origin','transit') THEN
        RAISE EXCEPTION 'Cannot drop off at a destination-only hub' USING ERRCODE = '22023';
    END IF;

    v_lot_code := public.generate_hub_lot_code(p_hub_id);
    v_expires_at := now() + interval '48 hours';

    INSERT INTO hub_dropoffs (
        hub_id, farmer_id, listing_id, quantity_kg, lot_code,
        status, dropped_at, expires_at
    ) VALUES (
        p_hub_id, v_user_id, p_listing_id, p_quantity_kg, v_lot_code,
        'dropped_off', now(), v_expires_at
    ) RETURNING id INTO v_dropoff_id;

    -- Auto-flip listing to hub-aware mode if it was farm-pickup-only.
    IF v_listing.pickup_mode = 'farm_pickup' THEN
        UPDATE produce_listings SET pickup_mode = 'both' WHERE id = p_listing_id;
    END IF;

    RETURN jsonb_build_object(
        'dropoff_id', v_dropoff_id,
        'lot_code', v_lot_code,
        'expires_at', v_expires_at
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_hub_dropoff_v1(uuid, uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_hub_dropoff_v1(uuid, uuid, numeric) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. mark_dropoff_received_v1 — operator-callable
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_dropoff_received_v1(p_dropoff_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_dropoff record;
    v_hub record;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;

    SELECT * INTO v_dropoff FROM hub_dropoffs WHERE id = p_dropoff_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dropoff % not found', p_dropoff_id USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO v_hub FROM pickup_hubs WHERE id = v_dropoff.hub_id;
    IF v_hub.operator_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'Only the hub operator can mark dropoffs received' USING ERRCODE = '42501';
    END IF;

    IF v_dropoff.status <> 'dropped_off' THEN
        RAISE EXCEPTION 'Dropoff is not in dropped_off status (current: %)', v_dropoff.status
            USING ERRCODE = '22023';
    END IF;

    UPDATE hub_dropoffs
       SET status = 'in_inventory', received_at = now()
     WHERE id = p_dropoff_id;

    RETURN jsonb_build_object('dropoff_id', p_dropoff_id, 'status', 'in_inventory');
END;
$$;

REVOKE ALL ON FUNCTION public.mark_dropoff_received_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_dropoff_received_v1(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. dispatch_dropoff_v1 — operator OR rider can call
-- Marks a dropoff as dispatched once it's been handed to a rider trip.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_dropoff_v1(
    p_dropoff_id uuid,
    p_rider_trip_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_dropoff record;
    v_hub record;
    v_trip record;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;

    SELECT * INTO v_dropoff FROM hub_dropoffs WHERE id = p_dropoff_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dropoff % not found', p_dropoff_id USING ERRCODE = 'P0002';
    END IF;

    SELECT id, rider_id, status INTO v_trip FROM rider_trips WHERE id = p_rider_trip_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rider trip % not found', p_rider_trip_id USING ERRCODE = 'P0002';
    END IF;

    SELECT operator_id INTO v_hub FROM pickup_hubs WHERE id = v_dropoff.hub_id;

    -- Authorized: hub operator, or the rider on the trip.
    IF v_user_id <> v_hub.operator_id AND v_user_id <> v_trip.rider_id THEN
        RAISE EXCEPTION 'Not authorized to dispatch this dropoff' USING ERRCODE = '42501';
    END IF;

    IF v_dropoff.status NOT IN ('in_inventory','dropped_off') THEN
        RAISE EXCEPTION 'Dropoff cannot be dispatched from status %', v_dropoff.status
            USING ERRCODE = '22023';
    END IF;

    UPDATE hub_dropoffs
       SET status = 'dispatched',
           dispatched_at = now(),
           rider_trip_id = p_rider_trip_id
     WHERE id = p_dropoff_id;

    RETURN jsonb_build_object('dropoff_id', p_dropoff_id, 'status', 'dispatched');
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_dropoff_v1(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispatch_dropoff_v1(uuid, uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. mark_dropoff_spoiled_v1 — operator-only
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_dropoff_spoiled_v1(
    p_dropoff_id uuid,
    p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_dropoff record;
    v_hub record;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;
    SELECT * INTO v_dropoff FROM hub_dropoffs WHERE id = p_dropoff_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dropoff % not found', p_dropoff_id USING ERRCODE = 'P0002';
    END IF;
    SELECT * INTO v_hub FROM pickup_hubs WHERE id = v_dropoff.hub_id;
    IF v_hub.operator_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'Only the hub operator can mark spoiled' USING ERRCODE = '42501';
    END IF;
    UPDATE hub_dropoffs
       SET status = 'spoiled',
           notes = COALESCE(p_notes, notes)
     WHERE id = p_dropoff_id;
    RETURN jsonb_build_object('dropoff_id', p_dropoff_id, 'status', 'spoiled');
END;
$$;

REVOKE ALL ON FUNCTION public.mark_dropoff_spoiled_v1(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_dropoff_spoiled_v1(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. expire_stale_dropoffs_v1 — scheduler-callable
-- Flips dropoffs past expires_at (in dropped_off or in_inventory) to expired.
-- Returns count of rows updated.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_stale_dropoffs_v1()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_count integer;
BEGIN
    WITH expired AS (
        UPDATE hub_dropoffs
           SET status = 'expired'
         WHERE status IN ('dropped_off','in_inventory')
           AND expires_at <= now()
        RETURNING 1
    )
    SELECT count(*)::integer INTO v_count FROM expired;
    RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_stale_dropoffs_v1() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_dropoffs_v1() TO service_role;

-- ---------------------------------------------------------------------------
-- 7. Updated place_order_v1 — hub-aware sourcing
-- For each cart item, if the listing has pickup_mode IN ('hub_dropoff','both')
-- and there is an in_inventory dropoff with sufficient quantity, prefer that
-- dropoff: link order_item.dropoff_id and use the hub location as pickup.
-- Otherwise fall back to farm location (existing behaviour).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_order_v1(
    p_delivery_address text,
    p_delivery_lat double precision,
    p_delivery_lng double precision,
    p_payment_method text,
    p_delivery_fee numeric,
    p_delivery_fee_base numeric,
    p_delivery_fee_distance numeric,
    p_delivery_fee_weight numeric,
    p_delivery_distance_km numeric,
    p_items jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_order_id uuid;
    v_total_price numeric(10,2) := 0;
    v_grand_total numeric(10,2);
    v_item jsonb;
    v_listing record;
    v_subtotal numeric(10,2);
    v_quantity numeric(10,2);
    v_farmer_index int := 0;
    v_farmer_seq jsonb := '{}'::jsonb;
    v_payouts jsonb := '{}'::jsonb;
    v_seq int;
    v_payment_data jsonb;
    v_txn_uuid text;
    v_purchase_order_id text;
    v_amount_paisa integer;
    v_txn_id text;
    v_reference_id text;
    v_dropoff record;
    v_pickup_geog geography;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;
    IF p_payment_method NOT IN ('cash', 'esewa', 'khalti', 'connectips') THEN
        RAISE EXCEPTION 'Invalid payment method: %', p_payment_method USING ERRCODE = '22023';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Cannot place an order with empty cart' USING ERRCODE = '22023';
    END IF;

    -- Pass 1: validate + price.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT id, location, price_per_kg, farmer_id INTO v_listing
          FROM produce_listings
         WHERE id = (v_item->>'listing_id')::uuid AND is_active = true;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Listing % not found or inactive', v_item->>'listing_id' USING ERRCODE = 'P0002';
        END IF;
        v_quantity := (v_item->>'quantity_kg')::numeric;
        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION 'Invalid quantity for listing %', v_item->>'listing_id' USING ERRCODE = '22023';
        END IF;
        v_total_price := v_total_price + round(v_quantity * v_listing.price_per_kg, 2);
    END LOOP;

    v_total_price := round(v_total_price, 2);
    v_grand_total := round(v_total_price + coalesce(p_delivery_fee, 0), 2);

    INSERT INTO orders (
        consumer_id, status, delivery_address, delivery_location,
        total_price, delivery_fee, delivery_fee_base, delivery_fee_distance,
        delivery_fee_weight, delivery_distance_km, payment_method, payment_status
    ) VALUES (
        v_user_id, 'pending', p_delivery_address,
        ST_SetSRID(ST_MakePoint(p_delivery_lng, p_delivery_lat), 4326)::geography,
        v_total_price, coalesce(p_delivery_fee, 0), coalesce(p_delivery_fee_base, 0),
        coalesce(p_delivery_fee_distance, 0), coalesce(p_delivery_fee_weight, 0),
        p_delivery_distance_km, p_payment_method::payment_method, 'pending'
    ) RETURNING id INTO v_order_id;

    -- Pass 2: insert items + bind hub dropoffs where applicable.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT id, location, price_per_kg, farmer_id, pickup_mode INTO v_listing
          FROM produce_listings WHERE id = (v_item->>'listing_id')::uuid;
        v_quantity := (v_item->>'quantity_kg')::numeric;
        v_subtotal := round(v_quantity * v_listing.price_per_kg, 2);

        IF v_farmer_seq ? v_listing.farmer_id::text THEN
            v_seq := (v_farmer_seq->>v_listing.farmer_id::text)::int;
        ELSE
            v_farmer_index := v_farmer_index + 1;
            v_seq := v_farmer_index;
            v_farmer_seq := jsonb_set(v_farmer_seq, ARRAY[v_listing.farmer_id::text], to_jsonb(v_seq));
        END IF;

        -- Default: farm pickup.
        v_dropoff := NULL;
        v_pickup_geog := v_listing.location;

        -- Hub sourcing: pick the oldest in_inventory dropoff for this listing
        -- with sufficient quantity. If found, override pickup location.
        IF v_listing.pickup_mode IN ('hub_dropoff','both') THEN
            SELECT d.id, d.hub_id, h.location AS hub_location
              INTO v_dropoff
              FROM hub_dropoffs d
              JOIN pickup_hubs h ON h.id = d.hub_id
             WHERE d.listing_id = v_listing.id
               AND d.status = 'in_inventory'
               AND d.quantity_kg >= v_quantity
               AND h.is_active = true
             ORDER BY d.received_at ASC NULLS LAST, d.dropped_at ASC
             LIMIT 1
             FOR UPDATE OF d SKIP LOCKED;

            IF v_dropoff.id IS NOT NULL THEN
                v_pickup_geog := v_dropoff.hub_location;
            ELSIF v_listing.pickup_mode = 'hub_dropoff' THEN
                -- Listing requires hub fulfilment but no live lot is available.
                RAISE EXCEPTION 'No hub inventory available for listing %', v_listing.id
                    USING ERRCODE = '22023';
            END IF;
        END IF;

        INSERT INTO order_items (
            order_id, listing_id, farmer_id, quantity_kg, price_per_kg,
            subtotal, pickup_location, pickup_sequence, pickup_status, dropoff_id
        ) VALUES (
            v_order_id, v_listing.id, v_listing.farmer_id,
            v_quantity, v_listing.price_per_kg, v_subtotal,
            v_pickup_geog, v_seq, 'pending_pickup', v_dropoff.id
        );

        v_payouts := jsonb_set(v_payouts, ARRAY[v_listing.farmer_id::text],
            to_jsonb(round(coalesce((v_payouts->>v_listing.farmer_id::text)::numeric, 0) + v_subtotal, 2)));
    END LOOP;

    INSERT INTO farmer_payouts (order_id, farmer_id, amount, status)
    SELECT v_order_id, key::uuid, value::numeric, 'pending' FROM jsonb_each_text(v_payouts);

    IF p_payment_method = 'esewa' THEN
        v_txn_uuid := replace(gen_random_uuid()::text, '-', '');
        INSERT INTO esewa_transactions (
            order_id, transaction_uuid, product_code, amount,
            tax_amount, service_charge, delivery_charge, total_amount, status
        ) VALUES (
            v_order_id, v_txn_uuid, 'EPAYTEST', v_total_price,
            0, 0, coalesce(p_delivery_fee, 0), v_grand_total, 'PENDING'
        );
        v_payment_data := jsonb_build_object('gateway','esewa','orderId',v_order_id,
            'transactionUuid',v_txn_uuid,'amount',v_total_price,
            'deliveryCharge',coalesce(p_delivery_fee,0),'totalAmount',v_grand_total);
    ELSIF p_payment_method = 'khalti' THEN
        v_purchase_order_id := 'KH-' || v_order_id::text;
        v_amount_paisa := (v_grand_total * 100)::integer;
        INSERT INTO khalti_transactions (
            order_id, purchase_order_id, amount_paisa, total_amount, status
        ) VALUES (v_order_id, v_purchase_order_id, v_amount_paisa, v_grand_total, 'PENDING');
        v_payment_data := jsonb_build_object('gateway','khalti','orderId',v_order_id,
            'purchaseOrderId',v_purchase_order_id,'amountPaisa',v_amount_paisa);
    ELSIF p_payment_method = 'connectips' THEN
        v_txn_id := 'CI-' || v_order_id::text;
        v_reference_id := 'REF-' || v_order_id::text;
        v_amount_paisa := (v_grand_total * 100)::integer;
        INSERT INTO connectips_transactions (
            order_id, txn_id, reference_id, amount_paisa, total_amount, status
        ) VALUES (v_order_id, v_txn_id, v_reference_id, v_amount_paisa, v_grand_total, 'PENDING');
        v_payment_data := jsonb_build_object('gateway','connectips','orderId',v_order_id,
            'txnId',v_txn_id,'referenceId',v_reference_id,'amountPaisa',v_amount_paisa);
    END IF;

    IF p_payment_method = 'cash' THEN
        PERFORM public.match_order_riders(v_order_id);
    END IF;

    RETURN jsonb_build_object(
        'order_id', v_order_id, 'total_price', v_total_price,
        'grand_total', v_grand_total, 'payment_data', v_payment_data
    );
END;
$$;

-- Re-grant (signature unchanged but CREATE OR REPLACE preserves grants;
-- this is just defensive in case grants were ever revoked).
GRANT EXECUTE ON FUNCTION public.place_order_v1(
    text, double precision, double precision, text,
    numeric, numeric, numeric, numeric, numeric, jsonb
) TO authenticated;

-- ---------------------------------------------------------------------------
-- 8. Hub status transition notifications
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_hub_dropoff_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_hub record;
    v_listing_name text;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
        SELECT name_en INTO v_hub FROM pickup_hubs WHERE id = NEW.hub_id;
        SELECT name_en INTO v_listing_name FROM produce_listings WHERE id = NEW.listing_id;

        IF NEW.status = 'in_inventory' THEN
            PERFORM create_notification(
                p_user_id  := NEW.farmer_id,
                p_category := 'hub_dropoff_received'::notification_category,
                p_title_en := 'Dropoff received',
                p_title_ne := 'ड्रपअफ प्राप्त भयो',
                p_body_en  := 'Your ' || coalesce(v_listing_name, 'produce') || ' (lot ' || NEW.lot_code
                              || ') is in hub inventory.',
                p_body_ne  := coalesce(v_listing_name, 'उत्पादन') || ' (लट ' || NEW.lot_code
                              || ') हब इन्भेन्टरीमा छ।',
                p_data := jsonb_build_object('dropoff_id', NEW.id, 'hub_id', NEW.hub_id, 'lot_code', NEW.lot_code, 'type', 'hub_dropoff_received')
            );
        ELSIF NEW.status = 'dispatched' THEN
            PERFORM create_notification(
                p_user_id  := NEW.farmer_id,
                p_category := 'hub_dropoff_dispatched'::notification_category,
                p_title_en := 'Dropoff dispatched',
                p_title_ne := 'ड्रपअफ पठाइयो',
                p_body_en  := 'Your ' || coalesce(v_listing_name, 'produce') || ' (lot ' || NEW.lot_code
                              || ') has been picked up by a rider.',
                p_body_ne  := coalesce(v_listing_name, 'उत्पादन') || ' (लट ' || NEW.lot_code
                              || ') राइडरले उठाएको छ।',
                p_data := jsonb_build_object('dropoff_id', NEW.id, 'rider_trip_id', NEW.rider_trip_id, 'lot_code', NEW.lot_code, 'type', 'hub_dropoff_dispatched')
            );
        ELSIF NEW.status = 'expired' THEN
            PERFORM create_notification(
                p_user_id  := NEW.farmer_id,
                p_category := 'hub_dropoff_expired'::notification_category,
                p_title_en := 'Dropoff expired',
                p_title_ne := 'ड्रपअफ म्याद सकियो',
                p_body_en  := 'Your dropoff (lot ' || NEW.lot_code || ') was not dispatched in time and has been marked expired.',
                p_body_ne  := 'तपाईंको ड्रपअफ (लट ' || NEW.lot_code || ') समयमा पठाइएन र म्याद सकियो भनी चिन्ह लगाइयो।',
                p_data := jsonb_build_object('dropoff_id', NEW.id, 'lot_code', NEW.lot_code, 'type', 'hub_dropoff_expired')
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_hub_dropoff_notify ON hub_dropoffs;
CREATE TRIGGER trg_hub_dropoff_notify
    AFTER UPDATE OF status ON hub_dropoffs
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_hub_dropoff_status_change();
