# Phone OTP — runbook

## What the flow looks like in code

1. Client (`apps/web/src/app/[locale]/auth/login/page.tsx`) calls
   `useAuth().signInWithOtp(toE164(phone))` →
   `supabase.auth.signInWithOtp({ phone })`.
2. GoTrue receives the request and (when configured) fires the Send-SMS
   webhook at `${GOTRUE_HOOK_SEND_SMS_URI}`.
3. Our hook receiver lives at `apps/web/src/app/api/auth/sms-hook/route.ts`.
   It verifies the Standard-Webhooks HMAC against
   `WEBHOOK_SEND_SMS_SECRET`, then forwards `{phone, otp}` to Aakash via
   `apps/web/src/lib/sms.ts`.
4. User types the OTP into the form. Client calls
   `supabase.auth.verifyOtp({ phone, token, type: "sms" })`. GoTrue
   returns a session. `onAuthStateChange` fires in `AuthProvider` →
   fetches profile → redirects to onboarding or the role dashboard.

## Required env vars

These are owned by the operator on `~/jirisewa-docker/.env.docker` on
hetzner-1. They are NOT in the repo.

GoTrue (`auth` service):

```
GOTRUE_HOOK_SEND_SMS_ENABLED=true
GOTRUE_HOOK_SEND_SMS_URI=https://khetbata.xyz/api/auth/sms-hook
GOTRUE_HOOK_SEND_SMS_SECRETS=v1,whsec_<base64-32B>
ENABLE_PHONE_AUTOCONFIRM=false
```

Web (`web` service):

```
AAKASH_SMS_TOKEN=<token from sms.aakashsms.com>
AAKASH_SMS_API_URL=https://sms.aakashsms.com/sms/v3/send
WEBHOOK_SEND_SMS_SECRET=<same base64 as in GOTRUE_HOOK_SEND_SMS_SECRETS, without the v1,whsec_ prefix>
```

`WEBHOOK_SEND_SMS_SECRET` and `GOTRUE_HOOK_SEND_SMS_SECRETS` must share
the same secret value.

## Diagnosing a failed send

```bash
docker compose -f docker-compose.prod.yml --env-file .env.docker logs --tail=200 -f auth web \
  | grep -iE "sms|otp|hook|webhook"
```

Trigger a phone OTP from the login page while watching this. Common
signatures:

| Log fragment                                  | Cause                                             |
|-----------------------------------------------|---------------------------------------------------|
| `401 Invalid signature` from `/api/auth/sms-hook` | Secrets don't match between GoTrue and web    |
| `Hook secret not configured`                    | `WEBHOOK_SEND_SMS_SECRET` missing on web        |
| `[sms-hook] Aakash send failed`                 | Aakash rejected (bad token, balance, format)    |
| (no hook log on auth side at all)               | `GOTRUE_HOOK_SEND_SMS_ENABLED` not true, or hook URI unreachable |

If you can paste a few hundred lines of those logs around a failing
attempt, the cause is usually obvious.
