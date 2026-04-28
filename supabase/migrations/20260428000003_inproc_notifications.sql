-- Replace the HTTP-based notify trigger with one that writes directly to
-- the notifications table via create_notification(). The original trigger
-- in 20260221100004 calls a Deno edge function via pg_net.http_post, but
-- the edge function isn't deployed in this environment, so the trigger
-- silently 404s and no notification rows ever land.
--
-- Going direct keeps the in-app notification flow working (mobile + web
-- subscribe to notifications inserts via Supabase realtime). FCM push to
-- backgrounded devices is a separate concern; it can be added later by
-- restoring an HTTP call alongside the inline insert, or by deploying the
-- edge function.
--
-- Also adds a per-rider notification insert inside match_order_riders so
-- mobile-placed cash orders ping AND notify riders the same way the web's
-- findAndPingRiders did.

-- Farmer notification helper, callable inline from place_order_v1 (so it
-- runs after the order_items loop has populated the cart). The trigger's
-- INSERT branch is dropped because AFTER INSERT on orders fires before
-- order_items rows exist within the same transaction.
CREATE OR REPLACE FUNCTION public.notify_farmers_new_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_farmer record;
BEGIN
    FOR v_farmer IN
        SELECT
            oi.farmer_id,
            sum(oi.quantity_kg) AS total_qty,
            min(pl.name_en) AS first_produce
        FROM order_items oi
        LEFT JOIN produce_listings pl ON pl.id = oi.listing_id
        WHERE oi.order_id = p_order_id
        GROUP BY oi.farmer_id
    LOOP
        PERFORM create_notification(
            p_user_id  := v_farmer.farmer_id,
            p_category := 'new_order_for_farmer'::notification_category,
            p_title_en := 'New Order!',
            p_title_ne := 'नयाँ अर्डर!',
            p_body_en  := 'New order for ' || coalesce(v_farmer.total_qty::text, '?') || 'kg of '
                          || coalesce(v_farmer.first_produce, 'produce') || '.',
            p_body_ne  := coalesce(v_farmer.first_produce, 'उत्पादन') || ' को '
                          || coalesce(v_farmer.total_qty::text, '?') || ' केजी को नयाँ अर्डर।',
            p_data := jsonb_build_object('order_id', p_order_id, 'type', 'new_order')
        );
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_farmers_new_order(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_farmers_new_order(uuid) TO service_role;


CREATE OR REPLACE FUNCTION public.notify_order_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order_id uuid;
BEGIN
    v_order_id := NEW.id;

    -- INSERT branch intentionally absent: AFTER INSERT on orders fires
    -- before order_items rows are visible, so farmer notifications happen
    -- inline from place_order_v1 via notify_farmers_new_order.

    -- UPDATE OF status: notify the consumer on each transition.
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status = 'matched' THEN
            PERFORM create_notification(
                p_user_id := NEW.consumer_id,
                p_category := 'order_matched'::notification_category,
                p_title_en := 'Order Matched',
                p_title_ne := 'अर्डर मिलान भयो',
                p_body_en := 'Your order has been matched with a rider!',
                p_body_ne := 'तपाईंको अर्डर राइडरसँग मिलान भयो!',
                p_data := jsonb_build_object('order_id', v_order_id, 'rider_id', NEW.rider_id, 'type', 'order_matched')
            );
        ELSIF NEW.status = 'picked_up' THEN
            PERFORM create_notification(
                p_user_id := NEW.consumer_id,
                p_category := 'rider_picked_up'::notification_category,
                p_title_en := 'Produce Picked Up',
                p_title_ne := 'उत्पादन उठाइयो',
                p_body_en := 'Your produce has been picked up and is being prepared for delivery.',
                p_body_ne := 'तपाईंको उत्पादन उठाइएको छ र डेलिभरीको लागि तयार भइरहेको छ।',
                p_data := jsonb_build_object('order_id', v_order_id, 'rider_id', NEW.rider_id, 'type', 'picked_up')
            );
        ELSIF NEW.status = 'in_transit' THEN
            PERFORM create_notification(
                p_user_id := NEW.consumer_id,
                p_category := 'rider_arriving'::notification_category,
                p_title_en := 'Order On Its Way',
                p_title_ne := 'अर्डर बाटोमा छ',
                p_body_en := 'Your order is on its way! Track your delivery in real-time.',
                p_body_ne := 'तपाईंको अर्डर बाटोमा छ! आफ्नो डेलिभरी रियल-टाइममा ट्र्याक गर्नुहोस्।',
                p_data := jsonb_build_object('order_id', v_order_id, 'rider_id', NEW.rider_id, 'rider_trip_id', NEW.rider_trip_id, 'type', 'in_transit')
            );
        ELSIF NEW.status = 'delivered' THEN
            PERFORM create_notification(
                p_user_id := NEW.consumer_id,
                p_category := 'order_delivered'::notification_category,
                p_title_en := 'Order Delivered',
                p_title_ne := 'अर्डर डेलिभर भयो',
                p_body_en := 'Your order has been delivered. Enjoy your fresh produce!',
                p_body_ne := 'तपाईंको अर्डर डेलिभर भयो। ताजा उत्पादनको आनन्द लिनुहोस्!',
                p_data := jsonb_build_object('order_id', v_order_id, 'type', 'delivered')
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger from 20260221100004 already attached; we're only swapping the function body.

-- Also notify each rider when their ping is inserted (web's findAndPingRiders
-- did this with notifyRiderPingArrived). Done as a trigger on order_pings so
-- it covers both mobile and any future ping inserter.
CREATE OR REPLACE FUNCTION public.notify_rider_ping()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_earnings text;
BEGIN
    v_earnings := round(coalesce(NEW.estimated_earnings, 0))::text;
    PERFORM create_notification(
        p_user_id := NEW.rider_id,
        p_category := 'new_order_match'::notification_category,
        p_title_en := 'New delivery opportunity',
        p_title_ne := 'नयाँ डेलिभरी अवसर',
        p_body_en := 'Rs ' || v_earnings || ' earnings — tap to accept within 5 min.',
        p_body_ne := 'रु ' || v_earnings || ' कमाइ — ५ मिनेट भित्र स्वीकार्न ट्याप गर्नुहोस्।',
        p_data := jsonb_build_object(
            'order_id', NEW.order_id,
            'trip_id',  NEW.trip_id,
            'ping_id',  NEW.id,
            'estimated_earnings', NEW.estimated_earnings,
            'type', 'new_ping'
        )
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_rider_ping ON order_pings;
CREATE TRIGGER trg_notify_rider_ping
    AFTER INSERT ON order_pings
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_rider_ping();


-- Wire the farmer-notification call into place_order_v1, after the
-- order_items loop. Re-declared verbatim from 20260428000002 except for
-- the new tail.
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

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT id, location, price_per_kg, farmer_id INTO v_listing
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

        INSERT INTO order_items (
            order_id, listing_id, farmer_id, quantity_kg, price_per_kg,
            subtotal, pickup_location, pickup_sequence, pickup_status
        ) VALUES (
            v_order_id, v_listing.id, v_listing.farmer_id,
            v_quantity, v_listing.price_per_kg, v_subtotal,
            v_listing.location, v_seq, 'pending_pickup'
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

    -- Notify farmers about the new order (always, regardless of payment method).
    PERFORM public.notify_farmers_new_order(v_order_id);

    -- Cash orders: ping riders now. Digital orders wait for payment escrow,
    -- handled by trg_order_match_riders_on_payment.
    IF p_payment_method = 'cash' THEN
        PERFORM public.match_order_riders(v_order_id);
    END IF;

    RETURN jsonb_build_object(
        'order_id', v_order_id, 'total_price', v_total_price,
        'grand_total', v_grand_total, 'payment_data', v_payment_data
    );
END;
$$;
