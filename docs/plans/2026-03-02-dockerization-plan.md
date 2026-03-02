# JiriSewa Dockerization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Dockerize the full JiriSewa production stack (Next.js + embedded Supabase) behind Traefik reverse proxy with auto-SSL, deployed via manual GitHub Actions CI/CD.

**Architecture:** Traefik handles TLS termination and domain routing on ports 80/443. JiriSewa runs as a self-contained Docker Compose stack with Next.js (standalone build) and all Supabase services (Postgres+PostGIS, Kong API gateway, GoTrue auth, PostgREST, Realtime, Storage, imgproxy, Studio, Meta). GitHub Actions builds the Next.js image on manual trigger and deploys to EC2 via SSH.

**Tech Stack:** Docker, Docker Compose, Traefik v3, Node 20, pnpm 9, Next.js 16 standalone, Supabase self-hosted images, GitHub Actions, ghcr.io

---

### Task 1: Create .dockerignore

**Files:**
- Create: `.dockerignore`

**Step 1: Create the file**

```
node_modules
.next
.git
.gitignore
*.md
docs/
apps/mobile/
supabase/
.env*
!.env.example
*.png
*.jpg
state.json
.playwright-mcp/
e2e-*.png
```

**Step 2: Verify**

Run: `cat .dockerignore | wc -l`
Expected: Non-zero line count, file exists.

**Step 3: Commit**

```bash
git add .dockerignore
git commit -m "chore: add .dockerignore for production builds"
```

---

### Task 2: Create Next.js Production Dockerfile

**Files:**
- Create: `Dockerfile`

**Context:** Next.js is configured with `output: "standalone"` in `apps/web/next.config.ts`. The monorepo uses pnpm workspaces with `apps/web` depending on `packages/shared` (workspace:*). The standalone build creates a self-contained Node.js server in `apps/web/.next/standalone/`.

**Step 1: Create the multi-stage Dockerfile**

```dockerfile
# ---- Stage 1: Install dependencies ----
FROM node:20-alpine AS deps
RUN corepack enable && corepack prepare pnpm@9 --activate
WORKDIR /app

# Copy workspace config + lockfile first (cache layer)
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY apps/web/package.json apps/web/package.json
COPY packages/shared/package.json packages/shared/package.json
COPY packages/database/package.json packages/database/package.json

RUN pnpm install --frozen-lockfile

# ---- Stage 2: Build ----
FROM node:20-alpine AS builder
RUN corepack enable && corepack prepare pnpm@9 --activate
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/web/node_modules ./apps/web/node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules
COPY --from=deps /app/packages/database/node_modules ./packages/database/node_modules

# Copy source
COPY package.json pnpm-workspace.yaml tsconfig.json ./
COPY apps/web/ apps/web/
COPY packages/shared/ packages/shared/
COPY packages/database/ packages/database/

# Build args for NEXT_PUBLIC_* env vars (baked into client bundle)
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG NEXT_PUBLIC_BASE_URL
ARG NEXT_PUBLIC_GOOGLE_CLIENT_ID
ARG NEXT_PUBLIC_FIREBASE_API_KEY
ARG NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN
ARG NEXT_PUBLIC_FIREBASE_PROJECT_ID
ARG NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET
ARG NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID
ARG NEXT_PUBLIC_FIREBASE_APP_ID
ARG NEXT_PUBLIC_FIREBASE_VAPID_KEY

ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL
ENV NEXT_PUBLIC_GOOGLE_CLIENT_ID=$NEXT_PUBLIC_GOOGLE_CLIENT_ID
ENV NEXT_PUBLIC_FIREBASE_API_KEY=$NEXT_PUBLIC_FIREBASE_API_KEY
ENV NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=$NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN
ENV NEXT_PUBLIC_FIREBASE_PROJECT_ID=$NEXT_PUBLIC_FIREBASE_PROJECT_ID
ENV NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=$NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET
ENV NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=$NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID
ENV NEXT_PUBLIC_FIREBASE_APP_ID=$NEXT_PUBLIC_FIREBASE_APP_ID
ENV NEXT_PUBLIC_FIREBASE_VAPID_KEY=$NEXT_PUBLIC_FIREBASE_VAPID_KEY

RUN pnpm --filter @jirisewa/web build

# ---- Stage 3: Production runner ----
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy standalone server
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
# Copy static assets
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./apps/web/.next/static
# Copy public directory
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public ./apps/web/public

USER nextjs
EXPOSE 3000

CMD ["node", "apps/web/server.js"]
```

