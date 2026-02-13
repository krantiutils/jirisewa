# JiriSewa

Farm-to-consumer marketplace connecting Nepali farmers, consumers, and riders.

## Project Structure

```
jirisewa/
  apps/
    web/              # Next.js 15 — consumer + farmer web app
    mobile/           # Flutter — rider + consumer mobile app
  packages/
    database/         # Supabase migrations, seed data, type definitions
    shared/           # Shared constants, enums, validation schemas
  supabase/           # Supabase config, migrations, edge functions
```

## Prerequisites

- Node.js >= 20
- pnpm >= 9
- Flutter >= 3.x
- Docker (for local Supabase)

## Setup

```bash
# Install JS dependencies
pnpm install

# Run web app
pnpm dev

# Run Flutter mobile app
cd apps/mobile
flutter run
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Web frontend | Next.js 15, App Router, TypeScript, Tailwind CSS |
| Mobile | Flutter, Dart |
| Backend | Self-hosted Supabase (Auth, Realtime, Storage) |
| Database | PostgreSQL 16 + PostGIS |
| Maps | OpenStreetMap + Leaflet (web) + flutter_map (mobile) |
