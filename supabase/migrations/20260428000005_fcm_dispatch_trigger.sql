-- Wire pg_net to the Next.js FCM dispatch endpoint. The trigger fires
-- after every notifications insert and POSTs the notification id to
-- POST /api/notifications/dispatch on the web container. The endpoint
-- (apps/web/src/app/api/notifications/dispatch/route.ts) loads the row,
-- calls sendFcmPush per active token, deactivates dead tokens, and
-- flips push_sent.
--
-- Two settings drive this; both can be set with ALTER DATABASE:
--   app.settings.web_url           — base URL of the Next.js app
--                                    (e.g. http://web:3000 inside docker,
--                                    or https://khetbata.xyz from outside).
--   app.settings.service_role_key  — used as Bearer auth on the dispatch
--                                    endpoint. Already set for the
--                                    existing notify_order_status_change
--                                    trigger.
-- If either setting is empty the trigger no-ops silently — in-app
-- notifications still land via create_notification.

CREATE OR REPLACE FUNCTION public.dispatch_notification_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_web_url text;
    v_service_key text;
    v_endpoint text;
BEGIN
    v_web_url := current_setting('app.settings.web_url', true);
    v_service_key := current_setting('app.settings.service_role_key', true);

    IF v_web_url IS NULL OR v_web_url = '' THEN
        RETURN NEW;
    END IF;
    IF v_service_key IS NULL OR v_service_key = '' THEN
        RETURN NEW;
    END IF;

    v_endpoint := rtrim(v_web_url, '/') || '/api/notifications/dispatch';

    PERFORM net.http_post(
        url := v_endpoint,
        body := jsonb_build_object('notification_id', NEW.id),
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || v_service_key
        )
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dispatch_notification_push ON notifications;
CREATE TRIGGER trg_dispatch_notification_push
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.dispatch_notification_push();