**Step 2: Test the build locally (smoke test)**

Run: `docker build --build-arg NEXT_PUBLIC_SUPABASE_URL=http://test --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY=test --build-arg NEXT_PUBLIC_BASE_URL=http://test -t jirisewa-web:test .`
Expected: Build completes successfully. Final image is ~200MB or less.

Run: `docker images jirisewa-web:test --format "{{.Size}}"`
Expected: Under 300MB.

**Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: add multi-stage Dockerfile for Next.js standalone production build"
```

---

### Task 3: Create Traefik Reverse Proxy Stack

**Files:**
- Create: `traefik/docker-compose.yml`
- Create: `traefik/traefik.yml`

**Context:** Traefik is the shared reverse proxy on the EC2 instance. It handles TLS via Let's Encrypt, routes by domain to each app stack. It runs on a shared Docker network `traefik-public` that app stacks connect to. Port 80 redirects to 443.

**Step 1: Create traefik static config**

Create `traefik/traefik.yml`:

```yaml
api:
  dashboard: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: krantiutils@gmail.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik-public

log:
  level: WARN
```

**Step 2: Create traefik compose**

Create `traefik/docker-compose.yml`:

```yaml
services:
  traefik:
    image: traefik:v3.3
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik-certs:/letsencrypt
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
    networks:
      - traefik-public
    labels:
      # Dashboard (optional, IP-restrict in production)
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.khetbata.xyz`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"

volumes:
  traefik-certs:

networks:
  traefik-public:
    name: traefik-public
```

**Step 3: Commit**

```bash
git add traefik/
git commit -m "feat: add Traefik reverse proxy with auto-SSL via Let's Encrypt"
```

---

### Task 4: Create Supabase Init Volumes

**Files:**
- Create: `docker/volumes/db/roles.sql`
- Create: `docker/volumes/db/jwt.sql`
- Create: `docker/volumes/api/kong.yml`

**Context:** The Supabase Postgres image (`supabase/postgres:15.8.1.085`) ships with built-in roles (anon, authenticated, service_role, supabase_auth_admin, etc.) via its own init scripts. We mount additional init scripts to set passwords from env vars and configure JWT settings. Kong needs a declarative config that routes API paths to backend services.

**Step 1: Create roles.sql**

Create `docker/volumes/db/roles.sql`:

```sql
-- Set passwords for Supabase system roles from env vars
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_functions_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
```

**Step 2: Create jwt.sql**

Create `docker/volumes/db/jwt.sql`:

```sql
\set jwt_secret `echo "$JWT_SECRET"`
\set jwt_exp `echo "$JWT_EXP"`

ALTER DATABASE postgres SET "app.settings.jwt_secret" TO :'jwt_secret';
ALTER DATABASE postgres SET "app.settings.jwt_exp" TO :'jwt_exp';
```

**Step 3: Create kong.yml**

Create `docker/volumes/api/kong.yml`. This is the Kong declarative config for API gateway routing. It defines routes for auth, rest, realtime, storage, and meta services:

```yaml
_format_version: "2.1"
_transform: true

consumers:
  - username: DASHBOARD
  - username: anon
    keyauth_credentials:
      - key: ${SUPABASE_ANON_KEY}
  - username: service_role
    keyauth_credentials:
      - key: ${SUPABASE_SERVICE_KEY}

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  ## Auth
  - name: auth-v1-open
    url: http://auth:9999/verify
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - /auth/v1/verify
    plugins:
      - name: cors
  - name: auth-v1-open-callback
    url: http://auth:9999/callback
    routes:
      - name: auth-v1-open-callback
        strip_path: true
        paths:
          - /auth/v1/callback
    plugins:
      - name: cors
  - name: auth-v1-open-authorize
    url: http://auth:9999/authorize
    routes:
      - name: auth-v1-open-authorize
        strip_path: true
        paths:
          - /auth/v1/authorize
    plugins:
      - name: cors
  - name: auth-v1
    _comment: "GoTrue: /auth/v1/* -> http://auth:9999/*"
    url: http://auth:9999/
    routes:
      - name: auth-v1
        strip_path: true
        paths:
          - /auth/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  ## REST (PostgREST)
  - name: rest-v1
    _comment: "PostgREST: /rest/v1/* -> http://rest:3000/*"
    url: http://rest:3000/
    routes:
      - name: rest-v1
        strip_path: true
        paths:
          - /rest/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  ## Realtime
  - name: realtime-v1-ws
    _comment: "Realtime WS: /realtime/v1/* -> ws://realtime:4000/socket/*"
    url: http://realtime:4000/socket/
    routes:
      - name: realtime-v1-ws
        strip_path: true
        paths:
          - /realtime/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  ## Storage
  - name: storage-v1
    _comment: "Storage: /storage/v1/* -> http://storage:5000/*"
    url: http://storage:5000/
    routes:
      - name: storage-v1
        strip_path: true
        paths:
          - /storage/v1/
    plugins:
      - name: cors

  ## Postgres Meta (for Studio)
  - name: meta
    _comment: "pg-meta: /pg/* -> http://meta:8080/*"
    url: http://meta:8080/
    routes:
      - name: meta
        strip_path: true
        paths:
          - /pg/
    plugins:
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
```

**Step 4: Commit**

```bash
git add docker/
git commit -m "feat: add Supabase init volumes (roles, jwt, kong gateway config)"
```

---

### Task 5: Create .env.example for Docker Stack

**Files:**
- Create: `docker/.env.example`

**Context:** This is the template for all secrets and configuration used by the docker-compose.yml. On the EC2 server, this gets copied to `docker/.env` and filled with real values. The JWT keys (ANON_KEY, SERVICE_ROLE_KEY) must be generated from the JWT_SECRET using the Supabase JWT tool or `supabase start` output.

**Step 1: Create the env template**

Create `docker/.env.example`:

```bash
############
# Secrets
# Generate a new JWT_SECRET: openssl rand -base64 32
############

POSTGRES_PASSWORD=your-super-secret-postgres-password
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
ANON_KEY=eyJhbG...generate-from-jwt-secret
SERVICE_ROLE_KEY=eyJhbG...generate-from-jwt-secret
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=change-this-dashboard-password
SECRET_KEY_BASE=generate-with-openssl-rand-base64-64
PG_META_CRYPTO_KEY=generate-with-openssl-rand-base64-32

############
# Database
############

POSTGRES_HOST=db
POSTGRES_DB=postgres
POSTGRES_PORT=5432

############
# Supabase API
############

SITE_URL=https://khetbata.xyz
API_EXTERNAL_URL=https://khetbata.xyz/_supabase
SUPABASE_PUBLIC_URL=https://khetbata.xyz/_supabase
ADDITIONAL_REDIRECT_URLS=https://khetbata.xyz/api/auth/callback,https://khetbata.xyz/_supabase/auth/v1/callback

############
# Auth
############

JWT_EXPIRY=3600
DISABLE_SIGNUP=false
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=false
ENABLE_PHONE_SIGNUP=true
ENABLE_PHONE_AUTOCONFIRM=true
ENABLE_ANONYMOUS_USERS=false

# SMTP (for email auth — leave defaults if not using email)
SMTP_ADMIN_EMAIL=admin@khetbata.xyz
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your-smtp-user
SMTP_PASS=your-smtp-password
SMTP_SENDER_NAME=JiriSewa

# Mailer paths
MAILER_URLPATHS_CONFIRMATION=/auth/v1/verify
MAILER_URLPATHS_INVITE=/auth/v1/verify
MAILER_URLPATHS_RECOVERY=/auth/v1/verify
MAILER_URLPATHS_EMAIL_CHANGE=/auth/v1/verify

############
# PostgREST
############

PGRST_DB_SCHEMAS=public,storage,graphql_public

############
# Storage
############

GLOBAL_S3_BUCKET=stub
REGION=us-east-1
STORAGE_TENANT_ID=stub
S3_PROTOCOL_ACCESS_KEY_ID=generate-random-key
S3_PROTOCOL_ACCESS_KEY_SECRET=generate-random-secret
IMGPROXY_ENABLE_WEBP_DETECTION=true

############
# Studio
############

STUDIO_DEFAULT_ORGANIZATION=JiriSewa
STUDIO_DEFAULT_PROJECT=JiriSewa

############
# Kong ports (internal, not exposed to host — Traefik routes to kong:8000)
############

KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443

############
# Next.js App (runtime secrets — NOT baked into image)
############

SUPABASE_SERVICE_ROLE_KEY=same-as-SERVICE_ROLE_KEY-above
GOOGLE_CLIENT_SECRET=your-google-oauth-secret
ESEWA_SECRET_KEY=your-esewa-secret
ESEWA_PRODUCT_CODE=EPAYTEST
ESEWA_ENVIRONMENT=sandbox
KHALTI_SECRET_KEY=your-khalti-secret
KHALTI_ENVIRONMENT=sandbox
CONNECTIPS_MERCHANT_ID=
CONNECTIPS_APP_ID=
CONNECTIPS_APP_NAME=
CONNECTIPS_APP_PASSWORD=
CONNECTIPS_KEY_PATH=/app/secrets/connectips.key
CONNECTIPS_ENVIRONMENT=sandbox

############
# Next.js Build Args (NEXT_PUBLIC_* — baked into image at build time)
# These are used by GitHub Actions, not at runtime.
############

NEXT_PUBLIC_SUPABASE_URL=https://khetbata.xyz/_supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=same-as-ANON_KEY-above
NEXT_PUBLIC_BASE_URL=https://khetbata.xyz
NEXT_PUBLIC_GOOGLE_CLIENT_ID=your-google-client-id
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=
NEXT_PUBLIC_FIREBASE_VAPID_KEY=
```

