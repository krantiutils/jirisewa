# JiriSewa: Phased Buildout Plan

**Date**: 2026-04-29
**Author**: emma
**Status**: planning — awaiting approval before implementation
**Companion doc**: [2026-04-29-honest-critique-and-gaps.md](./2026-04-29-honest-critique-and-gaps.md)

This is the implementation plan for the build order the overseer chose
out of the critique:

1. **Aggregation hubs** (origin-side)
2. **Subscriptions** (turn the schema stub into a live product)
3. **Quality policy** (pickup/delivery photos, grades, dispute window)
4. **Truck-route domain** (scheduled_trucks + multi-leg fulfilment)
5. **KTM micro-hubs** (destination-side)

Each phase ships independently and leaves the platform in a coherent
state — no half-merged refactors. Phases 1–3 are additive; Phase 4 is
the first one that breaks existing assumptions (the `rider_trip_id`
column on `orders`), so it has its own migration risk section.

---

## Phase 1 — Aggregation hubs (origin side)

**Goal.** A farmer who can't or won't run their own deliveries drops
produce at the Jiri bazaar hub. The hub holds inventory until a rider
or truck picks it up. Listings tagged "ready at hub" match faster
because pickup is from one well-known location instead of N farms
scattered across hillsides.

This is the physical asset we ask Jiri municipality for, and the
unlock for tonnage consolidation later in Phase 4.

### Schema

```sql
-- New table: a managed drop-off / pickup point.
CREATE TABLE pickup_hubs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en       text NOT NULL,
  name_ne       text NOT NULL,
  municipality_id uuid REFERENCES municipalities(id),
  address       text NOT NULL,
  location      geography(Point, 4326) NOT NULL,
  operator_id   uuid REFERENCES users(id),  -- hub manager
  hub_type      text NOT NULL CHECK (hub_type IN ('origin','destination','transit')),
  operating_hours jsonb,  -- { mon: ['06:00','18:00'], ... }
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- New table: tracks farmer drop-offs at a hub.
CREATE TABLE hub_dropoffs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hub_id        uuid NOT NULL REFERENCES pickup_hubs(id),
  farmer_id     uuid NOT NULL REFERENCES users(id),
  listing_id    uuid NOT NULL REFERENCES produce_listings(id),
  quantity_kg   numeric(10,2) NOT NULL,
  lot_code      text NOT NULL,        -- printable label for the bag/crate
  status        text NOT NULL CHECK (status IN
    ('dropped_off','in_inventory','dispatched','expired','spoiled')),
  dropped_at    timestamptz NOT NULL DEFAULT now(),
  dispatched_at timestamptz,
  expires_at    timestamptz NOT NULL,  -- spoilage horizon
  notes         text
);

-- Listing-level: which fulfilment modes are valid for this listing.
ALTER TABLE produce_listings ADD COLUMN
  pickup_mode text NOT NULL DEFAULT 'farm_pickup'
  CHECK (pickup_mode IN ('farm_pickup','hub_dropoff','both'));

-- Order-item level: was this item satisfied from a hub lot?
ALTER TABLE order_items ADD COLUMN dropoff_id uuid REFERENCES hub_dropoffs(id);
```

### RPCs

- `record_hub_dropoff_v1(p_hub_id, p_listing_id, p_quantity_kg)` —
  farmer-side. Creates a `hub_dropoffs` row, generates a printable
  `lot_code`. Enforces `farmer_id = auth.uid()`.
- `mark_dropoff_received_v1(p_dropoff_id)` — hub-operator-side. Flips
  status `dropped_off → in_inventory`.
- `dispatch_dropoff_v1(p_dropoff_id, p_rider_trip_id)` — hub-side or
  rider-side. Flips `in_inventory → dispatched`, links to a
  rider_trip.
- Update `match_order_riders` to consider hub locations as pickup
  candidates when an order's items are sourced from
  `dropoff.status IN ('in_inventory')`.

### UI surfaces

