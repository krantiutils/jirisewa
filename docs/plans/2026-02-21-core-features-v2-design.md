# Core Features V2 Design

Five features to close the biggest gaps in JiriSewa's user experience, built in dependency order.

## Build Order

1. Saved Addresses (foundation for checkout + ETAs)
2. Delivery ETAs (uses addresses + existing PostGIS data)
3. Payout System — manual (earnings tracking + admin settlement)
4. Live Rider Tracking (real-time map on order detail)
5. Push Notifications — FCM + Supabase (alerts for all events)

---

## 1. Saved Addresses

### Problem
Customers must pick a location on the map every checkout. No "Home", "Office", or recently used addresses.

### Database

New table `user_addresses`:
```sql
CREATE TABLE user_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,            -- "Home", "Office", or custom
  address_text TEXT NOT NULL,     -- human-readable address
  location GEOGRAPHY(Point, 4326) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Only one default per user
CREATE UNIQUE INDEX user_addresses_default_idx
  ON user_addresses (user_id) WHERE is_default = true;
```

RLS: users can only CRUD their own addresses.

### Server Actions (`lib/actions/addresses.ts`)
- `listAddresses()` — returns all for current user, default first
- `createAddress({ label, addressText, lat, lng, isDefault })` — upserts default if needed
- `updateAddress(id, { label, addressText, lat, lng, isDefault })`
- `deleteAddress(id)`
- `setDefaultAddress(id)` — unsets previous default, sets new one

### UI Changes

**Checkout page** (`checkout/page.tsx`):
- Above the map picker, show a dropdown/chip list of saved addresses
- Selecting one auto-fills `deliveryLocation` + `deliveryAddress`, triggers fee calculation
- "Save this address" checkbox appears after picking a new location on the map
- If user has a default address, pre-select it on page load

**New page** (`/settings/addresses`):
- List all saved addresses with edit/delete
- Add new address (opens LocationPicker)
- Set default toggle
- Link from user menu dropdown

**LocationPicker component**:
- Add "Saved addresses" section above the map when addresses exist
- Quick-select chips for saved locations

---

## 2. Delivery ETAs

### Problem
No delivery time estimates anywhere — marketplace cards, checkout, or order tracking.

### Approach

Calculate ETAs using PostGIS distance + configurable speed assumptions:
- Average speed: 30 km/h (Kathmandu valley default)
- Pickup buffer: 15 minutes (farmer preparation time)
- Formula: `ETA = pickup_buffer + (distance_km / avg_speed_kmh * 60)`

For active orders with a rider in transit, use rider's last known location instead of farmer location.

### Database

New RPC function:
```sql
CREATE OR REPLACE FUNCTION estimate_delivery_minutes(
  p_farmer_location GEOGRAPHY,
  p_delivery_location GEOGRAPHY,
  p_avg_speed_kmh NUMERIC DEFAULT 30,
  p_pickup_buffer_min INTEGER DEFAULT 15
) RETURNS INTEGER AS $$
  SELECT p_pickup_buffer_min + CEIL(
    ST_Distance(p_farmer_location, p_delivery_location) / 1000.0
    / p_avg_speed_kmh * 60
  )::INTEGER;
$$ LANGUAGE SQL STABLE;
```

### Server Actions
- `getDeliveryETA(listingId, deliveryLat, deliveryLng)` — returns estimated minutes for a single listing
- `getBatchDeliveryETAs(listingIds, deliveryLat, deliveryLng)` — batch version for marketplace page
- `getActiveOrderETA(orderId)` — uses rider's latest location from `rider_location_logs`

### UI Changes

**ProduceCard** (`marketplace/ProduceCard.tsx`):
- Show "~X min" badge when user has a default address set
- Gray out if no address (show "Set location for ETA")

**Checkout page**:
- Show "Estimated delivery: ~X min" below the delivery fee section

**Order detail page** (when `in_transit`):
- Show "Arriving by HH:MM" with countdown
- Recalculate every 30 seconds using rider's latest position

---

## 3. Payout System (Manual)

### Problem
Farmers sell produce and riders deliver orders, but there's no way to track or withdraw earnings. Money flows in via payments but never flows out.

### Database

