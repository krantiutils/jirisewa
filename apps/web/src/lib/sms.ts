const AAKASH_SMS_API_URL =
  process.env.AAKASH_SMS_API_URL ?? "https://sms.aakashsms.com/sms/v3/send";

interface AakashSmsResponse {
  error: boolean;
  message: string;
  data?: {
    valid?: Array<{
      id: number;
      mobile: string;
      text: string;
      credit: number;
      network: string;
      status: string;
    }>;
    invalid?: string[];
  };
}

export type SendSmsResult =
  | { ok: true; messageId?: number }
  | { ok: false; reason: string };

export function normalizeNepalPhone(phone: string): string | null {
  const digits = phone.replace(/\D/g, "");
  if (digits.startsWith("977") && digits.length === 13) return digits.slice(3);
  if (digits.length === 10 && /^9[678]/.test(digits)) return digits;
  return null;
}

export async function sendSms(
  to: string,
  text: string,
): Promise<SendSmsResult> {
  const token = process.env.AAKASH_SMS_TOKEN;
  if (!token) return { ok: false, reason: "AAKASH_SMS_TOKEN not configured" };

  const normalized = normalizeNepalPhone(to);
  if (!normalized) return { ok: false, reason: "Invalid Nepal phone number" };

  let res: Response;
  try {
    res = await fetch(AAKASH_SMS_API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ auth_token: token, to: normalized, text }),
    });
  } catch (e) {
    return { ok: false, reason: `Network error: ${(e as Error).message}` };
  }

  let data: AakashSmsResponse;
  try {
    data = (await res.json()) as AakashSmsResponse;
  } catch {
    return { ok: false, reason: `Aakash returned ${res.status} non-JSON` };
  }

  if (data.error) return { ok: false, reason: data.message || "Aakash error" };
  if (data.data?.invalid?.length)
    return { ok: false, reason: "Aakash marked phone invalid" };

  return { ok: true, messageId: data.data?.valid?.[0]?.id };
}

export function buildOtpMessage(otp: string): string {
  return `${otp} is your JiriSewa verification code. Valid for 5 minutes. Do not share.`;
}