**Mobile (farmer):**
- New screen: "Drop off at hub." Pick hub from list (filtered by
  municipality), pick listing, enter quantity, get printable lot code.
- Listing edit screen: `pickup_mode` selector.

**Mobile (hub operator — new role or sub-role):**
- New screen: "Hub inventory." Lists all `dropoffs` with
  status filter. Mark received, mark spoiled, mark dispatched.
- Print/SMS lot codes.

**Web (admin):**
- Hub CRUD (create/edit/disable hubs, assign operator).

### Notifications

- Farmer: "Your dropoff at <hub> received."
- Farmer: "Your dropoff at <hub> dispatched with rider <name>."
- Farmer: "Your dropoff expires in 24h — pick up or it'll be marked
  spoiled."

### Dependencies

None on prior phases. This is fully additive.

### Exit criteria

- One real hub seeded in the Jiri municipality (the bazaar).
- A test farmer can drop off via mobile, hub operator marks it
  received, an order matching that listing pulls from the hub lot,
  and a rider trip pickup-stop resolves to the hub address (not the
  farm address).
- All three notifications fire on the right events.

### Estimate

~1 week. Mostly schema + 3 mobile screens + 1 admin CRUD.

### Risks

- **Hub operator role.** We're adding a fourth role
  (farmer/consumer/rider/hub_operator) or treating it as a special
  user_role. Decide before schema migration. Recommendation: add
  `hub_operator` to the `user_roles` enum; let it stack with other
  roles.
- **Spoilage horizon.** `expires_at` per dropoff needs a per-listing
  default (perishability). Punt to Phase 3 (quality policy) for
  per-product calibration; for Phase 1 default to 48h.

---

## Phase 2 — Subscriptions: schema stub → live product

**Goal.** A consumer subscribes to a weekly produce box. Every week,
the system rolls the subscription forward into a real order, escrows
payment, fires the matching engine, and ships. Farmer sees "what to
harvest this week" aggregated from all active subscriptions touching
their listings.

This is the predictability lever — turns lumpy on-demand traffic into
a forecastable weekly cargo plan. Pairs with Phase 1 because hubs
aggregate supply against forecastable demand.

### Schema (minimal — most tables exist)

```sql
-- Existing tables: subscription_plans, subscriptions, subscription_deliveries.
-- Add scheduling fields if missing:
ALTER TABLE subscription_deliveries ADD COLUMN IF NOT EXISTS rolled_order_id uuid REFERENCES orders(id);
ALTER TABLE subscription_deliveries ADD COLUMN IF NOT EXISTS rolled_at timestamptz;
ALTER TABLE subscription_deliveries ADD COLUMN IF NOT EXISTS skip_reason text;

-- Idempotency: one rolled order per (subscription, scheduled_date).
CREATE UNIQUE INDEX IF NOT EXISTS subscription_deliveries_subscription_date_unique
  ON subscription_deliveries (subscription_id, scheduled_date);
```

### RPCs

- `roll_subscription_to_order_v1(p_delivery_id)` — SECURITY DEFINER.
  Reads the plan items, snapshots prices from current
  `produce_listings`, calls `place_order_v1` with the consumer's
  default delivery address + payment method, links the resulting
  order back to `subscription_deliveries.rolled_order_id`. Idempotent
  on `(subscription_id, scheduled_date)`.
- `skip_next_delivery_v1(p_subscription_id, p_reason)` — consumer
  pause-one-week.
- `harvest_forecast_for_farmer_v1(p_farmer_id, p_window_days)` —
  returns aggregated quantities the farmer's listings will be drawn
  on, by date, across all active subscriptions.

### Worker / cron

- `pg_cron` job: every day at 04:00 NPT, find
  `subscription_deliveries WHERE scheduled_date = current_date AND
  status = 'scheduled'`, call `roll_subscription_to_order_v1` per
  row.
- Notification fan-out on roll: consumer "your weekly box ships
  today," farmer "harvest list updated."

### UI surfaces

