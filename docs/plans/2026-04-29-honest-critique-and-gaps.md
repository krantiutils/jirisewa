# JiriSewa: Honest Critique & Gap Analysis

**Date**: 2026-04-29
**Author**: emma (crew/jirisewa)
**Status**: strategy + engineering follow-ups
**Audience**: founder / overseer

This is the document the overseer asked for after a long live demo session
on a real Android device. It captures (1) a candid critique of the current
product model — is this a one-time gimmick or something that actually solves
the Jiri-to-KTM produce problem? — and (2) the engineering gaps that are
still open after this session.

The tone is deliberately blunt. The goal is to surface what would break in
the next 6–12 months if we kept building on the current foundation, and to
name what has to be built to make the model defensible.

---

## 1. What we have today (as of 2026-04-29)

A working farmer-to-consumer marketplace with three roles, end-to-end on
both web (Next.js) and mobile (Flutter). After this session's work, the
mobile app exercises the same database side-effects as the web app — order
placement, rider matching, farmer notifications, status-change
notifications, cancel, and confirm-delivery — all routed through SECURITY
DEFINER RPCs in Postgres rather than client-side fan-out.

The fulfilment model is **rider-as-bus-passenger**: a rider declares a trip
(origin → destination, departure time, available capacity in kg). The
matching engine (`find_eligible_riders` + `match_order_riders`) finds
trips whose route passes near the pickup farmer(s) and the delivery
address, within a configurable detour budget. Eligible riders get a ping
notification (5-minute expiry); first-accept wins. Once a rider accepts,
the order becomes `matched`, payouts are escrowed (for digital payments),
and the rider executes pickups + delivery in trip-stop order.

This is a real product. It works. We placed a real order on a real device
during this session, watched the DB cascade fire correctly, and saw the
rider-side ping appear after we patched an EWKB hex parser bug. **The
plumbing is sound.**

But the plumbing is not the business. The business is whether this model
can carry the weight of (a) ton-scale farmers, (b) KTM last-mile, (c) a
Kalimati-grade wholesale relationship, and (d) a defensible pitch to the
Jiri municipality. On those four questions, the current model has real
ceilings — most of which we have not yet built around.

---

## 2. The honest critique

### 2.1 The volume ceiling

**The bus-passenger model carries 5–50 kg, not 500–2000 kg.**

Today a rider trip declares `available_capacity_kg`. In practice this is
whatever fits in a backpack, a saddlebag, or a small trunk. That's fine
for a household selling tomatoes from a kitchen garden. It is not fine for:

- a farmer with 1+ ton of seasonal harvest needing to move it before it
  rots;
- a Kalimati vendor who buys by the truckload and won't even pick up the
  phone for less than 200 kg;
- the Jiri-side aggregator who wants to consolidate output from 30
  households into a single weekly truck.

A bus carrying 30 small parcels is a microcosm — not a supply chain. To
move tonnage, we need a **scheduled-truck domain** alongside rider trips:
a recurring route (Jiri → KTM, departs Tuesday 4am), a contracted
operator, capacity in the hundreds of kg, and order matching that
consolidates many farmer outputs into one truck cargo. `rider_trips`
should not be the only fulfilment type — it should be one of several
(rider, bus, scheduled truck, on-demand truck).

**Without this, we are a hobbyist matchmaker with a cap on monthly GMV.**

### 2.2 The quality ceiling (cold chain)

**Mountain produce in transit for 6–8 hours without refrigeration arrives
wilted.** The Jiri → KTM corridor is not short. By the time a rider's bag
hits a Bhaktapur kitchen, leafy greens have lost a meaningful fraction of
their value. Tomatoes bruise. Strawberries are a write-off.

We have no concept of cold chain in the schema, no insulated-box program,
no farmer-side grading or pre-cooling guidance, and no quality-grade tag
on listings. Customers will form an opinion about "Jiri produce quality"
based on what arrives at their door — and right now the system makes no
distinction between produce that traveled in a chilled box and produce
that traveled in a hot pannier.

**If the first 200 customers' second order doesn't happen, this is why.**

### 2.3 The predictability ceiling (subscription is a stub)

