"use server";

import { NotificationCategory } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

// TODO: Replace hardcoded user IDs with authenticated user once auth is wired
const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";

interface NotificationRow {
  id: string;
  category: string;
  title_en: string;
  title_ne: string;
  body_en: string;
  body_ne: string;
  data: Record<string, unknown>;
  read: boolean;
  created_at: string;
}

interface NotificationPreference {
  category: string;
  enabled: boolean;
}

// ---- Device Token Management ----

export async function registerDeviceToken(
  fcmToken: string,
  platform: "web" | "android" | "ios",
  deviceName?: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { error } = await supabase
      .from("user_devices")
      .upsert(
        {
          user_id: DEMO_CONSUMER_ID,
          fcm_token: fcmToken,
          platform,
          device_name: deviceName ?? null,
          is_active: true,
        },
        { onConflict: "user_id,fcm_token" },
      );

    if (error) {
      console.error("registerDeviceToken error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("registerDeviceToken unexpected error:", err);
    return { error: "Failed to register device" };
  }
}

export async function unregisterDeviceToken(
  fcmToken: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { error } = await supabase
      .from("user_devices")
      .update({ is_active: false })
      .eq("user_id", DEMO_CONSUMER_ID)
      .eq("fcm_token", fcmToken);

    if (error) {
      console.error("unregisterDeviceToken error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("unregisterDeviceToken unexpected error:", err);
    return { error: "Failed to unregister device" };
  }
}

// ---- Notification CRUD ----

export async function listNotifications(
  limit = 20,
  offset = 0,
): Promise<ActionResult<NotificationRow[]>> {
  try {
    // Clamp inputs to prevent abuse
    const safeLimit = Math.max(1, Math.min(limit, 100));
    const safeOffset = Math.max(0, offset);

    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("notifications")
      .select("id, category, title_en, title_ne, body_en, body_ne, data, read, created_at")
      .eq("user_id", DEMO_CONSUMER_ID)
      .order("created_at", { ascending: false })
      .range(safeOffset, safeOffset + safeLimit - 1);

    if (error) {
      console.error("listNotifications error:", error);
      return { error: error.message };
    }

    return { data: data ?? [] };
  } catch (err) {
    console.error("listNotifications unexpected error:", err);
    return { error: "Failed to list notifications" };
  }
}

export async function getUnreadCount(): Promise<ActionResult<number>> {
  try {
    const supabase = createServiceRoleClient();

    const { count, error } = await supabase
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", DEMO_CONSUMER_ID)
      .eq("read", false);

    if (error) {
      console.error("getUnreadCount error:", error);
      return { error: error.message };
    }

    return { data: count ?? 0 };
  } catch (err) {
    console.error("getUnreadCount unexpected error:", err);
    return { error: "Failed to get unread count" };
  }
}

export async function markNotificationRead(
  notificationId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { error } = await supabase
      .from("notifications")
      .update({ read: true })
      .eq("id", notificationId)
      .eq("user_id", DEMO_CONSUMER_ID);

    if (error) {
      console.error("markNotificationRead error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("markNotificationRead unexpected error:", err);
    return { error: "Failed to mark notification as read" };
  }
}

export async function markAllNotificationsRead(): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { error } = await supabase
      .from("notifications")
      .update({ read: true })
      .eq("user_id", DEMO_CONSUMER_ID)
      .eq("read", false);

    if (error) {
      console.error("markAllNotificationsRead error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("markAllNotificationsRead unexpected error:", err);
    return { error: "Failed to mark all as read" };
  }
}

// ---- Notification Preferences ----

export async function getNotificationPreferences(): Promise<
  ActionResult<NotificationPreference[]>
> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("notification_preferences")
      .select("category, enabled")
      .eq("user_id", DEMO_CONSUMER_ID);

    if (error) {
      console.error("getNotificationPreferences error:", error);
      return { error: error.message };
    }

    // Return all categories with defaults (enabled=true for categories without a row)
    const prefMap = new Map(
      (data ?? []).map((p) => [p.category, p.enabled]),
    );

    const allPrefs = Object.values(NotificationCategory).map((cat) => ({
      category: cat,
      enabled: prefMap.get(cat) ?? true,
    }));

    return { data: allPrefs };
  } catch (err) {
    console.error("getNotificationPreferences unexpected error:", err);
    return { error: "Failed to get preferences" };
  }
}

export async function updateNotificationPreference(
  category: string,
  enabled: boolean,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { error } = await supabase
      .from("notification_preferences")
      .upsert(
        {
          user_id: DEMO_CONSUMER_ID,
          category,
          enabled,
        },
        { onConflict: "user_id,category" },
      );

    if (error) {
      console.error("updateNotificationPreference error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("updateNotificationPreference unexpected error:", err);
    return { error: "Failed to update preference" };
  }
}

// ---- Notification Triggers ----
// These are called from order lifecycle actions to create and send notifications.

interface SendNotificationPayload {
  user_id: string;
  category: string;
  title_en: string;
  title_ne: string;
  body_en: string;
  body_ne: string;
  data?: Record<string, unknown>;
}

/**
 * Trigger a notification via the Supabase edge function.
 * This creates the in-app notification, sends FCM push, and falls back to SMS.
 */
export async function triggerNotification(
  payload: SendNotificationPayload,
): Promise<void> {
  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !serviceKey) {
      console.error("triggerNotification: missing Supabase env vars");
      return;
    }

    const response = await fetch(
      `${supabaseUrl}/functions/v1/send-notification`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify(payload),
      },
    );

    if (!response.ok) {
      console.error(
        "triggerNotification failed:",
        response.status,
        await response.text(),
      );
    }
  } catch (err) {
    // Notification failures should not break order flows
    console.error("triggerNotification error:", err);
  }
}