**Mobile (consumer):**
- "Your subscription" screen: next delivery date, line items, skip /
  pause / cancel buttons.
- Onboarding nudge in marketplace: "subscribe and save."

**Mobile (farmer):**
- "Harvest forecast" screen: 7-day aggregated demand from
  subscriptions touching this farmer's listings.

**Web (admin):**
- Subscription health dashboard: active count, churn, failed rolls.

### Notifications

- Consumer 48h before: "Your box ships in 2 days."
- Consumer day-of: "Your box has been ordered."
- Farmer day-of: "Harvest list ready for today's subscriptions."
- Both, on insufficient inventory: "Substitution needed for X."

### Dependencies

- Phase 1 is **strongly recommended** but not required: hubs make
  weekly aggregation operationally easier. Subscriptions can ship
  without hubs against farm-pickup, but farmer side will hate it.

### Exit criteria

- A real test consumer subscribes to a weekly plan.
- The cron fires at 04:00, rolls the delivery into an order, fires
  rider matching, escrows payment.
- Farmer sees the harvest forecast in the mobile app.
- Skip/pause/cancel work end-to-end.
- Idempotency proven: running the cron twice on the same day does
  not create duplicate orders.

### Estimate

~1 week.

### Risks

- **Payment-on-roll for digital methods.** Today digital methods
  redirect to a gateway in-flow. For subscriptions we need stored
  authorization (a tokenised card / wallet handle). Nepali gateways
  vary on this. **Mitigation for v1: cash-on-delivery only for
  subscriptions, defer digital subscription billing to a follow-up.**
- **Insufficient inventory at roll time.** The plan promises 2kg of
  spinach; today the farmer has 1kg. Decide policy: substitute, hold,
  or partial-fulfil. Recommendation: partial-fulfil with consumer
  notification, allow consumer to add a note.
- **Time zones in pg_cron.** Run cron on a NPT-aware schedule — DB
  cluster is UTC, set the job's `WHERE` clause to use
  `(now() AT TIME ZONE 'Asia/Kathmandu')::date`, not `current_date`.

---

## Phase 3 — Quality policy

**Goal.** Every pickup has a photo. Every delivery has a photo. Every
order item has a quality grade. Consumers get a 24h refund window for
damaged produce with photo evidence. Farmer reputation tracks grade
performance and gates listing visibility.

This is the trust lever. Without it, every dispute is manual and
every bad delivery damages the platform's reputation
disproportionately. With it, disputes are bounded, auto-resolved
where possible, and farmer behaviour aligns with quality.

### Schema

```sql
-- Per-item photos and grading.
ALTER TABLE order_items ADD COLUMN pickup_photo_url text;
ALTER TABLE order_items ADD COLUMN delivery_photo_url text;
ALTER TABLE order_items ADD COLUMN grade text CHECK (grade IN ('A','B','C'));
ALTER TABLE order_items ADD COLUMN condition_report jsonb;

-- Disputes table.
CREATE TABLE order_disputes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL REFERENCES orders(id),
  order_item_id uuid REFERENCES order_items(id),
  reporter_id   uuid NOT NULL REFERENCES users(id),
  reason        text NOT NULL,
  evidence_photos text[] NOT NULL DEFAULT '{}',
  status        text NOT NULL DEFAULT 'open' CHECK (status IN
    ('open','auto_refunded','manual_refunded','rejected','escalated')),
  refund_amount numeric(10,2),
  resolved_at   timestamptz,
  resolved_by   uuid REFERENCES users(id),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Farmer reputation aggregate.
ALTER TABLE users ADD COLUMN grade_avg numeric(3,2);
ALTER TABLE users ADD COLUMN grade_count integer NOT NULL DEFAULT 0;
```

### RPCs

- `confirm_pickup_with_photo_v1(p_order_id, p_farmer_id, p_photo_url, p_grade, p_condition jsonb)` —
  replaces the bare `confirmFarmerPickup`. Photo + grade required.
