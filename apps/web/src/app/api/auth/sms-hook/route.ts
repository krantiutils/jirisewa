import { NextResponse } from "next/server";
import { createHmac, timingSafeEqual } from "node:crypto";
import { buildOtpMessage, sendSms } from "@/lib/sms";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface SendSmsPayload {
  user?: { id?: string; phone?: string };
  sms?: { otp?: string; sms_type?: string };
}

function verifySignature(
  rawBody: string,
  webhookId: string | null,
  webhookTimestamp: string | null,
  webhookSignature: string | null,
  secrets: string,
): boolean {
  if (!webhookId || !webhookTimestamp || !webhookSignature) return false;

  const tsNum = Number(webhookTimestamp);
  if (!Number.isFinite(tsNum)) return false;
  if (Math.abs(Date.now() / 1000 - tsNum) > 5 * 60) return false;

  const signedContent = `${webhookId}.${webhookTimestamp}.${rawBody}`;

  const candidates = secrets
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => (s.startsWith("v1,") ? s.slice(3) : s))
    .map((s) => (s.startsWith("whsec_") ? s.slice("whsec_".length) : s));

  const provided = webhookSignature
    .split(" ")
    .map((s) => s.trim())
    .filter((s) => s.startsWith("v1,"))
    .map((s) => s.slice(3));

  for (const secret of candidates) {
    let key: Buffer;
    try {
      key = Buffer.from(secret, "base64");
    } catch {
      continue;
    }
    const expected = createHmac("sha256", key)
      .update(signedContent)
      .digest("base64");
    for (const sig of provided) {
      const a = Buffer.from(expected);
      const b = Buffer.from(sig);
      if (a.length === b.length && timingSafeEqual(a, b)) return true;
    }
  }
  return false;
}

export async function POST(req: Request) {
  const secrets = process.env.WEBHOOK_SEND_SMS_SECRET;
  if (!secrets) {
    return NextResponse.json(
      { error: "Hook secret not configured" },
      { status: 500 },
    );
  }

  const rawBody = await req.text();

  const valid = verifySignature(
    rawBody,
    req.headers.get("webhook-id"),
    req.headers.get("webhook-timestamp"),
    req.headers.get("webhook-signature"),
    secrets,
  );
  if (!valid) {
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  let payload: SendSmsPayload;
  try {
    payload = JSON.parse(rawBody) as SendSmsPayload;
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const phone = payload.user?.phone;
  const otp = payload.sms?.otp;
  if (!phone || !otp) {
    return NextResponse.json(
      { error: "Missing user.phone or sms.otp" },
      { status: 400 },
    );
  }

  const result = await sendSms(phone, buildOtpMessage(otp));
  if (!result.ok) {
    console.error("[sms-hook] Aakash send failed:", result.reason, "for", phone);
    return NextResponse.json({ error: result.reason }, { status: 502 });
  }

  return NextResponse.json({ ok: true, messageId: result.messageId });
}