// ---- Pre-built notification templates for order events ----

export async function notifyOrderMatched(
  consumerId: string,
  orderId: string,
  riderName: string,
): Promise<void> {
  await triggerNotification({
    user_id: consumerId,
    category: NotificationCategory.OrderMatched,
    title_en: "Order Matched!",
    title_ne: "अर्डर मिल्यो!",
    body_en: `Your order has been matched with rider ${riderName}.`,
    body_ne: `तपाईंको अर्डर राइडर ${riderName} सँग मिल्यो।`,
    data: { order_id: orderId, url: `/orders/${orderId}` },
  });
}

export async function notifyRiderPickedUp(
  consumerId: string,
  orderId: string,
): Promise<void> {
  await triggerNotification({
    user_id: consumerId,
    category: NotificationCategory.RiderPickedUp,
    title_en: "Produce Picked Up",
    title_ne: "सामान उठाइयो",
    body_en: "The rider has picked up your produce and is preparing for delivery.",
    body_ne: "राइडरले तपाईंको सामान उठाइसक्यो र डेलिभरीको लागि तयारी गर्दैछ।",
    data: { order_id: orderId, url: `/orders/${orderId}` },
  });
}

export async function notifyRiderArriving(
  consumerId: string,
  orderId: string,
): Promise<void> {
  await triggerNotification({
    user_id: consumerId,
    category: NotificationCategory.RiderArriving,
    title_en: "Rider Arriving Soon",
    title_ne: "राइडर आउँदैछ",
    body_en: "Your rider is almost at your delivery location!",
    body_ne: "तपाईंको राइडर तपाईंको डेलिभरी स्थानमा लगभग पुग्यो!",
    data: { order_id: orderId, url: `/orders/${orderId}` },
  });
}

export async function notifyOrderDelivered(
  consumerId: string,
  orderId: string,
): Promise<void> {
  await triggerNotification({
    user_id: consumerId,
    category: NotificationCategory.OrderDelivered,
    title_en: "Order Delivered!",
    title_ne: "अर्डर डेलिभर भयो!",
    body_en: "Your order has been delivered. Please confirm receipt.",
    body_ne: "तपाईंको अर्डर डेलिभर भएको छ। कृपया प्राप्ति पुष्टि गर्नुहोस्।",
    data: { order_id: orderId, url: `/orders/${orderId}` },
  });
}

export async function notifyFarmerNewOrder(
  farmerId: string,
  orderId: string,
  produceName: string,
  quantityKg: number,
): Promise<void> {
  await triggerNotification({
    user_id: farmerId,
    category: NotificationCategory.NewOrderForFarmer,
    title_en: "New Order!",
    title_ne: "नयाँ अर्डर!",
    body_en: `New order for ${quantityKg}kg of ${produceName}.`,
    body_ne: `${produceName} को ${quantityKg} केजी को नयाँ अर्डर।`,
    data: { order_id: orderId, url: `/farmer/dashboard` },
  });
}

export async function notifyFarmerRiderArriving(
  farmerId: string,
  orderId: string,
  riderName: string,
): Promise<void> {
  await triggerNotification({
    user_id: farmerId,
    category: NotificationCategory.RiderArrivingForPickup,
    title_en: "Rider Coming for Pickup",
    title_ne: "राइडर सामान लिन आउँदैछ",
    body_en: `Rider ${riderName} is heading to your location for pickup.`,
    body_ne: `राइडर ${riderName} सामान लिन तपाईंको स्थानमा आउँदैछ।`,
    data: { order_id: orderId, url: `/farmer/dashboard` },
  });
}

export async function notifyRiderNewOrderMatch(
  riderId: string,
  orderId: string,
  tripId: string,
): Promise<void> {
  await triggerNotification({
    user_id: riderId,
    category: NotificationCategory.NewOrderMatch,
    title_en: "New Order Matched to Your Trip",
    title_ne: "तपाईंको यात्रामा नयाँ अर्डर मिल्यो",
    body_en: "A new order has been matched to your trip. Check the details.",
    body_ne: "तपाईंको यात्रामा नयाँ अर्डर मिलेको छ। विवरण हेर्नुहोस्।",
    data: { order_id: orderId, trip_id: tripId, url: `/rider/trips/${tripId}` },
  });
}

export async function notifyRiderTripReminder(
  riderId: string,
  tripId: string,
  originName: string,
  destinationName: string,
): Promise<void> {
  await triggerNotification({
    user_id: riderId,
    category: NotificationCategory.TripReminder,
    title_en: "Trip Reminder",
    title_ne: "यात्रा सम्झना",
    body_en: `Your trip from ${originName} to ${destinationName} is coming up soon.`,
    body_ne: `${originName} देखि ${destinationName} सम्मको तपाईंको यात्रा चाँडै हुँदैछ।`,
    data: { trip_id: tripId, url: `/rider/trips/${tripId}` },
  });
}

export async function notifyRiderDeliveryConfirmed(
  riderId: string,
  orderId: string,
): Promise<void> {
  await triggerNotification({
    user_id: riderId,
    category: NotificationCategory.DeliveryConfirmed,
    title_en: "Delivery Confirmed!",
    title_ne: "डेलिभरी पुष्टि भयो!",
    body_en: "The consumer has confirmed delivery. Great job!",
    body_ne: "उपभोक्ताले डेलिभरी पुष्टि गरेको छ। राम्रो काम!",
    data: { order_id: orderId, url: `/rider/dashboard` },
  });
}