- `confirm_delivery_with_photo_v1(p_order_id, p_photo_url)` —
  replaces bare `confirm_delivery_v1` for the rider half of delivery
  (consumer-side acceptance still calls `confirm_delivery_v1`).
- `report_damaged_item_v1(p_order_item_id, p_reason, p_photos text[])` —
  consumer-side. If within 24h of delivery and grade was A, auto-
  refund line item; otherwise opens a dispute for admin review.
- `recompute_farmer_grade_v1(p_farmer_id)` — trigger-driven; updates
  `users.grade_avg` whenever an `order_items.grade` lands.

### UI surfaces

**Mobile (rider):**
- Pickup screen: camera launches, photo required, can't proceed
  without it. Grade dropdown (A/B/C with translated descriptions).
- Delivery screen: camera launches, photo required.

**Mobile (farmer):**
- Reputation surface on profile: "Your grade: 4.6 / 5 across 23
  pickups." Listings sort lower in marketplace if grade < 3.5.

**Mobile (consumer):**
- Order detail: "Report damage" button visible for 24h post-delivery.
- Camera flow with reason picker.

**Web (admin):**
- Disputes queue. Bulk-resolve UI.

### Storage

- New Supabase Storage bucket: `quality-photos` (public read, signed
  upload with size limit). Bucket policy: rider can write to
  `pickups/{order_id}/{item_id}.jpg`; consumer can write to
  `disputes/{order_id}/{item_id}/{n}.jpg`.

### Dependencies

None hard. Easier after Phase 1 (hub operator can also grade at
intake — adds an earlier QA point) but not required.

### Exit criteria

- A rider cannot complete pickup without photo + grade.
- A rider cannot complete delivery without photo.
- A consumer can report damage within 24h and an A-graded item
  auto-refunds.
- A C-graded farmer's listings appear demoted in marketplace sort.
- Admin disputes queue works.

### Estimate

~1 week.

### Risks

- **Photo storage costs.** Estimate per-order photo footprint at ~3
  photos × 200KB = 600KB. At 1000 orders/month, ~600MB/month.
  Manageable on Supabase paid tier. Watch.
- **Offline rider scenario.** Rider in dead-zone can't upload photo.
  Mitigation: queue locally, upload on reconnect; allow status
  transition with "photo pending" flag.

---

## Phase 4 — Truck-route domain & multi-leg fulfilment

**Goal.** An order can be carried by a sequence of legs, each
performed by a different transport type (rider trip, scheduled truck
run, courier, pickup-from-hub). Specifically, a Jiri farmer's box can
go: **(leg 1)** farm → Jiri hub via local rider, **(leg 2)** Jiri hub
→ KTM hub via scheduled truck, **(leg 3)** KTM hub → consumer door
via city rider.

This is the structural change that lifts the volume ceiling and
enables Phase 5 (KTM micro-hubs).

### Schema (this is where we break things)

