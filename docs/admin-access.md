# Admin access — JiriSewa

## How it works

Admin gating is a single boolean column: `users.is_admin`.

- Server route guard: `apps/web/src/lib/admin/auth.ts` → `requireAdmin(locale)`
  reads `users.is_admin` for the current `auth.uid()` and redirects to
  `/{locale}` if false. Used by every page and action under
  `apps/web/src/app/[locale]/admin/*` and `lib/admin/*`.
- DB-level guard: RLS policies in
  `supabase/migrations/20260214100001_admin_role.sql` let admins read/write
  every table.
- Admin URL: `https://khetbata.xyz/{en|ne}/admin`

## Granting admin to a Jiri Nagarpalika user

There is no admin-grants-admin UI yet. Promote with SQL.

### Step 1 — the user must sign up first

Have the operator log in to `khetbata.xyz` once (Google OAuth or phone OTP) and
complete onboarding. That creates the `users` row.

### Step 2 — find their UUID

```sql
SELECT u.id, u.name, u.phone, p.email, p.full_name
FROM users u
LEFT JOIN user_profiles p ON p.id = u.id
WHERE p.email ILIKE '%jirimun.gov%'
   OR u.phone ILIKE '%';  -- narrow as needed
```

### Step 3 — flip the flag

```sql
UPDATE users SET is_admin = true WHERE id = '<uuid-from-step-2>';
```

Apply on prod:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.docker exec -T db \
  psql -U postgres -d postgres -c \
  "UPDATE users SET is_admin = true WHERE id = '<uuid>';"
```

### Step 4 — verify

```sql
SELECT id, name, phone, is_admin FROM users WHERE is_admin = true;
```

Have them refresh `khetbata.xyz/ne/admin` — they should land on the admin
dashboard instead of being redirected away.

## What admin can do

Available pages under `/{locale}/admin`:

| Page                       | Capability                                         |
|----------------------------|----------------------------------------------------|
| `/admin`                   | Platform stats dashboard                           |
| `/admin/users`             | User list, search by phone/name, view detail       |
| `/admin/users/[id]`        | View a user's roles                                |
| `/admin/orders`            | All orders, filter by status                       |
| `/admin/orders/[id]`       | Order detail, force-resolve, cancel, update status |
| `/admin/disputes`          | Disputed orders queue                              |
| `/admin/farmers`           | Farmer verification queue, approve/reject docs     |

## Revoking admin

```sql
UPDATE users SET is_admin = false WHERE id = '<uuid>';
```
