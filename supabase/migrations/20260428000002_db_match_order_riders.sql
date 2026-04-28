-- ---------------------------------------------------------------------------
-- Fix latent bug in find_eligible_riders: the detour_distance_m column was
-- declared `numeric` in RETURNS TABLE but the SELECT produced `double precision`
-- (ST_Distance's return type), which raises "structure of query does not
-- match function result type" the moment a row would actually qualify.
-- The web path silently failed on prod for the same reason. Re-create with
-- explicit casts to numeric.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION find_eligible_riders(
    p_order_id uuid,
    p_max_detour_m numeric DEFAULT 5000,
    p_max_results integer DEFAULT 10
)
RETURNS TABLE (
    trip_id uuid,
    rider_id uuid,
    remaining_capacity_kg numeric,
    detour_distance_m numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_delivery_location geography;
    v_total_weight_kg numeric;
    v_pickup_locations geography[];
    v_pickup_count integer;
BEGIN
    SELECT o.delivery_location::geography INTO v_delivery_location
    FROM orders o WHERE o.id = p_order_id;

    IF v_delivery_location IS NULL THEN
        RAISE EXCEPTION 'Order % not found or has no delivery location', p_order_id;
    END IF;

    SELECT
        COALESCE(SUM(oi.quantity_kg), 0),
        ARRAY_AGG(oi.pickup_location::geography) FILTER (WHERE oi.pickup_location IS NOT NULL)
    INTO v_total_weight_kg, v_pickup_locations
    FROM order_items oi WHERE oi.order_id = p_order_id;

    v_pickup_count := COALESCE(array_length(v_pickup_locations, 1), 0);
    IF v_pickup_count = 0 THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH eligible_trips AS (
        SELECT
            rt.id AS e_trip_id,
            rt.rider_id AS e_rider_id,
            rt.remaining_capacity_kg AS e_remaining_capacity_kg,
            rt.route
        FROM rider_trips rt
        WHERE rt.status IN ('scheduled', 'in_transit')  -- match both — pre-trip riders accept pings too
          AND rt.remaining_capacity_kg >= v_total_weight_kg
          AND rt.route IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM order_pings op
              WHERE op.order_id = p_order_id AND op.rider_id = rt.rider_id
          )
    ),
    trips_with_progress AS (
        SELECT et.*,
            COALESCE(
                (SELECT ST_LineLocatePoint(et.route::geometry, ll.location::geometry)
                   FROM rider_location_log ll
                   WHERE ll.trip_id = et.e_trip_id AND ll.rider_id = et.e_rider_id
                   ORDER BY ll.recorded_at DESC LIMIT 1),
                0.0
            ) AS route_progress
        FROM eligible_trips et
    ),
    trips_with_remaining AS (
        SELECT tp.*,
            CASE
                WHEN tp.route_progress >= 0.99 THEN NULL
                ELSE ST_LineSubstring(tp.route::geometry, tp.route_progress, 1.0)::geography
            END AS remaining_route
        FROM trips_with_progress tp
    ),
    spatial_check AS (
        SELECT tr.e_trip_id, tr.e_rider_id, tr.e_remaining_capacity_kg, tr.remaining_route,
            ST_DWithin(tr.remaining_route, v_delivery_location, p_max_detour_m) AS delivery_near,
            (SELECT COUNT(*) FROM unnest(v_pickup_locations) AS pl(geog)
              WHERE ST_DWithin(tr.remaining_route, pl.geog, p_max_detour_m)) AS pickups_near_count
        FROM trips_with_remaining tr
        WHERE tr.remaining_route IS NOT NULL
    )
    SELECT
        sc.e_trip_id,
        sc.e_rider_id,
        sc.e_remaining_capacity_kg,
        ((
            SELECT COALESCE(SUM(ST_Distance(sc.remaining_route, pl.geog)), 0)
            FROM unnest(v_pickup_locations) AS pl(geog)
         ) + ST_Distance(sc.remaining_route, v_delivery_location))::numeric AS detour_est
    FROM spatial_check sc
    WHERE sc.delivery_near = true
      AND sc.pickups_near_count = v_pickup_count
    ORDER BY detour_est ASC
    LIMIT p_max_results;
END;
$$;

-- DB-side rider matching:
-- Closes the gap where mobile-placed orders (going through place_order_v1)
-- never pinged riders, because findAndPingRiders only ran inside the Next.js
-- server action `placeOrder`. After this migration, ANY order insert (mobile,
-- web, or future channels) fans out pings via the same PostGIS path the web
-- code used to invoke from JS.
--
-- Cash orders ping on INSERT.
-- Digital orders (esewa/khalti/connectips) ping when payment_status flips
-- to 'escrowed' — same gating as the web code, so we don't ping riders for
-- orders that may never be paid.

-- ---------------------------------------------------------------------------
-- match_order_riders: builds ping rows for an order using the existing
-- find_eligible_riders RPC. Mirrors the JSON snapshots that
-- apps/web/src/lib/actions/pings.ts builds, so the rider client (which
-- already reads pickup_locations / delivery_location off the row) sees the
-- same shape regardless of which path created the ping.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.match_order_riders(p_order_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_max_detour_m   numeric := 5000;   -- mirrors @jirisewa/shared MAX_DETOUR_M
    v_max_results    integer := 5;       -- mirrors MAX_PINGS_PER_ORDER
    v_ping_ttl       interval := interval '5 minutes';  -- PING_EXPIRY_MS

    v_order          record;
    v_total_weight   numeric;
    v_pickups        jsonb;
    v_delivery       jsonb;
    v_inserted       integer := 0;
BEGIN
    -- Load the order's delivery location + delivery fee (rider's earnings).
    SELECT
        o.delivery_address,
        o.delivery_fee,
        ST_Y(o.delivery_location::geometry) AS lat,
        ST_X(o.delivery_location::geometry) AS lng
    INTO v_order
    FROM orders o
    WHERE o.id = p_order_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'match_order_riders: order % not found', p_order_id;
        RETURN 0;
    END IF;

    v_delivery := jsonb_build_object(
        'lat',     coalesce(v_order.lat, 0),
        'lng',     coalesce(v_order.lng, 0),
        'address', v_order.delivery_address
    );

    -- Aggregate pickup locations per farmer and total weight from order_items.
    SELECT
        coalesce(sum(oi.quantity_kg), 0),
        coalesce(jsonb_agg(
            jsonb_build_object(
                'lat',        ST_Y(oi.pickup_location::geometry),
                'lng',        ST_X(oi.pickup_location::geometry),
                'farmerName', coalesce(u.name, 'Unknown')
            )
        ) FILTER (WHERE oi.pickup_location IS NOT NULL), '[]'::jsonb)
    INTO v_total_weight, v_pickups
    FROM order_items oi
    LEFT JOIN users u ON u.id = oi.farmer_id
    WHERE oi.order_id = p_order_id;

    -- Insert one ping per eligible rider/trip pair.
    WITH inserted AS (
        INSERT INTO order_pings (
            order_id, rider_id, trip_id,
            pickup_locations, delivery_location,
            total_weight_kg, estimated_earnings,
            detour_distance_m, status, expires_at
        )
        SELECT
            p_order_id,
            er.rider_id,
            er.trip_id,
            v_pickups,
            v_delivery,
            v_total_weight,
            coalesce(v_order.delivery_fee, 0),
            er.detour_distance_m,
            'pending'::ping_status,
            now() + v_ping_ttl
        FROM find_eligible_riders(
            p_order_id   := p_order_id,
            p_max_detour_m := v_max_detour_m,
            p_max_results := v_max_results
        ) er
        RETURNING 1
    )
    SELECT count(*)::integer INTO v_inserted FROM inserted;

    RETURN v_inserted;
EXCEPTION WHEN OTHERS THEN
    -- Non-fatal: order exists regardless. Log and move on.
    RAISE WARNING 'match_order_riders failed for order %: %', p_order_id, SQLERRM;
    RETURN 0;
END;
$$;

REVOKE ALL ON FUNCTION public.match_order_riders(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.match_order_riders(uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- Trigger function: gate matching on payment readiness.
--   * Cash: ping immediately at INSERT.
--   * Digital: wait until payment_status flips to 'escrowed'.
--
-- Runs AFTER the row is in place so order_items are visible.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_order_match_riders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.payment_method = 'cash'::payment_method THEN
            PERFORM public.match_order_riders(NEW.id);
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.payment_method <> 'cash'::payment_method
           AND NEW.payment_status = 'escrowed'::payment_status
           AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
            PERFORM public.match_order_riders(NEW.id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Note: we don't install an AFTER INSERT trigger on `orders`. place_order_v1
-- inserts the order row *before* the order_items loop, so an AFTER INSERT
-- trigger would observe an empty cart and skip matching. Instead,
-- place_order_v1 (below) invokes match_order_riders inline once items are in.
-- The UPDATE trigger still covers the digital-payment escrow transition.

DROP TRIGGER IF EXISTS trg_order_match_riders_on_insert ON orders;

DROP TRIGGER IF EXISTS trg_order_match_riders_on_payment ON orders;
CREATE TRIGGER trg_order_match_riders_on_payment
    AFTER UPDATE OF payment_status ON orders
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_order_match_riders();

-- ---------------------------------------------------------------------------
-- Update place_order_v1 to call match_order_riders for cash orders, after
-- all order_items have been inserted. Digital orders still wait on the
-- payment_status update trigger above. Re-declared verbatim from
-- 20260428000001_place_order_rpc.sql except for the new tail.
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
