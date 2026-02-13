# JiriSewa — Specification

## 1. Problem

Nepal's agricultural supply chain has up to 7 layers of middlemen between farmer and consumer. A farmer in Jiri sells tomatoes at NPR 30/kg; by the time they reach a Kathmandu kitchen, the price is NPR 120/kg. The farmer gets 25%, middlemen take 75%. Meanwhile, people travel between Jiri and Kathmandu daily — buses, trucks, bikes, taxis — with unused cargo capacity.

JiriSewa eliminates middlemen by connecting three parties:
- **Farmers** who grow produce
- **Consumers** who buy produce
- **Riders** who are already traveling between locations and can carry produce

## 2. Core Concept

Anyone traveling from point A to point B can register as a rider and carry produce along their route. A farmer in Jiri lists their tomatoes. A consumer in Kathmandu orders them. A truck driver heading to Kathmandu tomorrow picks them up and delivers them. The farmer earns more, the consumer pays less, and the rider earns for carrying cargo they had capacity for anyway.

## 3. Architecture

### 3.1 Frontend
- **Web (consumers + farmers):** Next.js 15 with App Router. SSR for SEO — product pages, farmer profiles, and marketplace must be indexable. Bilingual (en/ne) via `[lang]` route param.
- **Mobile (riders + consumers):** Flutter. Rider app is mobile-only (needs GPS, camera for photo verification). Consumer app is a convenience layer over the web experience.

### 3.2 Backend
- **Self-hosted Supabase** on the deployment server
  - PostgreSQL 16 with PostGIS extension for geospatial queries
  - Supabase Auth (phone OTP — Nepal is phone-number-first, not email)
  - Supabase Realtime for live order status, rider tracking
  - Supabase Storage for produce photos, rider profile photos
  - Row Level Security (RLS) for multi-tenant data isolation

### 3.3 Maps
- **OpenStreetMap** via Leaflet (web) and flutter_map (mobile)
- **OSRM** (self-hosted or public) for route calculation and ETAs
- Nepal's OSM coverage is decent for major roads (Jiri-KTM highway is well mapped)

