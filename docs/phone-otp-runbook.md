# Phone OTP — runbook

## What the flow looks like in code

1. Client (`apps/web/src/app/[locale]/auth/login/...`) calls
   `useAuth().signInWithOtp(toE164(phone))` →
   `supabase.auth.signInWithOtp({ phone })`.
2. GoTrue receives the request and (when configured) fires the **Send-SMS
   webhook** at `${GOTRUE_HOOK_SEND_SMS_URI}`.
3. Our hook receiver lives at `apps/web/src/app/api/auth/sms-hook/route.ts`.
   It verifies the Standard-Webhooks HMAC, then forwards `{phone, otp}` to
   Aakash SMS via `apps/web/src/lib/sms.ts`.
4. User types the OTP into the form. Client calls
   `supabase.auth.verifyOtp({ phone, token, type: "sms" })`. GoTrue returns
   a session. `onAuthStateChange` fires in `AuthProvider` → fetches profile
   → redirects to onboarding or the role dashboard.

## If "verification doesn't work"

The most common cause is **prod env vars not set on the GoTrue + web
containers**. The `.env.example` defaults intentionally have the hook
disabled.

### Required env vars on the prod `.env.docker`

GoTrue (`auth` service):

```
GOTRUE_HOOK_SEND_SMS_ENABLED=true
GOTRUE_HOOK_SEND_SMS_URI=https://khetbata.xyz/api/auth/sms-hook
GOTRUE_HOOK_SEND_SMS_SECRETS=v1,whsec_<base64-32B>
ENABLE_PHONE_AUTOCONFIRM=false
```

Web (`web` service):

```
AAKASH_SMS_TOKEN=<token from sms.aakashsms.com dashboard>
AAKASH_SMS_API_URL=https://sms.aakashsms.com/sms/v3/send
WEBHOOK_SEND_SMS_SECRET=<same base64-32B value as in GOTRUE_HOOK_SEND_SMS_SECRETS, without the v1,whsec_ prefix>
```

`WEBHOOK_SEND_SMS_SECRET` is what our hook receiver uses to verify the HMAC
that GoTrue signs with `GOTRUE_HOOK_SEND_SMS_SECRETS`. They must be the
same secret.

### Generate a secret

```bash
openssl rand -base64 32
# → e.g. mY7y5R8/UXWbF1J0fX...==
```

Use that value:
- on GoTrue: `GOTRUE_HOOK_SEND_SMS_SECRETS=v1,whsec_mY7y5R8/UXWbF1J0fX...==`
- on web:   `WEBHOOK_SEND_SMS_SECRET=mY7y5R8/UXWbF1J0fX...==`

### Apply

After editing `~/jirisewa-docker/.env.docker` on hetzner-1:

```bash
cd ~/jirisewa-docker
docker compose -f docker-compose.prod.yml --env-file .env.docker up -d auth web
```

## Diagnosing a failed send

```bash
# Tail logs while triggering an OTP from the login page
docker compose -f docker-compose.prod.yml --env-file .env.docker logs -f auth web | grep -iE "sms|otp|hook|webhook"
```

Common signatures:

| Log fragment                                | Meaning                                              |
|---------------------------------------------|------------------------------------------------------|
| `400 send_sms_hook ... 401 Invalid signature` | Secrets don't match between GoTrue and web         |
| `Hook secret not configured`                  | `WEBHOOK_SEND_SMS_SECRET` missing on web container |
| `[sms-hook] Aakash send failed`               | Aakash rejected (bad token / unsupported number)   |
| (no hook log at all)                          | `GOTRUE_HOOK_SEND_SMS_ENABLED` not set to true     |

## After the fix is verified

Set the deploy script to enforce these vars exist (fail-fast on container
start). For now they are optional with `${VAR:-}` defaults in
`docker/docker-compose.yml`, which silently ships a broken auth experience
when missed.

## What about session cookies on the web?

Independent of the SMS path: a Next.js root `middleware.ts` is required
for SSR pages to see the session. It now lives at
`apps/web/src/middleware.ts` and composes `next-intl` routing with the
Supabase session-refresh helper from `lib/supabase/middleware.ts`. Without
it, server components called `getSession()` and saw `null` even right
after a successful client-side login.
