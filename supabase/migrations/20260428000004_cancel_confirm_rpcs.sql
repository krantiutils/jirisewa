-- Atomic SECURITY DEFINER RPCs for order cancellation and delivery
-- confirmation. Mirrors the side effects of the web server actions
-- cancelOrder() and confirmDelivery() so the mobile app (anon-key
-- session) can perform the same multi-table updates without hitting
-- RLS on payment-transaction tables.

-- ---------------------------------------------------------------------------
-- cancel_order_v1(p_order_id)
--
-- Caller must own the order (consumer_id = auth.uid()) and the order must
-- be in 'pending' or 'matched'. Cancels:
--   * orders.status -> 'cancelled' (+ payment_status -> 'refunded' for
--     digital orders that were already escrowed)
--   * matching {gateway}_transactions -> REFUNDED with refunded_at = now()
--   * farmer_payouts (pending) -> 'refunded'
--   * order_pings (pending) -> 'expired'
--
-- Returns: { ok: true } on success.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_order_v1(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_order record;
    v_now timestamptz := now();
    v_new_payment_status payment_status;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;

    SELECT id, status, consumer_id, payment_method, payment_status
      INTO v_order FROM orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_order.consumer_id <> v_user_id THEN
        RAISE EXCEPTION 'You can only cancel your own orders' USING ERRCODE = '42501';
    END IF;
    IF v_order.status NOT IN ('pending'::order_status, 'matched'::order_status) THEN
        RAISE EXCEPTION 'Only pending or matched orders can be cancelled' USING ERRCODE = '22023';
    END IF;

    v_new_payment_status := v_order.payment_status;

    IF v_order.payment_method <> 'cash'::payment_method
       AND v_order.payment_status = 'escrowed'::payment_status THEN
        v_new_payment_status := 'refunded'::payment_status;
        IF v_order.payment_method = 'esewa'::payment_method THEN
            UPDATE esewa_transactions
               SET status = 'REFUNDED', refunded_at = v_now
             WHERE order_id = p_order_id AND status = 'COMPLETE';
        ELSIF v_order.payment_method = 'khalti'::payment_method THEN
            UPDATE khalti_transactions
               SET status = 'REFUNDED', refunded = true, refunded_at = v_now
             WHERE order_id = p_order_id AND status = 'COMPLETE';
        ELSIF v_order.payment_method = 'connectips'::payment_method THEN
            UPDATE connectips_transactions
               SET status = 'REFUNDED', refunded_at = v_now
             WHERE order_id = p_order_id AND status = 'COMPLETE';
        END IF;
    END IF;

    UPDATE orders
       SET status = 'cancelled'::order_status,
           payment_status = v_new_payment_status
     WHERE id = p_order_id;

    UPDATE farmer_payouts
       SET status = 'refunded'
     WHERE order_id = p_order_id AND status = 'pending';

    UPDATE order_pings
       SET status = 'expired'::ping_status
     WHERE order_id = p_order_id AND status = 'pending'::ping_status;

    RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_order_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_order_v1(uuid) TO authenticated;


-- ---------------------------------------------------------------------------
-- confirm_delivery_v1(p_order_id)
--
-- Caller must be the consumer; order must be 'in_transit'. Settles:
--   * orders.status -> 'delivered'
--   * payment_status -> 'settled' (digital escrowed) or 'collected' (cash)
--   * matching {gateway}_transactions -> SETTLED + escrow_released_at
--   * order_items.delivery_confirmed = true (skip 'unavailable' rows)
--   * farmer_payouts (pending) -> 'settled' with settled_at = now()
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_delivery_v1(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_order record;
    v_now timestamptz := now();
    v_new_payment_status payment_status;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;

    SELECT id, status, consumer_id, rider_id, payment_method, payment_status
      INTO v_order FROM orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_order.consumer_id <> v_user_id THEN
        RAISE EXCEPTION 'You can only confirm your own orders' USING ERRCODE = '42501';
    END IF;
    IF v_order.status <> 'in_transit'::order_status THEN
        RAISE EXCEPTION 'Only in-transit orders can be confirmed as delivered' USING ERRCODE = '22023';
    END IF;

    IF v_order.payment_method <> 'cash'::payment_method
       AND v_order.payment_status = 'escrowed'::payment_status THEN
        v_new_payment_status := 'settled'::payment_status;
        IF v_order.payment_method = 'esewa'::payment_method THEN
            UPDATE esewa_transactions
               SET status = 'SETTLED', escrow_released_at = v_now
             WHERE order_id = p_order_id AND status = 'COMPLETE';
        ELSIF v_order.payment_method = 'khalti'::payment_method THEN
            UPDATE khalti_transactions
               SET status = 'SETTLED', escrow_released_at = v_now
             WHERE order_id = p_order_id AND status = 'COMPLETE';
        ELSIF v_order.payment_method = 'connectips'::payment_method THEN
            UPDATE connectips_transactions
               SET status = 'SETTLED', escrow_released_at = v_now
             WHERE order_id = p_order_id AND status = 'COMPLETE';
        END IF;
    ELSE
        v_new_payment_status := 'collected'::payment_status;
    END IF;

    UPDATE orders
       SET status = 'delivered'::order_status,
           payment_status = v_new_payment_status
     WHERE id = p_order_id;

    UPDATE order_items
       SET delivery_confirmed = true
     WHERE order_id = p_order_id
       AND pickup_status <> 'unavailable'::order_item_status;

    UPDATE farmer_payouts
       SET status = 'settled', settled_at = v_now
     WHERE order_id = p_order_id AND status = 'pending';

    RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_delivery_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_delivery_v1(uuid) TO authenticated;


-- Extend status-change trigger: also notify the rider when consumer
-- confirms delivery. (Web's confirmDelivery did this via
-- notifyRiderDeliveryConfirmed.) Re-declared in full to keep one source
-- of truth for the trigger body alongside 20260428000003.
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
            -- Notify consumer
            PERFORM create_notification(
                p_user_id := NEW.consumer_id,
                p_category := 'order_delivered'::notification_category,
                p_title_en := 'Order Delivered',
                p_title_ne := 'अर्डर डेलिभर भयो',
                p_body_en := 'Your order has been delivered. Enjoy your fresh produce!',
                p_body_ne := 'तपाईंको अर्डर डेलिभर भयो। ताजा उत्पादनको आनन्द लिनुहोस्!',
                p_data := jsonb_build_object('order_id', v_order_id, 'type', 'delivered')
            );
            -- Notify rider that delivery was confirmed (parity with web's
            -- notifyRiderDeliveryConfirmed)
            IF NEW.rider_id IS NOT NULL THEN
                PERFORM create_notification(
                    p_user_id := NEW.rider_id,
                    p_category := 'delivery_confirmed'::notification_category,
                    p_title_en := 'Delivery Confirmed',
                    p_title_ne := 'डेलिभरी पुष्टि भयो',
                    p_body_en := 'The customer confirmed delivery — earnings settled.',
                    p_body_ne := 'ग्राहकले डेलिभरी पुष्टि गर्नुभयो — कमाइ टुङ्गिएको छ।',
                    p_data := jsonb_build_object('order_id', v_order_id, 'type', 'delivery_confirmed')
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;
