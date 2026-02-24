-- ==========================================================
-- Order notification triggers
-- Fires on INSERT/UPDATE of orders table to send push
-- notifications via the send-notification edge function.
-- Uses pg_net extension for async HTTP calls from PL/pgSQL.
-- ==========================================================

-- Enable pg_net extension for HTTP calls from triggers
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ==========================================================
-- Trigger function: notify_order_status_change
-- Detects order status transitions and calls the
-- send-notification edge function via net.http_post.
-- ==========================================================
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS trigger AS $$
DECLARE
    v_supabase_url text;
    v_service_key text;
    v_endpoint text;
    v_payload jsonb;
    v_farmer_id uuid;
    v_order_id uuid;
BEGIN
    -- Retrieve configuration; skip silently if not set
    v_supabase_url := current_setting('app.settings.supabase_url', true);
    v_service_key  := current_setting('app.settings.service_role_key', true);

    IF v_supabase_url IS NULL OR v_supabase_url = '' THEN
        RETURN NEW;
    END IF;

    IF v_service_key IS NULL OR v_service_key = '' THEN
        RETURN NEW;
    END IF;

    v_endpoint := v_supabase_url || '/functions/v1/send-notification';
    v_order_id := NEW.id;

    -- ======================================================
    -- Case 1: New order (INSERT with status = 'pending')
    -- Notify each farmer who has items in this order.
    -- ======================================================
    IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
        FOR v_farmer_id IN
            SELECT DISTINCT oi.farmer_id
            FROM order_items oi
            WHERE oi.order_id = v_order_id
        LOOP
            v_payload := jsonb_build_object(
                'user_id',  v_farmer_id,
                'category', 'new_order_for_farmer',
                'title_en', 'New Order Received',
                'title_ne', 'नयाँ अर्डर प्राप्त भयो',
                'body_en',  'You have a new order for your produce. Check your dashboard for details.',
                'body_ne',  'तपाईंको उत्पादनको लागि नयाँ अर्डर आएको छ। विवरणको लागि ड्यासबोर्ड हेर्नुहोस्।',
                'data',     jsonb_build_object(
                    'order_id', v_order_id,
                    'type',     'new_order'
                )
            );

            PERFORM net.http_post(
                url     := v_endpoint,
                body    := v_payload,
                headers := jsonb_build_object(
                    'Content-Type',  'application/json',
                    'Authorization', 'Bearer ' || v_service_key
                )
            );
        END LOOP;

        RETURN NEW;
    END IF;

    -- ======================================================
    -- Case 2: Status changed on UPDATE
    -- ======================================================
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN

        -- matched -> notify consumer
        IF NEW.status = 'matched' THEN
            v_payload := jsonb_build_object(
                'user_id',  NEW.consumer_id,
                'category', 'order_matched',
                'title_en', 'Order Matched',
                'title_ne', 'अर्डर मिलान भयो',
                'body_en',  'Your order has been matched with a rider!',
                'body_ne',  'तपाईंको अर्डर राइडरसँग मिलान भयो!',
                'data',     jsonb_build_object(
                    'order_id', v_order_id,
                    'rider_id', NEW.rider_id,
                    'type',     'order_matched'
                )
            );

            PERFORM net.http_post(
                url     := v_endpoint,
                body    := v_payload,
                headers := jsonb_build_object(
                    'Content-Type',  'application/json',
                    'Authorization', 'Bearer ' || v_service_key
                )
            );

        -- picked_up -> notify consumer
        ELSIF NEW.status = 'picked_up' THEN
            v_payload := jsonb_build_object(
                'user_id',  NEW.consumer_id,
                'category', 'rider_picked_up',
                'title_en', 'Produce Picked Up',
                'title_ne', 'उत्पादन उठाइयो',
                'body_en',  'Your produce has been picked up and is being prepared for delivery.',
                'body_ne',  'तपाईंको उत्पादन उठाइएको छ र डेलिभरीको लागि तयार भइरहेको छ।',
                'data',     jsonb_build_object(
                    'order_id', v_order_id,
                    'rider_id', NEW.rider_id,
                    'type',     'picked_up'
                )
            );

            PERFORM net.http_post(
                url     := v_endpoint,
                body    := v_payload,
                headers := jsonb_build_object(
                    'Content-Type',  'application/json',
                    'Authorization', 'Bearer ' || v_service_key
                )
            );

        -- in_transit -> notify consumer
        ELSIF NEW.status = 'in_transit' THEN
            v_payload := jsonb_build_object(
                'user_id',  NEW.consumer_id,
                'category', 'rider_arriving',
                'title_en', 'Order On Its Way',
                'title_ne', 'अर्डर बाटोमा छ',
                'body_en',  'Your order is on its way! Track your delivery in real-time.',
                'body_ne',  'तपाईंको अर्डर बाटोमा छ! आफ्नो डेलिभरी रियल-टाइममा ट्र्याक गर्नुहोस्।',
                'data',     jsonb_build_object(
                    'order_id',     v_order_id,
                    'rider_id',     NEW.rider_id,
                    'rider_trip_id', NEW.rider_trip_id,
                    'type',         'in_transit'
                )
            );

            PERFORM net.http_post(
                url     := v_endpoint,
                body    := v_payload,
                headers := jsonb_build_object(
                    'Content-Type',  'application/json',
                    'Authorization', 'Bearer ' || v_service_key
                )
            );

        -- delivered -> notify consumer
        ELSIF NEW.status = 'delivered' THEN
            v_payload := jsonb_build_object(
                'user_id',  NEW.consumer_id,
                'category', 'order_delivered',
                'title_en', 'Order Delivered',
                'title_ne', 'अर्डर डेलिभर भयो',
                'body_en',  'Your order has been delivered. Enjoy your fresh produce!',
                'body_ne',  'तपाईंको अर्डर डेलिभर भयो। ताजा उत्पादनको आनन्द लिनुहोस्!',
                'data',     jsonb_build_object(
                    'order_id', v_order_id,
                    'type',     'delivered'
                )
            );

            PERFORM net.http_post(
                url     := v_endpoint,
                body    := v_payload,
                headers := jsonb_build_object(
                    'Content-Type',  'application/json',
                    'Authorization', 'Bearer ' || v_service_key
                )
            );

        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- Attach trigger to orders table
-- Fires AFTER INSERT or UPDATE so that order_items are
-- already present when we query them (for new orders).
-- ==========================================================
CREATE TRIGGER trg_order_status_notification
    AFTER INSERT OR UPDATE OF status ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_status_change();