```sql
-- Per-order earnings for farmers and riders
CREATE TABLE earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL CHECK (role IN ('farmer', 'rider')),
  order_id UUID NOT NULL REFERENCES orders(id),
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'settled', 'disputed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at TIMESTAMPTZ,
  settled_by UUID REFERENCES auth.users(id)
);

CREATE INDEX earnings_user_idx ON earnings (user_id, status);
CREATE UNIQUE INDEX earnings_order_role_idx ON earnings (order_id, user_id, role);

-- Withdrawal requests
CREATE TABLE payout_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  method TEXT NOT NULL CHECK (method IN ('esewa', 'khalti', 'bank')),
  account_details JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'rejected')),
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  processed_by UUID REFERENCES auth.users(id)
);

CREATE INDEX payout_requests_user_idx ON payout_requests (user_id, status);
CREATE INDEX payout_requests_status_idx ON payout_requests (status, created_at);
```

### Auto-create earnings

Database trigger on `orders` table: when `status` changes to `delivered`:
- Create farmer earnings: sum of `order_items.subtotal` for each farmer in the order
- Create rider earnings: `orders.delivery_fee`

```sql
CREATE OR REPLACE FUNCTION create_earnings_on_delivery()
RETURNS TRIGGER SECURITY DEFINER AS $$
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    -- Farmer earnings (per farmer in order)
    INSERT INTO earnings (user_id, role, order_id, amount)
    SELECT oi.farmer_id, 'farmer', NEW.id, SUM(oi.subtotal)
    FROM order_items oi WHERE oi.order_id = NEW.id
    GROUP BY oi.farmer_id
    ON CONFLICT (order_id, user_id, role) DO NOTHING;

    -- Rider earnings
    IF NEW.rider_id IS NOT NULL AND NEW.delivery_fee > 0 THEN
      INSERT INTO earnings (user_id, role, order_id, amount)
      VALUES (NEW.rider_id, 'rider', NEW.id, NEW.delivery_fee)
      ON CONFLICT (order_id, user_id, role) DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_create_earnings
  AFTER UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION create_earnings_on_delivery();
```

### Server Actions (`lib/actions/earnings.ts`)
- `getEarningsSummary()` — returns `{ totalEarned, pendingBalance, settledBalance, totalWithdrawn }`
- `listEarnings(page, status?)` — paginated earnings list
- `requestPayout({ amount, method, accountDetails })` — creates payout request (validates amount <= pending balance)

### Admin Actions (`lib/actions/admin/payouts.ts`)
- `listPayoutRequests(status?)` — all pending/processing requests
- `processPayoutRequest(id, { status, adminNotes })` — approve/reject with notes
- When completed: mark corresponding earnings as `settled`

### UI Changes

**Farmer dashboard** — new "Earnings" card:
- Total earned, pending balance, withdrawn
- "Request Payout" button
- Link to earnings detail page

**Rider dashboard** — same earnings card

**New page** (`/farmer/earnings` and `/rider/earnings`):
- Earnings summary at top
- List of all earnings per order (amount, date, status)
- "Request Payout" button opens modal with amount input + payment method selector + account details

**New admin page** (`/admin/payouts`):
- Table of payout requests with filters (pending/processing/completed/rejected)
- Click to review: user details, earnings history, payout amount
- Approve/reject buttons with notes field

---

## 4. Live Rider Tracking

### Problem
Customer sees "In Transit" but has no idea where the rider is or when they'll arrive.

### Approach

Use `navigator.geolocation.watchPosition` on the rider's device during active trips. Log positions to `rider_location_logs`. Customer subscribes to real-time updates via Supabase Realtime.

### Rider Side (GPS Logging)

**New hook** (`lib/hooks/useRiderTracking.ts`):
```ts
function useRiderTracking(tripId: string, active: boolean) {
  // When active=true:
  // 1. Start watchPosition (high accuracy, 10s interval)
  // 2. Batch and send positions via logRiderLocation() every 10s
  // 3. Clean up on unmount or active=false
}
```

**Server action** (`lib/actions/rider-tracking.ts`):
- `logRiderLocation(tripId, lat, lng, speed?)` — insert into `rider_location_logs`
- `getLatestRiderLocation(tripId)` — returns most recent position

**Trip detail page** (`rider/trips/[id]/page.tsx`):
- When trip status is `in_transit`, activate `useRiderTracking` hook
- Show "Location sharing active" indicator

### Customer Side (Live Map)

**New component** (`components/orders/LiveTrackingMap.tsx`):
- Leaflet map showing:
  - Rider position (blue pulsing dot, updates in real-time)
  - Delivery destination (red pin)
  - Straight-line or route between them
  - Distance + ETA text overlay
- Uses Supabase Realtime subscription to `rider_location_logs` filtered by `trip_id`

**Order detail page** (`orders/[id]/page.tsx`):
- When order is `in_transit` or `picked_up` and has `rider_trip_id`:
  - Replace the existing static `RiderTrackingSection` with `LiveTrackingMap`
  - Show "Rider is X km away — arriving in ~Y min"

