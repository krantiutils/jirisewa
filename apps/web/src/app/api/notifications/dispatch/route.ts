/**
 * FCM dispatch endpoint, called from a Postgres trigger via pg_net after
 * a row lands in `notifications`. The Next.js server is the FCM client
 * (Firebase admin creds live here, not in the database), so the trigger
 * just hands off the notification id and we do the rest.
 *
 * Auth: service-role bearer token. The trigger reads it from
 * current_setting('app.settings.service_role_key', true).
 */
import { NextRequest, NextResponse } from "next/server";
import { createServiceRoleClient } from "@/lib/supabase/server";
import { sendFcmPush, isFcmConfigured } from "@/lib/fcm";

export const runtime = "nodejs";

interface DispatchPayload {
  notification_id: string;
}

export async function POST(req: NextRequest) {
  // Bearer auth — must match SUPABASE_SERVICE_ROLE_KEY.
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token || token !== process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  let body: DispatchPayload;
  try {
    body = (await req.json()) as DispatchPayload;
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  if (!body?.notification_id) {
    return NextResponse.json({ error: "missing_notification_id" }, { status: 400 });
  }

  if (!isFcmConfigured()) {
    // Graceful no-op when creds aren't set yet — the in-app notification
    // row already exists and realtime will deliver to foregrounded users.
    return NextResponse.json({ skipped: "fcm_not_configured" });
  }

  const supabase = createServiceRoleClient();

  const { data: notif, error: notifErr } = await supabase
    .from("notifications")
    .select("id, user_id, title_en, title_ne, body_en, body_ne, data, push_sent")
    .eq("id", body.notification_id)
    .single();

  if (notifErr || !notif) {
    return NextResponse.json({ error: "notification_not_found" }, { status: 404 });
  }

  if (notif.push_sent) {
    return NextResponse.json({ skipped: "already_sent" });
  }

  const { data: user } = await supabase
    .from("users")
    .select("lang")
    .eq("id", notif.user_id)
    .single();
  const lang = user?.lang === "ne" ? "ne" : "en";
  const title = lang === "ne" ? notif.title_ne : notif.title_en;
  const pushBody = lang === "ne" ? notif.body_ne : notif.body_en;

  const { data: devices } = await supabase
    .from("user_devices")
    .select("fcm_token")
    .eq("user_id", notif.user_id)
    .eq("is_active", true);

  const tokens = (devices ?? []).map((d) => d.fcm_token).filter(Boolean) as string[];

  if (tokens.length === 0) {
    await supabase
      .from("notifications")
      .update({ push_sent: false })
      .eq("id", notif.id);
    return NextResponse.json({ sent: 0, reason: "no_tokens" });
  }

  const failedTokens: string[] = [];
  let sent = 0;
  await Promise.all(
    tokens.map(async (t) => {
      const r = await sendFcmPush(
        t,
        title,
        pushBody,
        (notif.data ?? {}) as Record<string, unknown>,
      );
      if (r.ok) {
        sent += 1;
      } else if (r.shouldDeactivate) {
        failedTokens.push(t);
      }
    }),
  );

  if (failedTokens.length > 0) {
    await supabase
      .from("user_devices")
      .update({ is_active: false })
      .in("fcm_token", failedTokens)
      .eq("user_id", notif.user_id);
  }

  await supabase
    .from("notifications")
    .update({ push_sent: sent > 0 })
    .eq("id", notif.id);

  return NextResponse.json({ sent, failed: failedTokens.length });
}