```sql
-- New: scheduled trucks (recurring routes between hubs).
CREATE TABLE scheduled_trucks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id    uuid NOT NULL REFERENCES users(id),
  route_name      text NOT NULL,
  origin_hub_id   uuid NOT NULL REFERENCES pickup_hubs(id),
  destination_hub_id uuid NOT NULL REFERENCES pickup_hubs(id),
  capacity_kg     numeric(10,2) NOT NULL,
  recurrence      jsonb NOT NULL,  -- { days: ['tue','fri'], depart: '04:00' }
  price_per_kg    numeric(10,2) NOT NULL,
  is_active       boolean NOT NULL DEFAULT true
);

-- New: actual scheduled / executed runs (one per recurrence firing).
CREATE TABLE truck_runs (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scheduled_truck_id  uuid NOT NULL REFERENCES scheduled_trucks(id),
  departure_at        timestamptz NOT NULL,
  status              text NOT NULL DEFAULT 'scheduled' CHECK (status IN
    ('scheduled','loading','in_transit','arrived','completed','cancelled')),
  capacity_used_kg    numeric(10,2) NOT NULL DEFAULT 0,
  route_geom          geography(LineString, 4326)
);

-- New: a fulfilment is the abstraction above an order's transport plan.
CREATE TABLE fulfilments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    uuid NOT NULL REFERENCES orders(id) UNIQUE,
  status      text NOT NULL DEFAULT 'planning' CHECK (status IN
    ('planning','in_progress','completed','failed','cancelled')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- New: each leg of the fulfilment.
CREATE TABLE fulfilment_legs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fulfilment_id   uuid NOT NULL REFERENCES fulfilments(id) ON DELETE CASCADE,
  sequence        integer NOT NULL,
  carrier_type    text NOT NULL CHECK (carrier_type IN ('rider_trip','truck_run','consumer_pickup')),
  rider_trip_id   uuid REFERENCES rider_trips(id),
  truck_run_id    uuid REFERENCES truck_runs(id),
  origin_type     text NOT NULL CHECK (origin_type IN ('farm','hub','address')),
  origin_id       uuid,
  origin_geom     geography(Point, 4326) NOT NULL,
  destination_type text NOT NULL CHECK (destination_type IN ('farm','hub','address')),
  destination_id  uuid,
  destination_geom geography(Point, 4326) NOT NULL,
  status          text NOT NULL DEFAULT 'pending',
  UNIQUE (fulfilment_id, sequence),
  CHECK (
    (carrier_type = 'rider_trip' AND rider_trip_id IS NOT NULL) OR
    (carrier_type = 'truck_run'  AND truck_run_id IS NOT NULL) OR
    (carrier_type = 'consumer_pickup')
  )
);
```

### Migration risk

`orders.rider_trip_id` is referenced across the codebase (web actions,
mobile repos, RPCs). Migration plan:

1. Add new tables alongside existing schema; do not drop
   `orders.rider_trip_id` yet.
2. Backfill: for every existing order, create a `fulfilments` row +
   single `fulfilment_legs` row referencing the existing rider trip.
3. Update read paths to prefer `fulfilments`/`fulfilment_legs` and
   fall back to `orders.rider_trip_id` if `fulfilments` row is
   missing.
4. Update write paths to write to both for one release.
5. After one release with no read-path errors, drop the fallback and
   the column.

This is a 5-step migration over multiple deploys. Plan for a 3-week
window minimum.

### RPCs

- `plan_fulfilment_v1(p_order_id)` — replaces inline matching from
  `place_order_v1`. Computes the cheapest leg sequence using
  available rider trips + scheduled truck runs. Returns the plan.
- `assign_truck_leg_v1(p_leg_id, p_truck_run_id)` — books a leg onto
  a truck run, debits capacity.
- `confirm_leg_handoff_v1(p_leg_id, p_photo_url)` — handoff at a
  hub (truck unloads, next-leg rider takes over).

### Multi-leg matching

This is the meat of the phase. Today `match_order_riders` finds one
rider whose route covers pickup + delivery. New version:

1. Group order_items by source hub (or farm).
2. For each (origin, destination) pair, find the cheapest path:
   - direct rider trip if one matches (existing behaviour);
   - else origin → hub via local rider, hub → destination_hub via
     truck_run, destination_hub → consumer via city rider.
3. Insert N `fulfilment_legs`. Match riders/trucks per leg
   independently.

### UI surfaces

**Mobile (truck operator — new role):**
- "My trucks" screen: scheduled runs, capacity used, manifest.
- Run detail: list of legs assigned, each with origin hub manifest.

**Mobile (consumer):**
- Order tracking: shows N legs, current leg highlighted.

**Web (admin):**
- Scheduled trucks CRUD.
- Truck-run dashboard.

### Dependencies

- Phase 1 hubs are **required** (trucks go hub-to-hub).
- Phase 5 needs this in place before it ships (the destination-hub
  legs require multi-leg fulfilment).

### Exit criteria

- A scheduled truck route Jiri↔KTM is live with a real operator.
- An order from a Jiri farmer to a KTM consumer is fulfilled via
  three legs (farm→hub rider, hub→hub truck, hub→home rider) and the
  consumer sees correct multi-leg tracking.