### 3.4 Payments
- **MVP:** Cash on delivery only. Rider collects from consumer, pays farmer minus platform fee.
- **Phase 2:** eSewa integration (Nepal's most-used digital wallet). Consumer pays via eSewa, platform holds in escrow, releases to farmer and rider on delivery confirmation.
- **Phase 3:** Khalti, bank transfer, connectIPS.

## 4. User Types & Flows

### 4.1 Farmer

**Registration:** Phone number + OTP → name, location (pin on map), farm name, municipality.

**Core flow:**
1. Farmer opens dashboard (web or mobile)
2. Lists produce: item name (from standard catalog + custom), price per kg, available quantity, freshness date, photos
3. Produce appears in marketplace for consumers in the delivery radius
4. Farmer gets notified when an order is placed
5. Farmer prepares the order for rider pickup
6. Rider arrives, farmer hands over produce, both confirm handoff in-app
7. Farmer receives payment after consumer confirms delivery

**Key screens:**
- Dashboard: active listings, pending orders, earnings summary
- Add/edit produce listing
- Order detail: what was ordered, which rider, pickup time
- Earnings history

### 4.2 Consumer

**Registration:** Phone number + OTP → name, delivery address (pin on map), municipality.

**Core flow:**
1. Consumer opens marketplace (web or mobile)
2. Browses produce by category, location, price
3. Sees available items from farmers, with estimated delivery based on rider trips
4. Adds items to cart (can order from multiple farmers in one order)
5. Chooses delivery window from available rider trips
6. Places order → order is created, matched to rider trip
7. Gets real-time updates: rider picked up → in transit → arriving → delivered
8. Confirms delivery, rates farmer and rider
9. Pays rider cash on delivery (MVP) or pays via eSewa (Phase 2)

**Key screens:**
- Marketplace: browse/search produce, filter by category/price/location
- Product detail: photos, price, farmer info, estimated delivery
- Cart and checkout
- Order tracking (map view with rider location)
- Order history with ratings

### 4.3 Rider

**Registration:** Phone number + OTP → name, vehicle type (bike/car/truck/bus), vehicle capacity (kg), license photo (optional for MVP), profile photo.

**Core flow (posting a trip):**
1. Rider opens app
2. Posts a trip: origin, destination, departure date/time, available capacity (kg), route (auto-calculated via OSRM or manual waypoints)
3. System matches pending orders along the rider's route
4. Rider sees matched orders: pickup location, drop location, weight, earnings
5. Rider accepts/declines individual orders
6. On trip day: rider follows route, picks up from farmers, delivers to consumers
7. At each pickup: rider photographs produce, both confirm handoff
8. At each delivery: consumer confirms receipt, rider collects cash (MVP)
9. Rider's earnings are tracked in-app

**Core flow (real-time pings):**
1. Rider is en route (GPS active)
2. New order comes in along their route
3. Rider gets pinged: "Pickup 2kg tomatoes from Farm X, 500m off your route, earn NPR 50"
4. Rider accepts/declines

**Key screens:**
- Post a trip: origin, destination, date, capacity
- Trip dashboard: matched orders, route map, pickup/drop sequence
- Active trip: navigation, pickup/delivery confirmations
- Earnings dashboard
- Rating history

## 5. Data Model

### 5.1 Core Tables

```
users
  id: uuid (PK)
  phone: text (unique, required)
  name: text
  role: enum (farmer, consumer, rider) -- users can have multiple roles
  avatar_url: text
  location: geography(Point, 4326) -- PostGIS
  address: text
  municipality: text
  lang: enum (en, ne) default 'ne'
  rating_avg: decimal(3,2) default 0
  rating_count: integer default 0
  created_at: timestamptz
  updated_at: timestamptz

user_roles
  id: uuid (PK)
  user_id: uuid (FK users)
  role: enum (farmer, consumer, rider)
  -- role-specific fields:
  farm_name: text (farmer only)
  vehicle_type: enum (bike, car, truck, bus, other) (rider only)
  vehicle_capacity_kg: decimal (rider only)
  license_photo_url: text (rider only)
  verified: boolean default false
  created_at: timestamptz

produce_categories
  id: uuid (PK)
  name_en: text
  name_ne: text
  icon: text
  sort_order: integer

produce_listings
  id: uuid (PK)
  farmer_id: uuid (FK users)
  category_id: uuid (FK produce_categories)
  name_en: text
  name_ne: text
  description: text
  price_per_kg: decimal(10,2) -- in NPR
  available_qty_kg: decimal(10,2)
  freshness_date: date -- when harvested/available
  location: geography(Point, 4326)
  photos: text[] -- array of storage URLs
  is_active: boolean default true
  created_at: timestamptz
  updated_at: timestamptz

rider_trips
  id: uuid (PK)
  rider_id: uuid (FK users)
  origin: geography(Point, 4326)
  origin_name: text
  destination: geography(Point, 4326)
  destination_name: text
  route: geography(LineString, 4326) -- OSRM-calculated route
  departure_at: timestamptz
  available_capacity_kg: decimal(10,2)
  remaining_capacity_kg: decimal(10,2)
  status: enum (scheduled, in_transit, completed, cancelled)
  created_at: timestamptz
  updated_at: timestamptz

orders
  id: uuid (PK)
  consumer_id: uuid (FK users)
  rider_trip_id: uuid (FK rider_trips, nullable) -- null until matched
  rider_id: uuid (FK users, nullable) -- null until matched
  status: enum (pending, matched, picked_up, in_transit, delivered, cancelled, disputed)
  delivery_address: text
  delivery_location: geography(Point, 4326)
  total_price: decimal(10,2) -- produce cost (100% to farmer)
  delivery_fee: decimal(10,2) -- 100% to rider
  payment_method: enum (cash, esewa, khalti)
  payment_status: enum (pending, collected, settled)
  created_at: timestamptz
  updated_at: timestamptz

order_items
  id: uuid (PK)
  order_id: uuid (FK orders)
  listing_id: uuid (FK produce_listings)
  farmer_id: uuid (FK users)
  quantity_kg: decimal(10,2)
  price_per_kg: decimal(10,2)
  subtotal: decimal(10,2)
  pickup_location: geography(Point, 4326)
  pickup_confirmed: boolean default false
  pickup_photo_url: text
  delivery_confirmed: boolean default false

ratings
  id: uuid (PK)
  order_id: uuid (FK orders)
  rater_id: uuid (FK users)
  rated_id: uuid (FK users)
  role_rated: enum (farmer, consumer, rider)
  score: integer CHECK (score >= 1 AND score <= 5)
  comment: text
  created_at: timestamptz

rider_location_log
  id: uuid (PK)
  rider_id: uuid (FK users)
  trip_id: uuid (FK rider_trips)
  location: geography(Point, 4326)
  speed_kmh: decimal
  recorded_at: timestamptz
  -- partitioned by recorded_at, auto-purge after 7 days
```

### 5.2 Key Indexes
```sql
CREATE INDEX idx_listings_location ON produce_listings USING GIST (location);
CREATE INDEX idx_listings_active ON produce_listings (is_active, category_id);
CREATE INDEX idx_trips_route ON rider_trips USING GIST (route);
CREATE INDEX idx_trips_status ON rider_trips (status, departure_at);
CREATE INDEX idx_orders_consumer ON orders (consumer_id, status);
CREATE INDEX idx_orders_rider ON orders (rider_id, status);
CREATE INDEX idx_rider_location ON rider_location_log USING GIST (location);
```

### 5.3 Key Queries
- **Find produce near consumer:** `ST_DWithin(listing.location, consumer.location, radius)`
- **Match orders to rider route:** `ST_DWithin(pickup.location, trip.route, max_detour_m) AND ST_DWithin(delivery.location, trip.route, max_detour_m)`
- **Rider tracking:** Insert to rider_location_log via Supabase Realtime channel, consumers subscribe to their order's rider

## 6. API Design

### 6.1 Auth
- `POST /auth/otp/send` — send OTP to phone
- `POST /auth/otp/verify` — verify OTP, return JWT
- `POST /auth/register` — complete registration with profile details

### 6.2 Produce
- `GET /produce` — browse marketplace (filters: category, location, price range, search)
- `GET /produce/:id` — single listing detail
- `POST /produce` — farmer creates listing (auth: farmer)
- `PATCH /produce/:id` — farmer updates listing (auth: owner)
- `DELETE /produce/:id` — farmer deactivates listing (auth: owner)

### 6.3 Trips
- `GET /trips` — browse available trips (filters: origin, destination, date, capacity)
- `GET /trips/:id` — trip detail with matched orders
- `POST /trips` — rider creates trip (auth: rider)
- `PATCH /trips/:id` — rider updates trip (auth: owner)
- `POST /trips/:id/start` — rider starts trip (auth: owner)
- `POST /trips/:id/complete` — rider completes trip (auth: owner)

### 6.4 Orders
- `POST /orders` — consumer places order (auth: consumer)
- `GET /orders` — list my orders (auth: any role, filtered by role)
- `GET /orders/:id` — order detail
- `POST /orders/:id/match` — system or rider matches order to trip
- `POST /orders/:id/pickup` — confirm pickup with photo (auth: rider)
- `POST /orders/:id/deliver` — confirm delivery (auth: rider)
- `POST /orders/:id/confirm` — consumer confirms receipt (auth: consumer)
- `POST /orders/:id/dispute` — raise dispute (auth: consumer)

### 6.5 Ratings
- `POST /orders/:id/rate` — rate counterparty after order complete (auth: any)
- `GET /users/:id/ratings` — public rating history

### 6.6 Realtime (Supabase Channels)
- `order:{order_id}` — order status changes
- `trip:{trip_id}` — rider location updates
- `rider:{rider_id}:pings` — new order pings for active riders

## 7. Revenue Model

**Free.** No platform fees, no commissions, no subscriptions. JiriSewa is a public utility for Nepali farmers and consumers. The platform makes zero revenue from transactions. Consumer pays produce price + delivery fee — 100% goes to farmer and rider respectively. Platform sustains on grants, sponsorships, or municipal funding.

## 8. Matching Algorithm

### 8.1 Trip-based Matching
When a consumer places an order:
1. Find all `scheduled` trips where:
   - Trip departure is within consumer's requested delivery window
   - Pickup location (farmer) is within `max_detour_km` of trip route
   - Delivery location (consumer) is within `max_detour_km` of trip route
   - Trip has enough `remaining_capacity_kg`
2. Rank by: least detour distance, highest rider rating, soonest departure
3. Notify top rider(s), first-accept wins

### 8.2 Real-time Pings
When a rider is `in_transit`:
1. New orders with pickup near rider's current position + remaining route
2. Rider gets push notification with order details + earnings
3. Rider accepts → order matched, route updated

### 8.3 Unmatched Orders
If no rider trip matches within 24 hours:
- Notify consumer: "No riders available for this route yet"
- Option to keep order open (wait for a trip) or cancel
- Option to increase delivery fee to attract riders

## 9. MVP Scope (Phase 1)

### In scope:
- Phone OTP auth (Supabase Auth with SMS provider)
- Farmer: register, list produce with photos and price
- Consumer: browse marketplace, search/filter, place order
- Rider: register with vehicle info, post trips, accept matched orders
- Order lifecycle: place → match → pickup (with photo) → deliver → confirm → rate
- Trip posting with route display on map
- Basic matching: trip-based (no real-time pings yet)
- Cash on delivery
- Bilingual UI (en/ne)
- Rating system (1-5 stars + comment)
- OSM maps with Leaflet/flutter_map
- Responsive web (Next.js) for consumers and farmers
- Flutter mobile app for riders

### Out of scope (Phase 1):
- Digital payments (eSewa/Khalti)
- Real-time rider tracking on map
- Real-time order pings for riders
- Push notifications (use SMS for MVP)
- Multi-stop route optimization
- Bulk orders
- Farmer verification
- Admin dashboard
- Analytics
- Dispute resolution system (manual via phone for MVP)
- Chat between users

## 10. Phase 2 Scope

- eSewa payment integration
- Real-time rider location tracking (consumer sees rider on map)
- Real-time order pings for in-transit riders
- Push notifications (Firebase Cloud Messaging)
- Admin dashboard (order management, user management, disputes)
- Farmer verification flow
- Multi-farmer orders (single order, multiple pickups)
- Order history and reorder
- Delivery fee calculator based on distance and weight

## 11. Phase 3 Scope

- Khalti, connectIPS, bank transfer
- Chat between consumer-rider, consumer-farmer
- Bulk ordering for businesses (restaurants, hotels, canteens)
- Subscription boxes (weekly produce delivery)
- Farmer analytics (what sells, pricing suggestions)
- Route optimization for multi-stop trips
- Rider leaderboards and incentives
- Expand beyond Jiri-KTM: location-agnostic, any municipality pair

## 12. Non-Functional Requirements

- **Performance:** Marketplace page loads in <2s on 3G (critical for Nepal)
- **Offline:** Rider app must queue location updates and sync when back online
- **Language:** All user-facing text in both English and Nepali. Nepali is default.
- **Accessibility:** Large touch targets (48px minimum), high contrast for outdoor use
- **Security:** Phone OTP auth, RLS on all tables, no direct DB access from client
- **Data:** GDPR-equivalent data handling. Users can delete their account and data.
- **Uptime:** 99% target. Graceful degradation — marketplace should work even if realtime is down.

## 13. Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| Web frontend | Next.js 15, App Router, TypeScript, Tailwind CSS |
| Mobile | Flutter, Dart |
| Backend | Self-hosted Supabase (Auth, Realtime, Storage) |
| Database | PostgreSQL 16 + PostGIS |
| Maps | OpenStreetMap + Leaflet (web) + flutter_map (mobile) |
| Routing | OSRM (self-hosted or public demo server for MVP) |
| SMS/OTP | Sparrow SMS or Aakash SMS (Nepal providers) |
| Hosting | VPS (Hetzner or local Nepal hosting) |
| CI/CD | GitHub Actions |
| Monitoring | Uptime Kuma + PostgreSQL pg_stat |

## 14. Project Structure

```
jirisewa/
  apps/
    web/                  # Next.js consumer + farmer web app
      src/
        app/[lang]/       # bilingual routes
          page.tsx        # landing/marketplace
          produce/        # browse produce
          orders/         # order management
          farmer/         # farmer dashboard
          auth/           # login/register
        components/
        lib/
    mobile/               # Flutter rider + consumer app
      lib/
        features/
          auth/
          marketplace/
          trips/
          orders/
          tracking/
        core/
          api/
          models/
          routing/
  packages/
    database/             # Supabase migrations, seed data, types
      migrations/
      seed/
      types/
    shared/               # Shared constants, enums, validation schemas
  supabase/
    config.toml
    migrations/
    functions/            # Edge functions if needed
  docs/
```

## 15. Open Decisions

1. **SMS provider:** Sparrow SMS vs Aakash SMS vs Nepal Telecom API — needs cost comparison for OTP volume
2. **Hosting location:** Hetzner (Europe) vs local Nepal VPS — latency vs reliability tradeoff
3. **OSRM hosting:** Public demo server is rate-limited. Self-host if traffic exceeds ~100 route calculations/day.
4. **Produce catalog:** Start with a curated list of ~50 common items (rice, tomatoes, potatoes, etc.) or fully open?
5. **Delivery fee calculation:** Flat fee per km? Per kg? Rider sets their own price?