The on-demand "browse and buy fresh produce now" UX is the flashiest
thing in the app, but it is also the worst possible match for the
underlying supply. Farmers don't have inventory on a shelf — they have a
field that produces when it produces. Consumers don't want to think about
groceries every other day — they want a box to show up.

The `subscription_plans` / `subscriptions` / `subscription_deliveries`
tables exist. The farmer-facing UX to create plans exists. The
consumer-facing UX to subscribe exists. **What does not exist** is the
scheduled-delivery worker: nothing on prod actually fires the recurring
order on the delivery date, nothing rolls a `subscription_deliveries` row
into an `orders` row, nothing notifies the consumer "your weekly box ships
tomorrow." This is a web-only cron stub at best, and not running on prod.

Subscriptions are the way to smooth lumpy supply, lock in revenue, and
plan trucks 7+ days in advance. **Right now they are a marketing claim, not
a product surface.**

### 2.4 The KTM last-mile gap

Even if we solve Jiri-side aggregation and get a truck to KTM, we then
have to deliver to Bhaktapur, Boudha, Lalitpur, Kapan. That is its own
dispatch problem and the current design has no answer for it. Today the
same rider who picks up in Jiri also delivers in KTM — which is fine
when the trip is one-passenger-with-a-bag and falls apart the moment the
truck unloads 800 kg at a hub.

What we need: **micro-hubs** in 4–5 KTM neighbourhoods (Kalimati, Boudha,
Jawalakhel, Kapan, Bhaktapur). Truck unloads at hubs. From each hub
either (a) consumer pickup window, or (b) hub-to-door rider in a 2-hour
evening slot. This is a different `fulfilment_leg` model from
"rider_trip carries the order end-to-end." Schema does not support it.

### 2.5 The B2B unlock is built but not executed

`business_profiles` and `bulk_orders` exist. The intent is right: a
restaurant, hotel, or canteen can place a bulk order; farmers quote per
line; business accepts. **But there is no Kalimati vendor onboarding.**
The B2B flow is built for KTM end-buyers (restaurants); it is not built
for the wholesale market that would actually anchor truck cargo.

A standing weekly order from one Kalimati vendor for 200 kg of mixed
greens is worth more to the model than 200 individual consumer orders.
That relationship needs:

- a "wholesale buyer" role distinct from `business_profiles`;
- standing-order semantics (recurring bulk orders);
- price negotiation outside the consumer marketplace (private quotes);
- a settlement model that doesn't escrow per-delivery (line of credit /
  weekly settlement).

None of this exists today. The closest analog (subscriptions) is for
consumers, not wholesale.

### 2.6 The trust gap (quality + spoilage policy)

There is no:

- pickup photo requirement;
- delivery photo requirement;
- per-line-item quality grade;
- automatic refund window for "produce arrived damaged";
- farmer reputation surface (rating exists; consequence does not).

In Nepal, where trust in fresh-produce supply chains is already low and
where spoilage disputes will be common, **this gap will manifest as
disputes within 8 weeks of any real volume**. Right now `orders.status`
includes a `disputed` value but the dispute flow is bare metal. Disputes
that pile up unresolved kill the platform's reputation faster than any
single bad order.

### 2.7 The pitch-to-Jiri framing

The overseer asked: how do we pitch to Jiri municipality?

**Don't pitch logistics. They can't run KTM and they know it.**

Pitch them the thing they actually need from us:

