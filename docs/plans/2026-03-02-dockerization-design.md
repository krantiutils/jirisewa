# JiriSewa Dockerization Design

**Date**: 2026-03-02
**Status**: Approved

## Goals

- Dockerize the entire JiriSewa production stack on a single EC2 instance
- Traefik as shared reverse proxy with auto-SSL (Let's Encrypt)
- Embedded Supabase services (no `supabase start` on bare metal)
- GitHub Actions CI/CD: push to master → build → deploy automatically
- Extensible for future apps on the same EC2

## Non-Goals

- Local dev Docker setup (dev runs raw: `supabase start` + `pnpm dev`)
- Mobile app dockerization (Flutter, compiled to native)
- Supabase Cloud migration

## Architecture

```
EC2 (54.156.88.160)
│
│ ports 80/443 only
│
├── traefik (reverse proxy + auto-SSL)
│   ├── khetbata.xyz → jirisewa-web:3000
│   ├── khetbata.xyz/_supabase/* → jirisewa-kong:8000
│   └── future-app.com → future-app:XXXX
│
└── jirisewa stack
    ├── web         Next.js standalone (production build)
    ├── db          Postgres 15 + PostGIS
    ├── kong        Supabase API gateway
    ├── auth        GoTrue (email, phone OTP, Google OAuth)
    ├── rest        PostgREST
    ├── realtime    WebSocket subscriptions
    ├── storage     File storage (produce photos)
    ├── imgproxy    Image transforms
    ├── studio      Supabase dashboard (auth-gated)
    └── meta        Postgres metadata (for Studio)
```

## Routing

| Domain/Path | Target | Notes |
|---|---|---|
| `khetbata.xyz` | `jirisewa-web:3000` | Next.js app |
| `khetbata.xyz/_supabase/*` | `jirisewa-kong:8000` | Supabase API gateway |
| `studio.khetbata.xyz` | `jirisewa-studio:3000` | Optional, IP-restricted |

## Files to Create

```
traefik/
  docker-compose.yml           # Traefik + shared network
  traefik.yml                  # Static config (entrypoints, ACME)

jirisewa/
  docker-compose.yml           # All JiriSewa services
  Dockerfile                   # Multi-stage: install → build → standalone
  .env.example                 # Template for secrets
  volumes/
    db/init/                   # Migration bootstrap SQL

.github/
  workflows/
    deploy.yml                 # Build → push to ghcr.io → SSH deploy

.dockerignore                  # Exclude node_modules, .next, etc.
```

## Docker Images

### Next.js (web) — Multi-stage Dockerfile

1. **Stage 1 (deps)**: `node:20-alpine` + pnpm, install all deps
2. **Stage 2 (build)**: Copy source, `next build` (standalone output)
3. **Stage 3 (run)**: `node:20-alpine`, copy standalone + static + public, ~150MB

### Supabase Services — Official Images

| Service | Image |
|---|---|
| db | `supabase/postgres:15.8.1.085` |
| kong | `kong:2.8.1` |
| auth | `supabase/gotrue:v2.186.0` |
| rest | `postgrest/postgrest:v14.5` |
| realtime | `supabase/realtime:v2.76.5` |
| storage | `supabase/storage-api:v1.37.8` |
| imgproxy | `darthsim/imgproxy:v3.30.1` |
| studio | `supabase/studio:2026.02.16-sha-26c615c` |
| meta | `supabase/postgres-meta:v0.95.2` |

## CI/CD Pipeline

**Trigger**: Manual (`workflow_dispatch`) — click "Run workflow" in GitHub Actions UI

```
Manual trigger (GitHub Actions UI)
  │
  ▼
Build & Push
  ├── Checkout repo
  ├── Set up Docker Buildx
  ├── Login to ghcr.io
  ├── Build Next.js image (multi-stage)
  ├── Push ghcr.io/krantiutils/jirisewa:latest
  └── Push ghcr.io/krantiutils/jirisewa:<git-sha>
  │
  ▼
Deploy
  ├── SSH to EC2
  ├── cd ~/jirisewa
  ├── docker compose pull web
  └── docker compose up -d web
```

**GitHub Secrets required:**
- `EC2_SSH_KEY` — SSH private key for ubuntu@54.156.88.160
- `EC2_HOST` — 54.156.88.160
- `GHCR_TOKEN` — or use automatic `GITHUB_TOKEN`

**Build-time env vars** (baked into image via ARG):
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_BASE_URL`
- `NEXT_PUBLIC_GOOGLE_CLIENT_ID`
- `NEXT_PUBLIC_FIREBASE_*` vars

**Runtime env vars** (in .env on EC2):
- `SUPABASE_SERVICE_ROLE_KEY`
- `GOOGLE_CLIENT_SECRET`
- `ESEWA_*`, `KHALTI_*`, `CONNECTIPS_*` payment secrets

## Networking

- **`traefik-public`**: External Docker network shared by Traefik and all app stacks
- **`jirisewa-internal`**: Internal network for Supabase services (db, auth, rest, etc.)
- Only `web` and `kong` join both networks (reachable by Traefik)

## Data Persistence

| Volume | Mount | Purpose |
|---|---|---|
| `jirisewa-db-data` | `/var/lib/postgresql/data` | Postgres data |
| `jirisewa-storage` | `/var/lib/storage` | Uploaded files |

## Migration Strategy

Migrations run via a one-shot `migrate` service in docker-compose that:
1. Waits for `db` to be healthy
2. Runs all SQL migrations from `supabase/migrations/` in order
3. Runs seed data from `supabase/seed/`
4. Exits

## Deploy Workflow (First Time)

```bash
ssh ubuntu@54.156.88.160

# 1. Install Docker + Docker Compose
# 2. Create directories
mkdir -p ~/traefik ~/jirisewa

# 3. Copy/clone compose files
# 4. Configure .env
cd ~/jirisewa && cp .env.example .env && vim .env

# 5. Start everything
cd ~/traefik && docker compose up -d
cd ~/jirisewa && docker compose up -d
```

After first-time setup, all subsequent deploys are automated via GitHub Actions.

## Deploy Workflow (Updates)

Fully automated: push to master → GitHub Actions builds, pushes, deploys.

For Supabase service updates: manually update image tags in docker-compose.yml and redeploy.

## Rollback

```bash
# Roll back to previous image
docker compose pull web  # if tags were updated
# Or specify exact SHA:
# In docker-compose.yml, change image tag to specific SHA
docker compose up -d web
```