### Supabase Realtime

Enable realtime on `rider_location_logs` table:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE rider_location_logs;
```

RLS policy: customers can read location logs for trips linked to their orders.

---

## 5. Push Notifications (FCM + Supabase)

### Problem
Users must open the app to check status. No alerts for "order matched", "rider picking up", "delivered", etc.

### Approach

- **Web Push** via Firebase Cloud Messaging (FCM) with VAPID keys
- **Service Worker** for background notification display
- **Supabase Database Triggers** fire on status changes, call a Supabase Edge Function that sends FCM pushes to relevant users
- Respect existing `notification_preferences` table

### Database

```sql
CREATE TABLE push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_info JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, fcm_token)
);
```

### Firebase Setup
- Create Firebase project (or reuse if one exists)
- Generate VAPID key pair for web push
- Store `FIREBASE_*` env vars in `.env.local` and Supabase secrets

### Service Worker (`public/firebase-messaging-sw.js`)
- Handles background push display (title, body, icon, click URL)
- Registers with FCM on page load

### Client Integration

**New hook** (`lib/hooks/usePushNotifications.ts`):
```ts
function usePushNotifications() {
  // 1. Check if browser supports push
  // 2. Request notification permission (non-intrusive banner, not on first load)
  // 3. Get FCM token
  // 4. Save token via registerPushToken() server action
  // 5. Listen for foreground messages, show toast
}
```

**Permission prompt**:
- Show after first successful order (not on login — too aggressive)
- Dismissible banner: "Get delivery updates? Enable notifications"
- Store dismissal in localStorage to avoid repeat asks

### Server Actions (`lib/actions/push.ts`)
- `registerPushToken(fcmToken, deviceInfo)` — upsert push subscription
- `unregisterPushToken(fcmToken)` — remove on logout

### Supabase Edge Function (`supabase/functions/send-push/`)

Triggered by database webhooks on `orders` status changes:

| Event | Recipients | Message |
|-------|-----------|---------|
| Order `pending` → `matched` | Customer | "Your order has been matched with a rider!" |
| Order `matched` → `picked_up` | Customer | "Your produce has been picked up by the rider" |
| Order `picked_up` → `in_transit` | Customer | "Your order is on its way!" |
| Order `in_transit` → `delivered` | Customer | "Your order has been delivered" |
| New order created | Farmer(s) | "New order: X kg of [produce]" |
| Rider arriving for pickup | Farmer | "Rider arriving for pickup" |
| New order matches route | Rider | "New delivery opportunity on your route" |
| Payout completed | Farmer/Rider | "Payout of NPR X has been sent" |

Edge function:
1. Receives webhook payload (old row, new row)
2. Determines notification type and recipients
3. Checks `notification_preferences` for each recipient
4. Fetches `push_subscriptions` for allowed recipients
5. Sends FCM push via Firebase Admin SDK

### Notification Preferences Integration
- Wire existing `notification_preferences` toggles to actually filter push sends
- Add new preference categories for payout notifications

---

## Migration Order

```
20260221000001_user_addresses.sql
20260221000002_delivery_eta_function.sql
20260221000003_earnings_and_payouts.sql
20260221000004_push_subscriptions.sql
20260221000005_rider_location_realtime.sql
```

## Files Summary

| Area | New Files | Modified Files |
|------|-----------|----------------|
| Saved Addresses | migration, `actions/addresses.ts`, `settings/addresses/page.tsx` | `checkout/page.tsx`, `LocationPicker.tsx`, Header menu |
| Delivery ETAs | migration (RPC), `actions/delivery-eta.ts` additions | `ProduceCard.tsx`, `checkout/page.tsx`, `orders/[id]/page.tsx` |
| Payouts | migration, `actions/earnings.ts`, `actions/admin/payouts.ts`, `farmer/earnings/page.tsx`, `rider/earnings/page.tsx`, `admin/payouts/page.tsx` | Farmer dashboard, rider dashboard |
| Live Tracking | migration (realtime), `hooks/useRiderTracking.ts`, `actions/rider-tracking.ts`, `components/orders/LiveTrackingMap.tsx` | `rider/trips/[id]/page.tsx`, `orders/[id]/page.tsx` |
| Push Notifications | migration, `hooks/usePushNotifications.ts`, `actions/push.ts`, `public/firebase-messaging-sw.js`, `supabase/functions/send-push/` | AuthProvider or layout (init FCM), notification preferences page |
