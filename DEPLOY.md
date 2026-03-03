# JiriSewa Deployment Guide

## Server Information

- **Server**: hetzner-1 (ARM) — `ubuntu@178.104.21.224`
- **Domain**: https://khetbata.xyz
- **Studio**: https://studio.khetbata.xyz
- **Source**: `~/jirisewa-src` (git clone)
- **Compose**: `~/jirisewa-docker/docker-compose.prod.yml`

## Architecture

```
Traefik (ports 80/443, auto-SSL via Docker labels)
├── khetbata.xyz → jirisewa-web:3000
├── khetbata.xyz/_supabase/* → jirisewa-kong:8000
└── studio.khetbata.xyz → jirisewa-studio:3000

JiriSewa Stack (~/jirisewa-docker/docker-compose.prod.yml)
├── web          Next.js standalone (ARM image, built on server)
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

This SSHes into hetzner-1, pulls the latest code, builds the ARM Docker image natively, and restarts the web service.

### GitHub Secrets

| Secret | Value |
|--------|-------|
| `SERVER_HOST` | `178.104.21.224` |
| `SERVER_SSH_KEY` | SSH private key (hetzner-1-deploy) |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://khetbata.xyz/_supabase` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Your anon key |
| `NEXT_PUBLIC_BASE_URL` | `https://khetbata.xyz` |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `NEXT_PUBLIC_FIREBASE_*` | Firebase config values (6 secrets) |

## Manual Deploy

```bash
ssh ubuntu@178.104.21.224

# Pull latest code and rebuild
cd ~/jirisewa-src
git pull
docker build -t ghcr.io/krantiutils/jirisewa:latest \
  --build-arg NEXT_PUBLIC_SUPABASE_URL=https://khetbata.xyz/_supabase \
  --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY=<your-anon-key> \
  --build-arg NEXT_PUBLIC_BASE_URL=https://khetbata.xyz \
  --build-arg NEXT_PUBLIC_GOOGLE_CLIENT_ID=<your-google-client-id> \
  .

# Restart web
cd ~/jirisewa-docker
docker compose -f docker-compose.prod.yml --env-file .env.docker up -d web
docker image prune -f
```

## Running Migrations

```bash
ssh ubuntu@178.104.21.224
cd ~/jirisewa-src
for f in supabase/migrations/*.sql; do
  echo "Applying $(basename $f)..."
  docker exec -i jirisewa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$f"
done
```

## Viewing Logs

```bash
ssh ubuntu@178.104.21.224
cd ~/jirisewa-docker

# All services
docker compose -f docker-compose.prod.yml --env-file .env.docker logs -f

# Specific service
docker logs jirisewa-web --tail 50 -f
docker logs jirisewa-auth --tail 50 -f
docker logs jirisewa-db --tail 50 -f
```

## Managing Services

```bash
cd ~/jirisewa-docker

# Start all
docker compose -f docker-compose.prod.yml --env-file .env.docker up -d

# Restart specific service
docker compose -f docker-compose.prod.yml --env-file .env.docker restart web

# Stop all
docker compose -f docker-compose.prod.yml --env-file .env.docker down

# Status
docker compose -f docker-compose.prod.yml --env-file .env.docker ps
```

## Database

```bash
# Connect
docker exec -it jirisewa-db psql -U postgres -d postgres

# Backup
docker exec jirisewa-db pg_dumpall -U postgres | gzip > ~/jirisewa-backup-$(date +%Y%m%d).sql.gz

# Restore
gunzip -c backup.sql.gz | docker exec -i jirisewa-db psql -U postgres -d postgres
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
curl -s https://khetbata.xyz/_supabase/rest/v1/ -H 'apikey: <anon-key>' | head -5

# Auth health
curl -s https://khetbata.xyz/_supabase/auth/v1/health -H 'apikey: <anon-key>'
```

## Troubleshooting

### Container won't start

```bash
docker compose -f docker-compose.prod.yml --env-file .env.docker ps
docker logs jirisewa-web --tail 50  # Check logs for the failing service
```

### Database connection issues

```bash
docker exec -it jirisewa-db psql -U postgres -d postgres
docker logs jirisewa-db --tail 50
```

### Restart everything

```bash
cd ~/jirisewa-docker
docker compose -f docker-compose.prod.yml --env-file .env.docker down
docker compose -f docker-compose.prod.yml --env-file .env.docker up -d
```