**Step 2: Commit**

```bash
git add docker/.env.example
git commit -m "feat: add .env.example template for Docker stack secrets"
```

---

### Task 6: Create JiriSewa Docker Compose

**Files:**
- Create: `docker/docker-compose.yml`

**Context:** This is the main compose file for JiriSewa. It includes all Supabase services and the Next.js web app. The `web` and `kong` services connect to the `traefik-public` external network so Traefik can route to them. Internal services communicate on the `internal` network. The `db` exposes port 5432 only on the internal network.

Important routing: Traefik sends `khetbata.xyz` traffic to `web:3000`, and `khetbata.xyz/_supabase/*` to `kong:8000`. Kong then strips `/_supabase` (not applicable since Traefik strips the prefix) — actually Traefik uses a StripPrefix middleware to remove `/_supabase` before forwarding to Kong, so Kong sees `/auth/v1/...`, `/rest/v1/...`, etc.

**Step 1: Create docker-compose.yml**

Create `docker/docker-compose.yml`:

```yaml
services:
  # ===== Next.js Web App =====
  web:
    image: ghcr.io/krantiutils/jirisewa:latest
    restart: unless-stopped
    networks:
      - internal
      - traefik-public
    environment:
      - NODE_ENV=production
      - PORT=3000
      - HOSTNAME=0.0.0.0
      # Runtime secrets (not baked into image)
      - SUPABASE_SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
      - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
      - ESEWA_SECRET_KEY=${ESEWA_SECRET_KEY}
      - ESEWA_PRODUCT_CODE=${ESEWA_PRODUCT_CODE}
      - ESEWA_ENVIRONMENT=${ESEWA_ENVIRONMENT}
      - KHALTI_SECRET_KEY=${KHALTI_SECRET_KEY:-}
      - KHALTI_ENVIRONMENT=${KHALTI_ENVIRONMENT:-sandbox}
      - CONNECTIPS_MERCHANT_ID=${CONNECTIPS_MERCHANT_ID:-}
      - CONNECTIPS_APP_ID=${CONNECTIPS_APP_ID:-}
      - CONNECTIPS_APP_NAME=${CONNECTIPS_APP_NAME:-}
      - CONNECTIPS_APP_PASSWORD=${CONNECTIPS_APP_PASSWORD:-}
      - CONNECTIPS_KEY_PATH=${CONNECTIPS_KEY_PATH:-}
      - CONNECTIPS_ENVIRONMENT=${CONNECTIPS_ENVIRONMENT:-sandbox}
    labels:
      - "traefik.enable=true"
      # Main app route
      - "traefik.http.routers.jirisewa-web.rule=Host(`khetbata.xyz`)"
      - "traefik.http.routers.jirisewa-web.entrypoints=websecure"
      - "traefik.http.routers.jirisewa-web.tls.certresolver=letsencrypt"
      - "traefik.http.services.jirisewa-web.loadbalancer.server.port=3000"
    depends_on:
      db:
        condition: service_healthy

  # ===== Supabase API Gateway (Kong) =====
  kong:
    image: kong:2.8.1
    restart: unless-stopped
    networks:
      - internal
      - traefik-public
    volumes:
      - ./volumes/api/kong.yml:/home/kong/temp.yml:ro
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /home/kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth,request-termination
      KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
      KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
      DASHBOARD_USERNAME: ${DASHBOARD_USERNAME}
      DASHBOARD_PASSWORD: ${DASHBOARD_PASSWORD}
    entrypoint: bash -c 'eval "echo \"$$(cat ~/temp.yml)\"" > ~/kong.yml && /docker-entrypoint.sh kong docker-start'
    depends_on:
      auth:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      # Supabase API route: khetbata.xyz/_supabase/* → kong:8000
      - "traefik.http.routers.jirisewa-supabase.rule=Host(`khetbata.xyz`) && PathPrefix(`/_supabase`)"
      - "traefik.http.routers.jirisewa-supabase.entrypoints=websecure"
      - "traefik.http.routers.jirisewa-supabase.tls.certresolver=letsencrypt"
      - "traefik.http.routers.jirisewa-supabase.middlewares=strip-supabase-prefix"
      - "traefik.http.middlewares.strip-supabase-prefix.stripprefix.prefixes=/_supabase"
      - "traefik.http.services.jirisewa-supabase.loadbalancer.server.port=8000"

  # ===== PostgreSQL + PostGIS =====
  db:
    image: supabase/postgres:15.8.1.085
    restart: unless-stopped
    networks:
      - internal
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data
      - db-config:/etc/postgresql-custom
      - ./volumes/db/roles.sql:/docker-entrypoint-initdb.d/init-scripts/99-roles.sql:Z
      - ./volumes/db/jwt.sql:/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql:Z
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres", "-h", "localhost"]
      interval: 5s
      timeout: 5s
      retries: 10
    environment:
      POSTGRES_HOST: /var/run/postgresql
      PGPORT: ${POSTGRES_PORT:-5432}
      POSTGRES_PORT: ${POSTGRES_PORT:-5432}
      PGPASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      PGDATABASE: ${POSTGRES_DB:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXP: ${JWT_EXPIRY:-3600}
    command:
      - postgres
      - -c
      - config_file=/etc/postgresql/postgresql.conf
      - -c
      - log_min_messages=fatal

  # ===== GoTrue Auth =====
  auth:
    image: supabase/gotrue:v2.186.0
    restart: unless-stopped
    networks:
      - internal
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9999/health"]
      timeout: 5s
      interval: 5s
      retries: 3
    depends_on:
      db:
        condition: service_healthy
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://supabase_auth_admin:${POSTGRES_PASSWORD}@db:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-postgres}
      GOTRUE_SITE_URL: ${SITE_URL}
      GOTRUE_URI_ALLOW_LIST: ${ADDITIONAL_REDIRECT_URLS}
      GOTRUE_DISABLE_SIGNUP: ${DISABLE_SIGNUP:-false}
      GOTRUE_JWT_ADMIN_ROLES: service_role
      GOTRUE_JWT_AUD: authenticated
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      GOTRUE_JWT_EXP: ${JWT_EXPIRY:-3600}
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_EXTERNAL_EMAIL_ENABLED: ${ENABLE_EMAIL_SIGNUP:-true}
      GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED: ${ENABLE_ANONYMOUS_USERS:-false}
      GOTRUE_MAILER_AUTOCONFIRM: ${ENABLE_EMAIL_AUTOCONFIRM:-false}
      GOTRUE_SMTP_ADMIN_EMAIL: ${SMTP_ADMIN_EMAIL:-admin@example.com}
      GOTRUE_SMTP_HOST: ${SMTP_HOST:-smtp.example.com}
      GOTRUE_SMTP_PORT: ${SMTP_PORT:-587}
      GOTRUE_SMTP_USER: ${SMTP_USER:-}
      GOTRUE_SMTP_PASS: ${SMTP_PASS:-}
      GOTRUE_SMTP_SENDER_NAME: ${SMTP_SENDER_NAME:-JiriSewa}
      GOTRUE_MAILER_URLPATHS_INVITE: ${MAILER_URLPATHS_INVITE:-/auth/v1/verify}
      GOTRUE_MAILER_URLPATHS_CONFIRMATION: ${MAILER_URLPATHS_CONFIRMATION:-/auth/v1/verify}
      GOTRUE_MAILER_URLPATHS_RECOVERY: ${MAILER_URLPATHS_RECOVERY:-/auth/v1/verify}
      GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE: ${MAILER_URLPATHS_EMAIL_CHANGE:-/auth/v1/verify}
      GOTRUE_EXTERNAL_PHONE_ENABLED: ${ENABLE_PHONE_SIGNUP:-true}
      GOTRUE_SMS_AUTOCONFIRM: ${ENABLE_PHONE_AUTOCONFIRM:-true}

  # ===== PostgREST =====
  rest:
    image: postgrest/postgrest:v14.5
    restart: unless-stopped
    networks:
      - internal
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGRST_DB_URI: postgres://authenticator:${POSTGRES_PASSWORD}@db:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-postgres}
      PGRST_DB_SCHEMAS: ${PGRST_DB_SCHEMAS:-public,storage,graphql_public}
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"
      PGRST_APP_SETTINGS_JWT_SECRET: ${JWT_SECRET}
      PGRST_APP_SETTINGS_JWT_EXP: ${JWT_EXPIRY:-3600}
    command: ["postgrest"]

  # ===== Realtime =====
  realtime:
    image: supabase/realtime:v2.76.5
    restart: unless-stopped
    networks:
      - internal
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -sSfL --head -o /dev/null -H 'Authorization: Bearer ${ANON_KEY}' http://localhost:4000/api/tenants/realtime-dev/health"]
      timeout: 5s
      interval: 30s
      retries: 3
      start_period: 10s
    environment:
      PORT: 4000
      DB_HOST: db
      DB_PORT: ${POSTGRES_PORT:-5432}
      DB_USER: supabase_admin
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: ${POSTGRES_DB:-postgres}
      DB_AFTER_CONNECT_QUERY: "SET search_path TO _realtime"
      DB_ENC_KEY: supabaserealtime
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      ERL_AFLAGS: -proto_dist inet_tcp
      DNS_NODES: "''"
      RLIMIT_NOFILE: "10000"
      APP_NAME: realtime
      SEED_SELF_HOST: "true"
      RUN_JANITOR: "true"

  # ===== Storage =====
  storage:
    image: supabase/storage-api:v1.37.8
    restart: unless-stopped
    networks:
      - internal
    depends_on:
      db:
        condition: service_healthy
      rest:
        condition: service_started
      imgproxy:
        condition: service_started
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5000/status"]
      timeout: 5s
      interval: 5s
      retries: 3
    volumes:
      - storage-data:/var/lib/storage
    environment:
      ANON_KEY: ${ANON_KEY}
      SERVICE_KEY: ${SERVICE_ROLE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://supabase_storage_admin:${POSTGRES_PASSWORD}@db:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-postgres}
      FILE_SIZE_LIMIT: 52428800
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
      GLOBAL_S3_BUCKET: stub
      TENANT_ID: stub
      REGION: us-east-1
      ENABLE_IMAGE_TRANSFORMATION: "true"
      IMGPROXY_URL: http://imgproxy:5001
      S3_PROTOCOL_ACCESS_KEY_ID: ${S3_PROTOCOL_ACCESS_KEY_ID:-stub}
      S3_PROTOCOL_ACCESS_KEY_SECRET: ${S3_PROTOCOL_ACCESS_KEY_SECRET:-stub}

  # ===== imgproxy =====
  imgproxy:
    image: darthsim/imgproxy:v3.30.1
    restart: unless-stopped
    networks:
      - internal
    healthcheck:
      test: ["CMD", "imgproxy", "health"]
      timeout: 5s
      interval: 5s
      retries: 3
    volumes:
      - storage-data:/var/lib/storage:ro
    environment:
      IMGPROXY_BIND: ":5001"
      IMGPROXY_LOCAL_FILESYSTEM_ROOT: /
      IMGPROXY_USE_ETAG: "true"
      IMGPROXY_ENABLE_WEBP_DETECTION: ${IMGPROXY_ENABLE_WEBP_DETECTION:-true}
      IMGPROXY_MAX_SRC_RESOLUTION: 16.8

  # ===== Studio (Supabase Dashboard) =====
  studio:
    image: supabase/studio:2026.02.16-sha-26c615c
    restart: unless-stopped
    networks:
      - internal
      - traefik-public
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://localhost:3000/api/platform/profile').then((r) => {if (r.status !== 200) throw new Error(r.status)})"]
      timeout: 10s
      interval: 5s
      retries: 3
    depends_on:
      meta:
        condition: service_started
    environment:
      HOSTNAME: "::"
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DEFAULT_ORGANIZATION_NAME: ${STUDIO_DEFAULT_ORGANIZATION:-JiriSewa}
      DEFAULT_PROJECT_NAME: ${STUDIO_DEFAULT_PROJECT:-JiriSewa}
      SUPABASE_URL: http://kong:8000
      SUPABASE_PUBLIC_URL: ${SUPABASE_PUBLIC_URL}
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
      AUTH_JWT_SECRET: ${JWT_SECRET}
      NEXT_PUBLIC_ENABLE_LOGS: "false"
      NEXT_ANALYTICS_BACKEND_PROVIDER: postgres
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jirisewa-studio.rule=Host(`studio.khetbata.xyz`)"
      - "traefik.http.routers.jirisewa-studio.entrypoints=websecure"
      - "traefik.http.routers.jirisewa-studio.tls.certresolver=letsencrypt"
      - "traefik.http.services.jirisewa-studio.loadbalancer.server.port=3000"

  # ===== Postgres Meta (for Studio) =====
  meta:
    image: supabase/postgres-meta:v0.95.2
    restart: unless-stopped
    networks:
      - internal
    depends_on:
      db:
        condition: service_healthy
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: ${POSTGRES_PORT:-5432}
      PG_META_DB_NAME: ${POSTGRES_DB:-postgres}
      PG_META_DB_USER: supabase_admin
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
      CRYPTO_KEY: ${PG_META_CRYPTO_KEY}

  # ===== Migration Runner (one-shot) =====
  migrate:
    image: supabase/postgres:15.8.1.085
    restart: "no"
    networks:
      - internal
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ../supabase/migrations:/migrations:ro
      - ../supabase/seed:/seed:ro
    environment:
      PGHOST: db
      PGPORT: ${POSTGRES_PORT:-5432}
      PGDATABASE: ${POSTGRES_DB:-postgres}
      PGUSER: postgres
      PGPASSWORD: ${POSTGRES_PASSWORD}
    entrypoint: ["sh", "-c"]
    command:
      - |
        echo "Running migrations..."
        for f in /migrations/*.sql; do
          echo "Applying: $f"
          psql -f "$f" || exit 1
        done
        echo "Running seeds..."
        for f in /seed/*.sql; do
          echo "Seeding: $f"
          psql -f "$f" || exit 1
        done
        echo "Migrations complete."

volumes:
  db-data:
  db-config:
  storage-data:

networks:
  internal:
  traefik-public:
    external: true
```

