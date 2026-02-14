-- ==========================================================
-- Push Notifications — FCM for web and mobile
-- Device tokens, notification preferences, in-app notifications
-- ==========================================================

-- Enum: notification categories (what events can trigger notifications)
CREATE TYPE notification_category AS ENUM (
    'order_matched',
    'rider_picked_up',
    'rider_arriving',
    'order_delivered',
    'new_order_for_farmer',
    'rider_arriving_for_pickup',
    'new_order_match',
    'trip_reminder',
    'delivery_confirmed'
);

-- Enum: device platforms
CREATE TYPE device_platform AS ENUM ('web', 'android', 'ios');

-- ==========================================================
-- user_devices — FCM device token registration
-- ==========================================================
CREATE TABLE user_devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token text NOT NULL,
    platform device_platform NOT NULL,
    device_name text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, fcm_token)
);

CREATE TRIGGER user_devices_updated_at
    BEFORE UPDATE ON user_devices
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- notification_preferences — per-user category toggles
-- Absence of a row means the category is enabled (opt-out model)
-- ==========================================================
CREATE TABLE notification_preferences (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category notification_category NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, category)
);

CREATE TRIGGER notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- notifications — in-app notification center
-- ==========================================================
CREATE TABLE notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category notification_category NOT NULL,
    title_en text NOT NULL,
    title_ne text NOT NULL,
    body_en text NOT NULL,
    body_ne text NOT NULL,
    data jsonb DEFAULT '{}',
    read boolean NOT NULL DEFAULT false,
    push_sent boolean NOT NULL DEFAULT false,
    sms_fallback_sent boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- ==========================================================
-- Indexes for notification tables
-- ==========================================================
CREATE INDEX idx_user_devices_user ON user_devices (user_id) WHERE is_active = true;
CREATE INDEX idx_user_devices_token ON user_devices (fcm_token);
CREATE INDEX idx_notification_prefs_user ON notification_preferences (user_id);
CREATE INDEX idx_notifications_user_unread ON notifications (user_id, created_at DESC) WHERE read = false;
CREATE INDEX idx_notifications_user_all ON notifications (user_id, created_at DESC);

-- ==========================================================
-- Enable RLS on notification tables
-- ==========================================================
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ==========================================================
-- RLS Policies: user_devices
-- Users manage only their own device tokens.
-- ==========================================================
CREATE POLICY user_devices_select ON user_devices
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY user_devices_insert ON user_devices
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY user_devices_update ON user_devices
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY user_devices_delete ON user_devices
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- ==========================================================
-- RLS Policies: notification_preferences
-- Users manage only their own preferences.
-- ==========================================================
CREATE POLICY notification_prefs_select ON notification_preferences
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY notification_prefs_insert ON notification_preferences
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY notification_prefs_update ON notification_preferences
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY notification_prefs_delete ON notification_preferences
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- ==========================================================
-- RLS Policies: notifications
-- Users read only their own notifications.
-- Insert is service-role only (triggers create notifications).
-- ==========================================================
CREATE POLICY notifications_select ON notifications
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY notifications_update ON notifications
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid());

-- ==========================================================
-- RPC: create_notification
-- Server-side function to create a notification and return
-- device tokens for FCM push. Called by edge functions only.
-- Restricted to service_role — authenticated users cannot call this.
-- ==========================================================
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id uuid,
    p_category notification_category,
    p_title_en text,
    p_title_ne text,
    p_body_en text,
    p_body_ne text,
    p_data jsonb DEFAULT '{}'
)
RETURNS jsonb AS $$
DECLARE
    v_notification_id uuid;
    v_enabled boolean;
    v_user_lang app_language;
    v_tokens jsonb;
    v_phone text;
BEGIN
    -- Check if user has disabled this category
    SELECT enabled INTO v_enabled
    FROM notification_preferences
    WHERE user_id = p_user_id AND category = p_category;

    -- Default to enabled if no preference row exists
    IF v_enabled IS NOT NULL AND v_enabled = false THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'user_disabled');
    END IF;

    -- Get user language and phone for SMS fallback
    SELECT lang, phone INTO v_user_lang, v_phone
    FROM users
    WHERE id = p_user_id;

    IF v_user_lang IS NULL THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'user_not_found');
    END IF;

    -- Create the in-app notification
    INSERT INTO notifications (user_id, category, title_en, title_ne, body_en, body_ne, data)
    VALUES (p_user_id, p_category, p_title_en, p_title_ne, p_body_en, p_body_ne, p_data)
    RETURNING id INTO v_notification_id;

    -- Get active FCM tokens for this user
    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'token', fcm_token,
        'platform', platform
    )), '[]'::jsonb)
    INTO v_tokens
    FROM user_devices
    WHERE user_id = p_user_id AND is_active = true;

    RETURN jsonb_build_object(
        'notification_id', v_notification_id,
        'user_lang', v_user_lang,
        'phone', v_phone,
        'tokens', v_tokens,
        'has_tokens', jsonb_array_length(v_tokens) > 0,
        'title', CASE WHEN v_user_lang = 'ne' THEN p_title_ne ELSE p_title_en END,
        'body', CASE WHEN v_user_lang = 'ne' THEN p_body_ne ELSE p_body_en END,
        'data', p_data
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- RPC: mark_notification_read
-- ==========================================================
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE notifications SET read = true
    WHERE id = p_notification_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- RPC: mark_all_notifications_read
-- ==========================================================
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS void AS $$
BEGIN
    UPDATE notifications SET read = true
    WHERE user_id = auth.uid() AND read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- RPC: get_unread_notification_count
-- ==========================================================
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS integer AS $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM notifications
    WHERE user_id = auth.uid() AND read = false;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- Access control: restrict create_notification to service_role
-- Authenticated users must not call this directly.
-- ==========================================================
REVOKE EXECUTE ON FUNCTION create_notification FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION create_notification TO service_role;
