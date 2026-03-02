# JiriSewa Deployment Guide

## Server Information

- **Server**: ubuntu@54.156.88.160
- **Domain**: https://khetbata.xyz
- **Studio**: https://studio.khetbata.xyz
- **Container Registry**: ghcr.io/krantiutils/jirisewa

## Architecture

```
Traefik (ports 80/443, auto-SSL)
├── khetbata.xyz → jirisewa-web:3000
├── khetbata.xyz/_supabase/* → kong:8000
└── studio.khetbata.xyz → studio:3000

JiriSewa Stack (docker/docker-compose.yml)
├── web          Next.js standalone
├── db           Postgres 15 + PostGIS
├── kong         Supabase API gateway
├── auth         GoTrue
├── rest         PostgREST
├── realtime     WebSockets
├── storage      File storage
├── imgproxy     Image transforms
├── studio       Supabase Dashboard
└── meta         Postgres metadata
```

## Automated Deploy (CI/CD)

Deployments are triggered manually via GitHub Actions:

1. Go to **Actions** tab in GitHub
2. Select **Deploy JiriSewa** workflow
3. Click **Run workflow**

This builds the Next.js image, pushes to ghcr.io, and deploys to EC2.

## First-Time EC2 Setup

### 1. Install Docker

```bash
ssh ubuntu@54.156.88.160

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
# Log out and back in for group to take effect
```

### 2. Set Up Directory Structure

```bash
mkdir -p ~/traefik ~/jirisewa/docker
```

### 3. Clone and Configure

```bash
# Clone the repo (just for config files)
cd ~/jirisewa
git clone https://github.com/krantiutils/jirisewa.git repo
cp repo/traefik/* ~/traefik/
cp -r repo/docker/* ~/jirisewa/docker/

# Configure secrets
cd ~/jirisewa-docker
cp .env.example .env
vim .env  # Fill in all secrets
```

### 4. Generate Supabase Keys

```bash
# Generate JWT secret
openssl rand -base64 32

# Generate ANON_KEY and SERVICE_ROLE_KEY from the JWT secret
# Use: https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys
# Or use the supabase CLI: supabase bootstrap
```

### 5. Start Everything

```bash
# Create shared network
docker network create traefik-public

# Start Traefik
cd ~/traefik
docker compose up -d

# Start JiriSewa
cd ~/jirisewa-docker
docker compose up -d

# Run migrations (first time only)
docker compose run --rm migrate
```

### 6. Set Up GitHub Secrets

In the GitHub repo settings (Settings > Secrets > Actions), add:

| Secret | Value |
|--------|-------|
| `EC2_HOST` | `54.156.88.160` |
| `EC2_SSH_KEY` | SSH private key for ubuntu user |
| `GHCR_TOKEN` | GitHub PAT with `read:packages` scope (for EC2 to pull images) |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://khetbata.xyz/_supabase` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Your anon key |
| `NEXT_PUBLIC_BASE_URL` | `https://khetbata.xyz` |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `NEXT_PUBLIC_FIREBASE_*` | Firebase config values (6 secrets) |

## Manual Deploy

```bash
ssh ubuntu@54.156.88.160
cd ~/jirisewa-docker

# Pull and restart web only
docker compose pull web
docker compose up -d web
```

## Running Migrations

```bash
cd ~/jirisewa-docker
docker compose run --rm migrate
```

## Viewing Logs

```bash
cd ~/jirisewa-docker

# All services
docker compose logs -f

# Specific service
docker compose logs -f web
docker compose logs -f auth
docker compose logs -f db
```

## Rollback

```bash
cd ~/jirisewa-docker

# Find available image tags
docker image ls ghcr.io/krantiutils/jirisewa

# Edit docker-compose.yml to pin a specific SHA
# Change: image: ghcr.io/krantiutils/jirisewa:latest
# To:     image: ghcr.io/krantiutils/jirisewa:sha-abc1234
docker compose up -d web
```

## Google OAuth Configuration

Add this redirect URI in [Google Cloud Console](https://console.cloud.google.com/apis/credentials):

```
https://khetbata.xyz/_supabase/auth/v1/callback
```

## Testing

```bash
# Site is up
curl -s -o /dev/null -w '%{http_code}' https://khetbata.xyz

# Supabase API
curl -s https://khetbata.xyz/_supabase/rest/v1/ | head -5

# OAuth callback
curl -s "https://khetbata.xyz/_supabase/auth/v1/authorize?provider=google" | grep -o 'redirect_uri=[^&]*'
```

## Troubleshooting

### Container won't start

```bash
docker compose ps        # Check status
docker compose logs web  # Check logs for the failing service
```

### Database connection issues

```bash
# Check if db is healthy
docker compose ps db

# Connect directly
docker compose exec db psql -U postgres
```

### Restart everything

```bash
cd ~/jirisewa-docker
docker compose down
docker compose up -d
```

### Remove all data (nuclear option)

```bash
docker compose down -v  # -v removes volumes (DATA LOSS!)
docker compose up -d
docker compose run --rm migrate  # Re-run migrations
```
