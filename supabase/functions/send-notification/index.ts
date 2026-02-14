import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

interface NotificationRequest {
  user_id: string;
  category: string;
  title_en: string;
  title_ne: string;
  body_en: string;
  body_ne: string;
  data?: Record<string, unknown>;
}

interface CreateNotificationResult {
  notification_id: string;
  user_lang: string;
  phone: string;
  tokens: Array<{ token: string; platform: string }>;
  has_tokens: boolean;
  title: string;
  body: string;
  data: Record<string, unknown>;
  skipped?: boolean;
  reason?: string;
}

/**
 * Send an FCM push notification via Firebase HTTP v1 API.
 * Falls back to SMS if user has no registered device tokens.
 */
async function sendFcmPush(
  token: string,
  title: string,
  body: string,
  data: Record<string, unknown>,
  fcmServerKey: string,
): Promise<boolean> {
  try {
    const response = await fetch(
      "https://fcm.googleapis.com/fcm/send",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify({
          to: token,
          notification: { title, body },
          data: { ...data, click_action: "OPEN_NOTIFICATION" },
          priority: "high",
        }),
      },
    );

    if (!response.ok) {
      console.error("FCM push failed:", response.status, await response.text());
      return false;
    }

    const result = await response.json();
    // FCM returns success=1 if delivered
    return result.success === 1;
  } catch (err) {
    console.error("FCM push error:", err);
    return false;
  }
}

/**
 * Send SMS fallback via Sparrow SMS (Nepal SMS gateway).
 * Used when user has no registered FCM tokens.
 */
async function sendSmsFallback(
  phone: string,
  message: string,
): Promise<boolean> {
  const sparrowToken = Deno.env.get("SPARROW_SMS_TOKEN");
  const sparrowFrom = Deno.env.get("SPARROW_SMS_FROM") ?? "JiriSewa";

  if (!sparrowToken) {
    console.error("SMS fallback: SPARROW_SMS_TOKEN not configured");
    return false;
  }

  try {
    const response = await fetch(
      "https://api.sparrowsms.com/v2/sms/",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: sparrowToken,
          from: sparrowFrom,
          to: phone,
          text: message,
        }),
      },
    );

    if (!response.ok) {
      console.error("SMS send failed:", response.status, await response.text());
      return false;
    }

    return true;
  } catch (err) {
    console.error("SMS send error:", err);
    return false;
  }
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

  // Verify the caller is using the service role key
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || authHeader !== `Bearer ${supabaseServiceKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  let payload: NotificationRequest;
  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!payload.user_id || !payload.category || !payload.title_en || !payload.title_ne || !payload.body_en || !payload.body_ne) {
    return new Response(
      JSON.stringify({ error: "Missing required fields: user_id, category, title_en, title_ne, body_en, body_ne" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  // Create notification record and get user data + tokens
  const { data: result, error } = await supabase.rpc("create_notification", {
    p_user_id: payload.user_id,
    p_category: payload.category,
    p_title_en: payload.title_en,
    p_title_ne: payload.title_ne,
    p_body_en: payload.body_en,
    p_body_ne: payload.body_ne,
    p_data: payload.data ?? {},
  });

  if (error) {
    console.error("create_notification RPC error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to create notification" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const notifResult = result as unknown as CreateNotificationResult;

  if (notifResult.skipped) {
    return new Response(
      JSON.stringify({ status: "skipped", reason: notifResult.reason }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

  let pushSent = false;
  let smsFallbackSent = false;

  // Attempt FCM push if user has tokens and FCM key is configured
  if (notifResult.has_tokens && fcmServerKey) {
    const pushResults = await Promise.all(
      notifResult.tokens.map((t) =>
        sendFcmPush(
          t.token,
          notifResult.title,
          notifResult.body,
          notifResult.data,
          fcmServerKey,
        )
      ),
    );
    pushSent = pushResults.some((r) => r);

    // Deactivate tokens that failed (likely expired/unregistered)
    const failedTokens = notifResult.tokens.filter((_, i) => !pushResults[i]);
    if (failedTokens.length > 0) {
      await supabase
        .from("user_devices")
        .update({ is_active: false })
        .in(
          "fcm_token",
          failedTokens.map((t) => t.token),
        )
        .eq("user_id", payload.user_id);
    }
  }

  // SMS fallback if push wasn't sent or failed
  if (!pushSent && notifResult.phone) {
    const smsMessage = `${notifResult.title}: ${notifResult.body}`;
    smsFallbackSent = await sendSmsFallback(notifResult.phone, smsMessage);
  }

  // Update notification record with delivery status
  await supabase
    .from("notifications")
    .update({
      push_sent: pushSent,
      sms_fallback_sent: smsFallbackSent,
    })
    .eq("id", notifResult.notification_id);

  return new Response(
    JSON.stringify({
      status: "sent",
      notification_id: notifResult.notification_id,
      push_sent: pushSent,
      sms_fallback_sent: smsFallbackSent,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