- Existing single-rider-trip orders still work end-to-end (backward
  compatibility through the migration).

### Estimate

3+ weeks. Schema migration, multi-leg matcher, truck operator UI,
backfill, dual-write, cleanup.

### Risks

- **Big surface area.** Touches matching, payouts, status
  transitions, notifications, tracking UI, admin tooling.
- **Backfill correctness.** Every existing in-flight order must
  survive the migration without status corruption.
- **Pricing model change.** Today delivery_fee is single-leg. With
  multi-leg, it's leg₁ + leg₂ + leg₃ with per-leg pricing. Consumer
  total stays the same conceptually but the breakdown gets richer.

---

## Phase 5 — KTM micro-hubs (destination side)

**Goal.** 4–5 destination hubs in KTM (Kalimati, Boudha, Jawalakhel,
Kapan, Bhaktapur). Truck runs from Phase 4 deliver to these hubs.
From each hub: (a) consumer self-pickup window, or (b) hub-to-door
city rider in a 2-hour evening slot.

This unlocks the actual KTM coverage problem.

### Schema reuse

`pickup_hubs.hub_type = 'destination'`. Most schema reused from Phase
1. New:

```sql
-- Hub-to-door rider windows (recurring).
CREATE TABLE hub_delivery_windows (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hub_id      uuid NOT NULL REFERENCES pickup_hubs(id),
  day_of_week int NOT NULL,  -- 0..6
  start_time  time NOT NULL,
  end_time    time NOT NULL,
  is_active   boolean NOT NULL DEFAULT true
);
```

### RPCs

- `assign_hub_to_door_leg_v1(p_leg_id, p_window_id, p_rider_trip_id)`.
- `claim_pickup_window_v1(p_order_id, p_window_id)` — consumer-side
  alternative to home delivery.

### UI surfaces

**Mobile (consumer):**
- Checkout: choose home delivery vs hub pickup. Hub pickup shows
  pickup window options.
- Order tracking: "Ready for pickup at <hub>" state.

**Mobile (city rider):**
- "Hub-to-door run" screen: claim a window, get manifest.

### Dependencies

- Phase 1 (hubs).
- Phase 4 (multi-leg fulfilment).

### Exit criteria

- 5 destination hubs seeded.
- A consumer can complete a hub-pickup order end-to-end.
- A city rider can claim and execute a hub-to-door delivery window.

### Estimate

~2 weeks after Phase 4 lands.

---

## Cross-phase concerns

### Roles

We're growing role count: farmer, consumer, rider, hub_operator
(Phase 1), truck_operator (Phase 4). Recommendation: extend
`user_roles.role` enum, allow stacking, and treat role-gating in RPCs
the way we already do for farmer/rider.

### Migrations strategy

Every schema change ships as a numbered Supabase migration. Phases
1–3 are additive; Phase 4 needs the dual-write window. Test
migrations against a snapshot of prod before applying.

### Notifications

Each phase adds notification categories. Add them to
`notification_preferences` defaults so consumers can opt out per
category.

### Web ↔ mobile parity

After Phase 1, every farmer-facing surface should ship on both web
and mobile. Hub operator and truck operator can be web-first
(operational role, fewer users, mobile parity later).

### Beads

Recommend filing one parent bead per phase, with subtasks per
schema migration / RPC / UI surface. Phase 1 is ready to break down
once this plan is approved.

---

## Decision points before we start Phase 1

1. **Hub operator role.** Add to `user_roles` enum or admin sub-role?
   Recommendation: add to enum.
2. **Spoilage default.** 48h dropoff TTL OK as a v1 default, or
   per-listing override?
3. **First hub.** Confirm Jiri bazaar as the seed hub, get a real
   operator account assigned.
4. **Scope cut.** Are we OK with hub_operator UI being web-only for
   v1 (mobile later), or does the operator need mobile from day one?

Once these are answered I'll file beads for Phase 1 and start
implementation.
