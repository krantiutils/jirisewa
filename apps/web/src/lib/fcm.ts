import { createSign } from "node:crypto";

/**
 * FCM HTTP v1 client.
 *
 * Authenticates via a Firebase service account JSON, mints short-lived
 * OAuth2 access tokens (cached ~55 min), and POSTs to
 * https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send.
 *
 * Required env (one of):
 *   FIREBASE_SERVICE_ACCOUNT_BASE64  — base64 of the service account JSON (preferred for Docker)
 *   FIREBASE_SERVICE_ACCOUNT_JSON    — raw JSON string
 *
 * The service account JSON contains project_id, so no separate FIREBASE_PROJECT_ID is needed.
 */

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  token_uri: string;
}

interface AccessTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

let cachedAccount: ServiceAccount | null = null;
let cachedToken: { value: string; expiresAt: number } | null = null;

function loadServiceAccount(): ServiceAccount {
  if (cachedAccount) return cachedAccount;

  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  let parsed: ServiceAccount;
  if (b64) {
    parsed = JSON.parse(Buffer.from(b64, "base64").toString("utf-8"));
  } else if (raw) {
    parsed = JSON.parse(raw);
  } else {
    throw new Error(
      "FCM credentials missing: set FIREBASE_SERVICE_ACCOUNT_BASE64 or FIREBASE_SERVICE_ACCOUNT_JSON",
    );
  }

  if (!parsed.private_key || !parsed.client_email || !parsed.project_id) {
    throw new Error("FCM service account JSON malformed");
  }

  cachedAccount = parsed;
  return parsed;
}

function base64url(input: Buffer | string): string {
  const buf = typeof input === "string" ? Buffer.from(input) : input;
  return buf.toString("base64url");
}

function signJwt(privateKey: string, claim: Record<string, unknown>): string {
  const header = { alg: "RS256", typ: "JWT" };
  const data = `${base64url(JSON.stringify(header))}.${base64url(
    JSON.stringify(claim),
  )}`;
  const signer = createSign("RSA-SHA256");
  signer.update(data);
  signer.end();
  const signature = base64url(signer.sign(privateKey));
  return `${data}.${signature}`;
}

async function fetchAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const assertion = signJwt(account.private_key, claim);

  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const res = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`FCM access token exchange failed: ${res.status} ${body}`);
  }

  const json = (await res.json()) as AccessTokenResponse;
  return json.access_token;
}

async function getAccessToken(): Promise<{ token: string; projectId: string }> {
  const account = loadServiceAccount();

  if (cachedToken && Date.now() < cachedToken.expiresAt) {
    return { token: cachedToken.value, projectId: account.project_id };
  }

  const token = await fetchAccessToken(account);
  // Refresh ~5 min before the 1-hour expiry.
  cachedToken = { value: token, expiresAt: Date.now() + 55 * 60_000 };
  return { token, projectId: account.project_id };
}

/**
 * FCM HTTP v1 requires `data` values to be strings. Coerce nested values.
 */
function coerceDataValuesToStrings(
  data: Record<string, unknown>,
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

export interface FcmPushResult {
  /** Whether FCM accepted the push. */
  ok: boolean;
  /** True when the device token is no longer valid and should be deactivated. */
  shouldDeactivate: boolean;
  /** Raw error string for logs. */
  error?: string;
}

/**
 * Send a single FCM push via HTTP v1.
 * Returns ok=false when delivery failed; shouldDeactivate=true means the
 * caller should mark the device row as inactive (token expired/unregistered).
 */
export async function sendFcmPush(
  token: string,
  title: string,
  body: string,
  data: Record<string, unknown>,
): Promise<FcmPushResult> {
  let auth: { token: string; projectId: string };
  try {
    auth = await getAccessToken();
  } catch (err) {
    return { ok: false, shouldDeactivate: false, error: String(err) };
  }

  const url = `https://fcm.googleapis.com/v1/projects/${auth.projectId}/messages:send`;
  const message = {
    message: {
      token,
      notification: { title, body },
      data: coerceDataValuesToStrings({
        ...data,
        click_action: "OPEN_NOTIFICATION",
      }),
      android: { priority: "HIGH" as const },
    },
  };

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${auth.token}`,
      },
      body: JSON.stringify(message),
    });
  } catch (err) {
    return { ok: false, shouldDeactivate: false, error: String(err) };
  }

  if (res.ok) return { ok: true, shouldDeactivate: false };

  const text = await res.text();
  // FCM returns 404/UNREGISTERED or 400/INVALID_ARGUMENT for stale tokens.
  const shouldDeactivate =
    res.status === 404 ||
    /UNREGISTERED|INVALID_ARGUMENT/i.test(text);

  return {
    ok: false,
    shouldDeactivate,
    error: `FCM ${res.status}: ${text}`,
  };
}

/** True when FCM credentials are configured. Useful for graceful no-op in dev. */
export function isFcmConfigured(): boolean {
  return Boolean(
    process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 ||
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
  );
}