**Step 2: Verify compose config parses**

Run: `cd docker && docker compose config --quiet`
Expected: No errors. (Requires .env file — copy .env.example first for validation.)

**Step 3: Commit**

```bash
git add docker/docker-compose.yml
git commit -m "feat: add docker-compose with full Supabase stack + Next.js + migration runner"
```

---

### Task 7: Create GitHub Actions Deploy Workflow

**Files:**
- Create: `.github/workflows/deploy.yml`

**Context:** Manual trigger (`workflow_dispatch`). Builds the Next.js Docker image using the multi-stage Dockerfile, pushes to ghcr.io, then SSHs to EC2 to pull and restart only the `web` service. The `NEXT_PUBLIC_*` env vars are passed as build args (baked into the client bundle at build time). Runtime secrets live in `.env` on the EC2 server.

**Step 1: Create the workflow**

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy JiriSewa

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Deploy environment"
        required: false
        default: "production"

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: krantiutils/jirisewa

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha
            type=raw,value=latest

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            NEXT_PUBLIC_SUPABASE_URL=${{ secrets.NEXT_PUBLIC_SUPABASE_URL }}
            NEXT_PUBLIC_SUPABASE_ANON_KEY=${{ secrets.NEXT_PUBLIC_SUPABASE_ANON_KEY }}
            NEXT_PUBLIC_BASE_URL=${{ secrets.NEXT_PUBLIC_BASE_URL }}
            NEXT_PUBLIC_GOOGLE_CLIENT_ID=${{ secrets.NEXT_PUBLIC_GOOGLE_CLIENT_ID }}
            NEXT_PUBLIC_FIREBASE_API_KEY=${{ secrets.NEXT_PUBLIC_FIREBASE_API_KEY }}
            NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=${{ secrets.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN }}
            NEXT_PUBLIC_FIREBASE_PROJECT_ID=${{ secrets.NEXT_PUBLIC_FIREBASE_PROJECT_ID }}
            NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=${{ secrets.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET }}
            NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=${{ secrets.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID }}
            NEXT_PUBLIC_FIREBASE_APP_ID=${{ secrets.NEXT_PUBLIC_FIREBASE_APP_ID }}
            NEXT_PUBLIC_FIREBASE_VAPID_KEY=${{ secrets.NEXT_PUBLIC_FIREBASE_VAPID_KEY }}

  deploy:
    runs-on: ubuntu-latest
    needs: build-and-push

    steps:
      - name: Deploy to EC2
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            echo "Pulling latest image..."
            docker pull ghcr.io/krantiutils/jirisewa:latest

            echo "Restarting web service..."
            cd ~/jirisewa/docker
            docker compose up -d web

            echo "Verifying..."
            sleep 5
            docker compose ps web
            echo "Deploy complete!"