1. **Rural economic data infrastructure.** Monthly tonnage by crop, by
   ward, by farmer cohort. Price-realisation data ("Jiri farmers
   averaged ₹X/kg vs Kalimati spot ₹Y/kg"). Crop-diversification reports.
   This is the kind of data a municipality wants for its own
   five-year-plan reporting.

2. **Farmer welfare metrics.** % of farmers with at least one sale per
   month, average revenue per farmer-household, count of farmers
   onboarded, count of unverified-to-verified transitions. These are
   numbers a municipal officer can put in a deck.

3. **"Jiri-grown" certification** — a brand the municipality lends to,
   we operate underneath. We do the QA; they do the endorsement. This
   is a no-cost asset for them and a marketing moat for us.

4. **Specific asks they can grant:**
   - a physical aggregation point at the Jiri bazaar (a roofed area,
     not infrastructure they have to build);
   - a public endorsement / signed agreement;
   - optional: a 3-month subsidy on truck fuel to bootstrap the route.

Do **not** ask them to "regulate KTM logistics." Do **not** ask them to
"build infrastructure." Both are outside their authority.

---

## 3. The defensible build order

If we accept the critique above, the prioritised next-build list is:

1. **Aggregation hubs (origin side).** Add a `pickup_hubs` table
   (Jiri bazaar = first row). Farmer can drop produce at a hub instead
   of waiting for a per-order rider pickup. Hub batches and tags
   produce for the next outbound truck. This unlocks (a) farmers
   without delivery capability, (b) tonnage consolidation, (c) the
   physical asset we ask Jiri municipality for.

2. **Weekly-box subscription UX.** The schema exists; ship the worker
   that actually rolls subscription_deliveries → orders, ship the
   consumer-facing "your next box" surface, ship the farmer-facing
   "what to harvest this week" surface. Subscriptions de-risk supply
   planning more than any other feature.

3. **Kalimati vendor onboarding.** A single signed wholesale buyer
   anchors weekly truck cargo. Schema work: distinguish wholesale
   buyer from consumer business profile; standing orders; weekly
   settlement instead of per-order escrow.

4. **Quality grading + dispute policy.** Pickup photo required.
   Delivery photo required. Per-line-item grade (A/B/C). 24-hour
   "report damaged" window with auto-refund. Farmer reputation that
   actually gates listing visibility.

5. **Truck-route domain model.** New `scheduled_trucks` (route,
   capacity, recurring schedule) decoupled from `rider_trips`. New
   `fulfilment_legs` so an order can be (truck Jiri→KTM hub) + (rider
   hub→home). Order matching becomes multi-leg.

6. **KTM micro-hubs (destination side).** 4–5 hubs. Hub-to-door
   evening rider window, or self-pickup. This requires (5) to be in
   place first.

The existing rider-trip matchmaker becomes the **micro-route
fallback** for tiny farmers (1–10 kg), not the primary fulfilment
type. That is a healthy demotion: it stays valuable, but it stops
being the ceiling.

---

## 4. Engineering gaps still open (post-session)

This section is the technical-debt counterpart to the strategic
critique. These are the things we noticed during the session that
should land as beads.

### 4.1 FCM dispatch: plumbed, not lit

- `apps/web/src/app/api/notifications/dispatch/route.ts` is committed
  locally; the **prod web image does not contain it yet**. Trigger
  fires, hits a 404, no push goes out.
- `FIREBASE_SERVICE_ACCOUNT_BASE64` is **not set on prod web container**.
  Even after redeploy, `isFcmConfigured()` returns false and the
  endpoint no-ops.
- Action: redeploy web image, set the env var, smoke-test by inserting
  a row into `notifications` and checking `pg_net._http_response`.

### 4.2 Subscription scheduled-delivery worker

- Schema exists (`subscription_deliveries`).
- Web-only cron stub at best; nothing runs on prod.
- Should be ported to a DB function (`pg_cron`) or a dedicated worker
  with idempotency on `(subscription_id, scheduled_date)`.
- Without this, subscriptions are a marketing claim only (see §2.3).

### 4.3 Build-time `--dart-define` footgun

- `apps/mobile/lib/main.dart` defaults `SUPABASE_URL` to
  `http://localhost:54321` and `SUPABASE_ANON_KEY` to a demo issuer.
- Building with `--dart-define=SUPABASE_ANON_KEY=""` (empty value)
  **bypasses the default** because `String.fromEnvironment` returns
  the explicitly-set empty string.
- We hit this once already in this session ("No API key found in
  request"). Add a build-time assertion or a non-empty check before
  bootstrapping Supabase.

### 4.4 `docker-compose.prod.yml` auth service has no `env_file`

- Naive `docker compose up -d auth` evaluates env vars empty and
  crashloops the container on missing JWT_SECRET.
- We had to use the explicit `--env-file .env.docker` flag.
- Fix: add `env_file: .env.docker` to the auth service in
  `compose.prod.yml`.

### 4.5 EWKB hex parsing was missing in two places

- `apps/mobile/lib/features/orders/repositories/available_orders_repository.dart`
  and `apps/mobile/lib/features/trips/repositories/trip_repository.dart`
  only handled WKT (`POINT(lng lat)`) and silently returned `null` for
  the EWKB hex format Supabase actually returns for `geography`
  columns (`0101000020E6100000<lng-LE><lat-LE>`).
- Fixed in this session in both files (uncommitted at time of
  writing — see §5).
- Worth grepping the codebase for other `_parsePoint` / `parsePoint`
  implementations and unifying on a shared util in `packages/shared`
  (or its Dart equivalent in the mobile app) to prevent the next
  occurrence.

### 4.6 `earnings` FK constraint complicates test cleanup

- `trg_create_earnings_on_delivery` inserts an `earnings` row when an
  order flips to `delivered`.
- Deleting orders for test fixture reset requires deleting
  `earnings` first; not a bug, but a footgun any test author will
  hit on day one.
- Action: write a `delete_test_order(uuid)` helper that handles the
  cascade.

### 4.7 Demo IDs still hardcoded in some web actions

- Several `lib/actions/*.ts` files still use `DEMO_CONSUMER_ID` /
  `DEMO_RIDER_ID` / `DEMO_FARMER_ID` constants.
- Auth migration was started but not finished.
- Action: audit and replace with `auth.uid()` equivalents; the
  mobile app already routes through SECURITY DEFINER RPCs that
  enforce `consumer_id = auth.uid()`, so this is a web-side gap only.

### 4.8 `find_eligible_riders` was silently broken for the web path

- We patched it during this session: cast detour to numeric, widen
  trip status filter to `('scheduled','in_transit')`.
- Worth a regression test that exercises both statuses and asserts
  the function returns the expected number of rows.

### 4.9 No regression coverage for the place-order RPC chain

- `place_order_v1` → `match_order_riders` → ping insert →
  `notify_rider_ping` → `dispatch_notification_push` is now the
  load-bearing chain for every order placed by every client.
- Zero tests cover it end-to-end on prod or staging.
- Action: a pgTAP or seed-fixture-based integration test that places
  a known order and asserts (a) order row, (b) order_items rows,
  (c) at least one ping for the seeded rider, (d) at least one
  notification for the seeded farmer.

### 4.10 No quality / spoilage policy in code (ties to §2.6)

This is the single highest-leverage *engineering* gap in the
strategic-critique sense: until pickup photo, delivery photo,
per-item grade, and refund window exist, every dispute is manual
admin work and every bad delivery is unbounded reputational damage.

---

## 5. Uncommitted changes from this session

At the time of writing, the working tree on `flutter-riverpod-buildout`
contains:

- `apps/mobile/lib/features/orders/repositories/available_orders_repository.dart`
  — added EWKB hex parsing.
- `apps/mobile/lib/features/trips/repositories/trip_repository.dart`
  — added EWKB hex parsing (same parser, second site).
- `apps/mobile/lib/main.dart` — minor bootstrap edit.
- This document.

These should land as a single commit on `flutter-riverpod-buildout`
with a message describing the EWKB fix and pointing at this doc for
the broader gap analysis.

---

## 6. Bottom line

The plumbing is good. The model is incomplete.

In its current shape JiriSewa is a working **proof that the rails
exist**: a consumer can browse, a farmer can list, a rider can match,
payments escrow, notifications fire. That is genuinely hard and it is
done.

But the model — rider-as-bus-passenger, on-demand fresh-to-home,
consumer-marketplace-first — has built-in ceilings on volume,
quality, predictability, and last-mile coverage. It cannot, as
designed, carry a ton of harvest from a Jiri farmer to a Kalimati
vendor by Tuesday morning. It cannot, as designed, deliver
unbruised strawberries to Bhaktapur. It cannot, as designed, give
the Jiri municipality the report it needs for its five-year plan.

What we have is a defensible **starting micro-route**. What we need
to build, in order, is: aggregation hubs → subscription UX →
wholesale anchor → quality policy → truck-route domain → KTM
micro-hubs. The rider-passenger model survives this evolution as a
useful fallback, not as the ceiling.

The pitch to Jiri is data + welfare metrics + certification +
physical aggregation point — not logistics. They cannot run KTM
logistics. We can.
