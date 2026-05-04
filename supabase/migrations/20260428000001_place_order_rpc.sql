-- place_order RPC: atomic order creation for clients that don't have
-- service-role access (mobile, future direct-from-browser flows).
--
-- The web app uses a service-role Supabase client and bypasses RLS to
-- insert into orders, order_items, farmer_payouts, and the per-gateway
-- transaction tables. Mobile uses the user's anon-key session, where the
-- existing RLS rejects writes to farmer_payouts (and the digital-payment
-- transaction tables) — see migration 20260214000014, which intentionally
-- left those without an INSERT policy.
--
-- This RPC moves the multi-table insert into a single SECURITY DEFINER
-- function so it can run regardless of RLS, while still enforcing that:
--   * the caller is authenticated (auth.uid() != null)
--   * the order is created on behalf of the caller (consumer_id = auth.uid())
--   * line-item prices come from produce_listings, not the client
--   * inactive listings are rejected
--
-- Returns: { order_id, total_price, grand_total, payment_data? }
-- payment_data is non-null for digital payments (esewa / khalti / connectips)
-- and contains the gateway-specific identifiers needed to redirect the user.

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
    v_payout record;
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
        RAISE EXCEPTION 'Invalid payment method: %', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Cannot place an order with empty cart'
            USING ERRCODE = '22023';
    END IF;

    -- Pass 1: validate listings + compute server-truth subtotal.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT id, location, price_per_kg, farmer_id
          INTO v_listing
          FROM produce_listings
         WHERE id = (v_item->>'listing_id')::uuid
           AND is_active = true;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Listing % not found or inactive',
                v_item->>'listing_id'
                USING ERRCODE = 'P0002';
        END IF;

        v_quantity := (v_item->>'quantity_kg')::numeric;
        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION 'Invalid quantity for listing %',
                v_item->>'listing_id'
                USING ERRCODE = '22023';
        END IF;

        v_total_price := v_total_price + round(v_quantity * v_listing.price_per_kg, 2);
    END LOOP;

    v_total_price := round(v_total_price, 2);
    v_grand_total := round(v_total_price + coalesce(p_delivery_fee, 0), 2);

    -- Insert the order row owned by the caller.
    INSERT INTO orders (
        consumer_id, status, delivery_address, delivery_location,
        total_price, delivery_fee, delivery_fee_base, delivery_fee_distance,
        delivery_fee_weight, delivery_distance_km,
        payment_method, payment_status
    ) VALUES (
        v_user_id, 'pending', p_delivery_address,
        ST_SetSRID(ST_MakePoint(p_delivery_lng, p_delivery_lat), 4326)::geography,
        v_total_price,
        coalesce(p_delivery_fee, 0),
        coalesce(p_delivery_fee_base, 0),
        coalesce(p_delivery_fee_distance, 0),
        coalesce(p_delivery_fee_weight, 0),
        p_delivery_distance_km,
        p_payment_method::payment_method, 'pending'
    ) RETURNING id INTO v_order_id;

    -- Pass 2: insert line items + accumulate per-farmer payouts and pickup sequence.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT id, location, price_per_kg, farmer_id
          INTO v_listing
          FROM produce_listings
         WHERE id = (v_item->>'listing_id')::uuid;

        v_quantity := (v_item->>'quantity_kg')::numeric;
        v_subtotal := round(v_quantity * v_listing.price_per_kg, 2);

        IF v_farmer_seq ? v_listing.farmer_id::text THEN
            v_seq := (v_farmer_seq->>v_listing.farmer_id::text)::int;
        ELSE
            v_farmer_index := v_farmer_index + 1;
            v_seq := v_farmer_index;
            v_farmer_seq := jsonb_set(
                v_farmer_seq,
                ARRAY[v_listing.farmer_id::text],
                to_jsonb(v_seq)
            );
        END IF;

        INSERT INTO order_items (
            order_id, listing_id, farmer_id, quantity_kg, price_per_kg,
            subtotal, pickup_location, pickup_sequence, pickup_status
        ) VALUES (
            v_order_id, v_listing.id, v_listing.farmer_id,
            v_quantity, v_listing.price_per_kg, v_subtotal,
            v_listing.location, v_seq, 'pending_pickup'
        );

        v_payouts := jsonb_set(
            v_payouts,
            ARRAY[v_listing.farmer_id::text],
            to_jsonb(round(
                coalesce((v_payouts->>v_listing.farmer_id::text)::numeric, 0)
                + v_subtotal, 2))
        );
    END LOOP;

    -- Insert farmer_payouts (one row per unique farmer).
    INSERT INTO farmer_payouts (order_id, farmer_id, amount, status)
    SELECT v_order_id, key::uuid, value::numeric, 'pending'
      FROM jsonb_each_text(v_payouts);

    -- Digital payment: insert gateway transaction row + return redirect data.
    IF p_payment_method = 'esewa' THEN
        v_txn_uuid := replace(gen_random_uuid()::text, '-', '');
        INSERT INTO esewa_transactions (
            order_id, transaction_uuid, product_code, amount,
            tax_amount, service_charge, delivery_charge, total_amount, status
        ) VALUES (
            v_order_id, v_txn_uuid, 'EPAYTEST', v_total_price,
            0, 0, coalesce(p_delivery_fee, 0), v_grand_total, 'PENDING'
        );
        v_payment_data := jsonb_build_object(
            'gateway', 'esewa',
            'orderId', v_order_id,
            'transactionUuid', v_txn_uuid,
            'amount', v_total_price,
            'deliveryCharge', coalesce(p_delivery_fee, 0),
            'totalAmount', v_grand_total
        );
    ELSIF p_payment_method = 'khalti' THEN
        v_purchase_order_id := 'KH-' || v_order_id::text;
        v_amount_paisa := (v_grand_total * 100)::integer;
        INSERT INTO khalti_transactions (
            order_id, purchase_order_id, amount_paisa, total_amount, status
        ) VALUES (
            v_order_id, v_purchase_order_id, v_amount_paisa, v_grand_total, 'PENDING'
        );
        v_payment_data := jsonb_build_object(
            'gateway', 'khalti',
            'orderId', v_order_id,
            'purchaseOrderId', v_purchase_order_id,
            'amountPaisa', v_amount_paisa
        );
    ELSIF p_payment_method = 'connectips' THEN
        v_txn_id := 'CI-' || v_order_id::text;
        v_reference_id := 'REF-' || v_order_id::text;
        v_amount_paisa := (v_grand_total * 100)::integer;
        INSERT INTO connectips_transactions (
            order_id, txn_id, reference_id, amount_paisa, total_amount, status
        ) VALUES (
            v_order_id, v_txn_id, v_reference_id, v_amount_paisa, v_grand_total, 'PENDING'
        );
        v_payment_data := jsonb_build_object(
            'gateway', 'connectips',
            'orderId', v_order_id,
            'txnId', v_txn_id,
            'referenceId', v_reference_id,
            'amountPaisa', v_amount_paisa
        );
    END IF;

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'total_price', v_total_price,
        'grand_total', v_grand_total,
        'payment_data', v_payment_data
    );
END;
$$;

-- Lock down EXECUTE so anonymous (unauthenticated) callers can't hit it.
REVOKE ALL ON FUNCTION public.place_order_v1(
    text, double precision, double precision, text,
    numeric, numeric, numeric, numeric, numeric, jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.place_order_v1(
    text, double precision, double precision, text,
    numeric, numeric, numeric, numeric, numeric, jsonb
) TO authenticated;