```

**Step 2: Commit**

```bash
git add .github/
git commit -m "feat: add GitHub Actions manual deploy workflow (build, push to ghcr.io, deploy to EC2)"
```

---

### Task 8: Update next.config.ts for Production Image Patterns

**Files:**
- Modify: `apps/web/next.config.ts`

**Context:** The current `next.config.ts` only allows images from `127.0.0.1:54321` (local Supabase) and `*.supabase.co`. In Docker, the storage service is at `storage:5000` internally, but externally images are served via `khetbata.xyz/_supabase/storage/v1/...`. We need to add `khetbata.xyz` to the allowed remote patterns.

**Step 1: Add khetbata.xyz to remotePatterns**

In `apps/web/next.config.ts`, add to the `remotePatterns` array:

```typescript
{
  protocol: "https",
  hostname: "khetbata.xyz",
  pathname: "/_supabase/storage/v1/object/public/**",
},
```

**Step 2: Commit**

```bash
git add apps/web/next.config.ts
git commit -m "fix: add khetbata.xyz to Next.js image remote patterns for Docker deployment"
```

---

### Task 9: Update DEPLOY.md

**Files:**
- Modify: `DEPLOY.md`

**Step 1: Rewrite DEPLOY.md** to document the new Docker-based deployment:

- First-time EC2 setup (install Docker, create directories, copy compose files, configure .env)
- How to run migrations (`docker compose run --rm migrate`)
- How automatic deploys work (push to master → trigger GitHub Actions)
- How to manually deploy
- How to view logs (`docker compose logs -f web`)
- How to rollback (pin to a specific SHA tag)
- GitHub Secrets setup checklist

**Step 2: Commit**

```bash
git add DEPLOY.md
git commit -m "docs: rewrite DEPLOY.md for Docker-based deployment with Traefik + GitHub Actions"
```

---

### Task 10: Integration Smoke Test

**Step 1: Verify Docker build locally**

```bash
docker build \
  --build-arg NEXT_PUBLIC_SUPABASE_URL=http://test \
  --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY=test \
  --build-arg NEXT_PUBLIC_BASE_URL=http://test \
  -t jirisewa-web:test .
```

Expected: Build succeeds. Check image size is reasonable.

**Step 2: Verify compose config**

```bash
cd docker
cp .env.example .env
docker compose config > /dev/null
echo "Config OK"
```

Expected: No errors from compose config.

**Step 3: Verify traefik config**

```bash
cd traefik
docker compose config > /dev/null
echo "Config OK"
```

Expected: No errors.

**Step 4: Final commit with all files**

If any fixes were needed during smoke testing, commit them.

```bash
git push
```
