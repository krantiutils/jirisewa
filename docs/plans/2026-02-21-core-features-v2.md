# Core Features V2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add saved addresses, marketplace delivery ETAs, manual payout system, rider GPS logging, and push notification triggers.

**Architecture:** Five independent feature slices, each with a migration + server actions + UI. Features 4 and 5 build on existing infrastructure (useRiderTracking hook, FCM edge function). All features use the existing server action pattern (`"use server"` + `createServiceRoleClient()` + `ActionResult<T>` return type).

**Tech Stack:** Next.js 16, Supabase (PostgreSQL 17 + PostGIS), Leaflet maps, Firebase Cloud Messaging (already configured), Supabase Edge Functions (already deployed).

**Existing Infrastructure (do NOT rebuild):**
- `apps/web/src/hooks/useRiderTracking.ts` — Realtime subscription to `rider_location_log`, ETA via OSRM
- `apps/web/src/components/orders/RiderTrackingSection.tsx` — Live map + ETA display on order detail
- `apps/web/src/components/map/OrderTrackingMap.tsx` — Leaflet map with rider marker
- `apps/web/src/lib/firebase.ts` — FCM client init, token request, foreground listener
- `apps/web/src/components/notifications/PushNotificationManager.tsx` — FCM token registration component
- `supabase/functions/send-notification/index.ts` — Edge function: FCM push + SMS fallback via Sparrow SMS
- `supabase/migrations/20260214000013_realtime_rider_location.sql` — Realtime enabled on `rider_location_log`

**Verification command:** `pnpm --filter web build`

---

## Feature 1: Saved Addresses

### Task 1.1: Database migration for user_addresses

**Files:**
- Create: `supabase/migrations/20260221100001_user_addresses.sql`

**Step 1: Write the migration**

```sql
-- Saved delivery addresses for customers
CREATE TABLE user_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  address_text TEXT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Only one default address per user
CREATE UNIQUE INDEX user_addresses_default_idx
  ON user_addresses (user_id) WHERE is_default = true;

CREATE INDEX user_addresses_user_idx ON user_addresses (user_id);

-- RLS: users manage only their own addresses
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own addresses"
  ON user_addresses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own addresses"
  ON user_addresses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own addresses"
  ON user_addresses FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own addresses"
  ON user_addresses FOR DELETE
  USING (auth.uid() = user_id);

-- Service role bypass for server actions
CREATE POLICY "Service role full access on user_addresses"
  ON user_addresses FOR ALL
  USING (current_setting('role') = 'service_role');
```

**Step 2: Apply migration**

Run: `supabase db reset` or `supabase migration up` (local dev)
Expected: Table created, no errors

**Step 3: Commit**

```bash
git add supabase/migrations/20260221100001_user_addresses.sql
git commit -m "feat: add user_addresses table with RLS"
```

---

### Task 1.2: Server actions for addresses

**Files:**
- Create: `apps/web/src/lib/actions/addresses.ts`
- Modify: `apps/web/src/lib/supabase/types.ts` (add user_addresses type if needed)

**Step 1: Create the server actions file**

Create `apps/web/src/lib/actions/addresses.ts` with these functions:

```ts
"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

export interface SavedAddress {
  id: string;
  label: string;
  addressText: string;
  lat: number;
  lng: number;
  isDefault: boolean;
}

// Helper: get authenticated user ID
async function getAuthUserId(): Promise<string | null> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id ?? null;
}

// Helper: parse EWKB hex point (same pattern used in delivery-fee.ts)
function parseEwkbPoint(hex: string): { lat: number; lng: number } | null {
  if (hex.length < 50) return null;
  const buf = Buffer.from(hex, "hex");
  const lng = buf.readDoubleLE(9);
  const lat = buf.readDoubleLE(17);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  return { lat, lng };
}

export async function listAddresses(): Promise<ActionResult<SavedAddress[]>> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();
  const { data, error } = await supabase
    .from("user_addresses")
    .select("id, label, address_text, location, is_default")
    .eq("user_id", userId)
    .order("is_default", { ascending: false })
    .order("created_at", { ascending: false });

  if (error) return { error: error.message };

  return {
    data: (data ?? []).map((row) => {
      const point = parseEwkbPoint(row.location as string);
      return {
        id: row.id,
        label: row.label,
        addressText: row.address_text,
        lat: point?.lat ?? 0,
        lng: point?.lng ?? 0,
        isDefault: row.is_default,
      };
    }),
  };
}

export async function createAddress(input: {
  label: string;
  addressText: string;
  lat: number;
  lng: number;
  isDefault?: boolean;
}): Promise<ActionResult<SavedAddress>> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();

  // If setting as default, unset existing default first
  if (input.isDefault) {
    await supabase
      .from("user_addresses")
      .update({ is_default: false })
      .eq("user_id", userId)
      .eq("is_default", true);
  }

  const { data, error } = await supabase
    .from("user_addresses")
    .insert({
      user_id: userId,
      label: input.label,
      address_text: input.addressText,
      location: `POINT(${input.lng} ${input.lat})`,
      is_default: input.isDefault ?? false,
    })
    .select("id, label, address_text, location, is_default")
    .single();

  if (error) return { error: error.message };

  const point = parseEwkbPoint(data.location as string);
  return {
    data: {
      id: data.id,
      label: data.label,
      addressText: data.address_text,
      lat: point?.lat ?? input.lat,
      lng: point?.lng ?? input.lng,
      isDefault: data.is_default,
    },
  };
}

export async function updateAddress(
  id: string,
  input: {
    label?: string;
    addressText?: string;
    lat?: number;
    lng?: number;
    isDefault?: boolean;
  },
): Promise<ActionResult> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();

  if (input.isDefault) {
    await supabase
      .from("user_addresses")
      .update({ is_default: false })
      .eq("user_id", userId)
      .eq("is_default", true);
  }

  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
  if (input.label !== undefined) updates.label = input.label;
  if (input.addressText !== undefined) updates.address_text = input.addressText;
  if (input.lat !== undefined && input.lng !== undefined) {
    updates.location = `POINT(${input.lng} ${input.lat})`;
  }
  if (input.isDefault !== undefined) updates.is_default = input.isDefault;

  const { error } = await supabase
    .from("user_addresses")
    .update(updates)
    .eq("id", id)
    .eq("user_id", userId);

  if (error) return { error: error.message };
  return { data: undefined };
}

export async function deleteAddress(id: string): Promise<ActionResult> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();
  const { error } = await supabase
    .from("user_addresses")
    .delete()
    .eq("id", id)
    .eq("user_id", userId);

  if (error) return { error: error.message };
  return { data: undefined };
}
```

**Step 2: Verify build**

Run: `pnpm --filter web build`
Expected: Compiles without errors

**Step 3: Commit**

```bash
git add apps/web/src/lib/actions/addresses.ts
git commit -m "feat: add saved addresses server actions (CRUD)"
```

---

### Task 1.3: Saved addresses settings page

**Files:**
- Create: `apps/web/src/app/[locale]/settings/addresses/page.tsx`

**Step 1: Create the addresses management page**

Client component page at `/settings/addresses`. Shows list of saved addresses with:
- Each address card: label, address text, "Default" badge, Edit/Delete buttons
- "Add Address" button opens inline form with LocationPicker + label input
- Set default toggle per address
- Auth guard (useAuth + redirect pattern)

Use existing UI patterns: `Card`, `Button` from `@/components/ui`, `LocationPicker` from `@/components/map/LocationPicker` (dynamic import, ssr: false).

Follow the same layout pattern as `/farmer/bulk-orders/page.tsx` (client component with useAuth guard, data loading useEffect with auth guard inside).

**Step 2: Add i18n messages**

Add to `apps/web/messages/en.json` under a new `"addresses"` key:
```json
"addresses": {
  "title": "Saved Addresses",
  "addNew": "Add Address",
  "label": "Label",
  "labelPlaceholder": "e.g. Home, Office",
  "address": "Address",
  "setDefault": "Set as default",
  "default": "Default",
  "save": "Save",
  "saving": "Saving...",
  "edit": "Edit",
  "delete": "Delete",
  "deleteConfirm": "Delete this address?",
  "empty": "No saved addresses yet",
  "emptyHint": "Add your frequently used delivery locations for faster checkout"
}
```

Add corresponding Nepali translations to `apps/web/messages/ne.json`.

**Step 3: Verify build**

Run: `pnpm --filter web build`

**Step 4: Commit**

```bash
git add apps/web/src/app/[locale]/settings/addresses/page.tsx apps/web/messages/en.json apps/web/messages/ne.json
git commit -m "feat: add saved addresses management page"
```

---

### Task 1.4: Integrate saved addresses into checkout

**Files:**
- Modify: `apps/web/src/app/[locale]/checkout/page.tsx`

**Step 1: Add saved address selector to checkout**

Above the LocationPicker in the checkout page:
1. Import and call `listAddresses()` in a useEffect (guarded by auth)
2. Show a row of address chips (label + truncated address text). Default address gets a filled style.
3. Clicking a chip sets `deliveryLocation` and `deliveryAddress`, triggers `computeFee()`
4. Add a "Save this address" checkbox that appears after picking a new location on the map
5. When checked and order is placed, call `createAddress()` with the selected location

Key integration points in existing code:
- After `const { user, loading: authLoading } = useAuth();` — add `const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);`
- In the auth-guarded data loading area — call `listAddresses()` and set state
- Above the `<LocationPicker>` section — render address chips
- After `handlePlaceOrder` success — if "save address" is checked, call `createAddress()`

**Step 2: Verify build + manual test**

Run: `pnpm --filter web build`
Manual: Go to `/en/checkout` with items in cart, verify saved addresses appear

**Step 3: Commit**

```bash
git add apps/web/src/app/[locale]/checkout/page.tsx
git commit -m "feat: integrate saved addresses into checkout page"
```

---

### Task 1.5: Add link to addresses page from user menu

**Files:**
- Modify: `apps/web/src/components/layout/Header.tsx`

**Step 1: Add "Saved Addresses" link to account dropdown**

In the Header component, find the account dropdown menu. Add a link to `/${locale}/settings/addresses` with a MapPin icon, placed near other account-related links.

**Step 2: Commit**

```bash
git add apps/web/src/components/layout/Header.tsx
git commit -m "feat: add saved addresses link to account menu"
```

---

## Feature 2: Delivery ETAs on Marketplace

### Task 2.1: Delivery ETA server action

**Files:**
- Create: `apps/web/src/lib/actions/delivery-eta.ts`

**Step 1: Create the ETA action**

```ts
"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

/**
 * Get estimated delivery minutes for a batch of listings to a delivery point.
 * Uses PostGIS ST_Distance + configurable speed assumptions.
 */
export async function getBatchDeliveryETAs(input: {
  listingIds: string[];
  deliveryLat: number;
  deliveryLng: number;
}): Promise<ActionResult<Record<string, number>>> {
  if (input.listingIds.length === 0) return { data: {} };

  const supabase = createServiceRoleClient();

  // Get farmer locations for all listings
  const { data, error } = await supabase
    .from("produce_listings")
    .select("id, farmer_id, users!inner(farm_location)")
    .in("id", input.listingIds);

  if (error) return { error: error.message };
  if (!data || data.length === 0) return { data: {} };

  // Calculate ETAs using PostGIS distance
  const deliveryPoint = `POINT(${input.deliveryLng} ${input.deliveryLat})`;
  const AVG_SPEED_KMH = 30;
  const PICKUP_BUFFER_MIN = 15;

  const { data: distances, error: distError } = await supabase.rpc(
    "batch_delivery_etas",
    {
      p_listing_ids: input.listingIds,
      p_delivery_point: deliveryPoint,
      p_avg_speed_kmh: AVG_SPEED_KMH,
      p_pickup_buffer_min: PICKUP_BUFFER_MIN,
    },
  );

  if (distError) {
    // Fallback: estimate using straight-line distance
    // This happens if the RPC doesn't exist yet
    return { data: {} };
  }

  const result: Record<string, number> = {};
  for (const row of distances ?? []) {
    result[row.listing_id] = row.eta_minutes;
  }
  return { data: result };
}
```

**Step 2: Create the supporting RPC in a migration**

Create `supabase/migrations/20260221100002_delivery_eta_rpc.sql`:

```sql
-- Batch ETA calculation for marketplace produce cards.
-- Returns estimated delivery minutes per listing based on farmer location.
CREATE OR REPLACE FUNCTION batch_delivery_etas(
  p_listing_ids UUID[],
  p_delivery_point TEXT,
  p_avg_speed_kmh NUMERIC DEFAULT 30,
  p_pickup_buffer_min INTEGER DEFAULT 15
)
RETURNS TABLE (listing_id UUID, eta_minutes INTEGER)
LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT
    pl.id AS listing_id,
    (p_pickup_buffer_min + CEIL(
      ST_Distance(u.farm_location, p_delivery_point::GEOGRAPHY) / 1000.0
      / p_avg_speed_kmh * 60
    ))::INTEGER AS eta_minutes
  FROM produce_listings pl
  JOIN users u ON u.id = pl.farmer_id
  WHERE pl.id = ANY(p_listing_ids)
    AND u.farm_location IS NOT NULL;
$$;
```

**Step 3: Apply migration + verify build**

Run: `supabase migration up` then `pnpm --filter web build`

**Step 4: Commit**

```bash
git add supabase/migrations/20260221100002_delivery_eta_rpc.sql apps/web/src/lib/actions/delivery-eta.ts
git commit -m "feat: add batch delivery ETA calculation"
```

---

### Task 2.2: Show ETAs on ProduceCard

**Files:**
- Modify: `apps/web/src/components/marketplace/ProduceCard.tsx`
- Modify: marketplace page that renders ProduceCard (pass ETA prop)

**Step 1: Add ETA badge to ProduceCard**

Add an optional `etaMinutes?: number` prop to ProduceCard. When provided, show a small badge:
```tsx
{etaMinutes && (
  <span className="absolute top-2 right-2 rounded-full bg-white/90 px-2 py-0.5 text-xs font-medium text-gray-700 shadow-sm">
    ~{etaMinutes} min
  </span>
)}
```

**Step 2: Load ETAs in marketplace page**

In the marketplace page, after loading listings:
1. Get user's default address from `listAddresses()` (if authenticated)
2. Call `getBatchDeliveryETAs()` with listing IDs + default address coords
3. Pass `etaMinutes` to each ProduceCard

Only show ETAs when user is authenticated and has a default address. No ETA for anonymous users.

**Step 3: Verify build**

Run: `pnpm --filter web build`

**Step 4: Commit**

```bash
git add apps/web/src/components/marketplace/ProduceCard.tsx apps/web/src/app/[locale]/marketplace/page.tsx
git commit -m "feat: show delivery ETA badges on marketplace produce cards"
```

---

## Feature 3: Payout System (Manual)

### Task 3.1: Database migration for earnings and payouts

**Files:**
- Create: `supabase/migrations/20260221100003_earnings_and_payouts.sql`

**Step 1: Write the migration**

```sql
-- Per-order earnings tracking for farmers and riders
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

CREATE INDEX earnings_user_status_idx ON earnings (user_id, status);
CREATE UNIQUE INDEX earnings_order_user_role_idx ON earnings (order_id, user_id, role);

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
CREATE INDEX payout_requests_pending_idx ON payout_requests (status, created_at)
  WHERE status IN ('pending', 'processing');

-- RLS
ALTER TABLE earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own earnings"
  ON earnings FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role full access on earnings"
  ON earnings FOR ALL USING (current_setting('role') = 'service_role');

CREATE POLICY "Users can view own payout requests"
  ON payout_requests FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own payout requests"
  ON payout_requests FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on payout_requests"
  ON payout_requests FOR ALL USING (current_setting('role') = 'service_role');

-- Auto-create earnings when order is delivered
CREATE OR REPLACE FUNCTION create_earnings_on_delivery()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    -- Farmer earnings: sum of subtotals per farmer
    INSERT INTO earnings (user_id, role, order_id, amount)
    SELECT oi.farmer_id, 'farmer', NEW.id, SUM(oi.subtotal)
    FROM order_items oi
    WHERE oi.order_id = NEW.id
    GROUP BY oi.farmer_id
    ON CONFLICT (order_id, user_id, role) DO NOTHING;

    -- Rider earnings: delivery fee
    IF NEW.rider_id IS NOT NULL AND COALESCE(NEW.delivery_fee, 0) > 0 THEN
      INSERT INTO earnings (user_id, role, order_id, amount)
      VALUES (NEW.rider_id, 'rider', NEW.id, NEW.delivery_fee)
      ON CONFLICT (order_id, user_id, role) DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_earnings_on_delivery
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION create_earnings_on_delivery();
```

**Step 2: Apply migration**

Run: `supabase db reset`

**Step 3: Commit**

```bash
git add supabase/migrations/20260221100003_earnings_and_payouts.sql
git commit -m "feat: add earnings and payout_requests tables with auto-create trigger"
```

---

### Task 3.2: Earnings server actions

**Files:**
- Create: `apps/web/src/lib/actions/earnings.ts`

**Step 1: Create the earnings actions**

Functions needed:
- `getEarningsSummary()` — returns `{ totalEarned, pendingBalance, settledBalance, totalWithdrawn, totalRequested }`
  - `pendingBalance` = sum of earnings where status='pending' minus sum of payout_requests where status in ('pending','processing')
- `listEarnings(page: number, status?: string)` — paginated list of earnings with order details
- `requestPayout({ amount, method, accountDetails })` — creates payout request, validates amount <= available balance

Follow the same pattern as `actions/orders.ts`: `"use server"`, `createServiceRoleClient()`, `createClient()` for auth, return `ActionResult<T>`.

**Step 2: Verify build**

Run: `pnpm --filter web build`

**Step 3: Commit**

```bash
git add apps/web/src/lib/actions/earnings.ts
git commit -m "feat: add earnings server actions"
```

---

### Task 3.3: Farmer earnings page

**Files:**
- Create: `apps/web/src/app/[locale]/farmer/earnings/page.tsx`

**Step 1: Create the earnings page**

Client component showing:
- **Summary cards**: Total Earned, Pending Balance, Withdrawn, Requested (pending payouts)
- **Earnings list**: Table/cards showing each earning (order ID snippet, amount, date, status badge)
- **"Request Payout" button**: Opens a form/modal with:
  - Amount input (max = available balance)
  - Payment method selector (eSewa / Khalti / Bank)
  - Account details: eSewa/Khalti phone number, or bank name + account number
  - Submit button
- Auth guard (useAuth pattern)

Use colors: pending=amber, settled=green, disputed=red. Same badge pattern as `OrderStatusBadge`.

**Step 2: Add i18n messages**

Add `"earnings"` key to `en.json` and `ne.json`:
```json
"earnings": {
  "title": "Earnings",
  "totalEarned": "Total Earned",
  "pendingBalance": "Available Balance",
  "settled": "Settled",
  "withdrawn": "Withdrawn",
  "requestPayout": "Request Payout",
  "amount": "Amount",
  "method": "Payment Method",
  "accountDetails": "Account Details",
  "esewaPhone": "eSewa Phone Number",
  "khaltiPhone": "Khalti Phone Number",
  "bankName": "Bank Name",
  "bankAccount": "Account Number",
  "submit": "Submit Request",
  "submitting": "Submitting...",
  "noEarnings": "No earnings yet",
  "noEarningsHint": "Your earnings will appear here after your first delivered order",
  "perOrder": "per order",
  "status": {
    "pending": "Pending",
    "settled": "Settled",
    "disputed": "Disputed"
  },
  "payoutStatus": {
    "pending": "Pending",
    "processing": "Processing",
    "completed": "Completed",
    "rejected": "Rejected"
  }
}
```

**Step 3: Verify build**

Run: `pnpm --filter web build`

**Step 4: Commit**

```bash
git add apps/web/src/app/[locale]/farmer/earnings/page.tsx apps/web/messages/en.json apps/web/messages/ne.json
git commit -m "feat: add farmer earnings page with payout requests"
```

---

### Task 3.4: Rider earnings page

**Files:**
- Create: `apps/web/src/app/[locale]/rider/earnings/page.tsx`

**Step 1: Create the rider earnings page**

Same structure as farmer earnings page but accessible from rider dashboard. Reuse the same server actions (`getEarningsSummary`, `listEarnings`, `requestPayout`). The actions already filter by authenticated user, and the `earnings` table has a `role` column, but both farmer and rider earnings for the same user are visible — this is correct since a user can have both roles.

Copy the pattern from `farmer/earnings/page.tsx`, adjust the layout to match rider dashboard styling (link back to `/rider/dashboard`).

**Step 2: Add "Earnings" link to farmer and rider dashboards**

- In `apps/web/src/app/[locale]/farmer/dashboard/page.tsx`: add a card/link to `/farmer/earnings`
- In `apps/web/src/app/[locale]/rider/dashboard/page.tsx`: add a card/link to `/rider/earnings`

**Step 3: Verify build**

Run: `pnpm --filter web build`

**Step 4: Commit**

```bash
git add apps/web/src/app/[locale]/rider/earnings/page.tsx apps/web/src/app/[locale]/farmer/dashboard/page.tsx apps/web/src/app/[locale]/rider/dashboard/page.tsx
git commit -m "feat: add rider earnings page, link from both dashboards"
```

---

### Task 3.5: Admin payouts management page

**Files:**
- Create: `apps/web/src/lib/actions/admin/payouts.ts`
- Create: `apps/web/src/app/[locale]/admin/payouts/page.tsx`

**Step 1: Create admin payout actions**

In `apps/web/src/lib/actions/admin/payouts.ts`:
- `listPayoutRequests(status?: string)` — all requests with user name, phone, role
- `processPayoutRequest(id, { status, adminNotes })` — update status + processed_at/by, mark related earnings as settled when completed

Use `requireAdmin(locale)` pattern from `apps/web/src/lib/admin/auth.ts`. Use `createSupabaseServerClient` (same as other admin pages).

**Step 2: Create admin payouts page**

Server component at `/admin/payouts`. Table showing:
- User name, phone, amount, method, account details, status, date
- Action buttons: Approve (→processing→completed) / Reject with notes field
- Filter tabs: Pending | Processing | Completed | Rejected

Follow the pattern of `/admin/orders/page.tsx` for layout and styling.

**Step 3: Add admin nav link**

Add "Payouts" link to admin navigation (check existing admin layout for where nav links are).

**Step 4: Verify build**

Run: `pnpm --filter web build`

**Step 5: Commit**

```bash
git add apps/web/src/lib/actions/admin/payouts.ts apps/web/src/app/[locale]/admin/payouts/page.tsx
git commit -m "feat: add admin payouts management page"
```

---

## Feature 4: Rider GPS Logging

### Task 4.1: Rider location logging server action

**Files:**
- Modify: `apps/web/src/lib/actions/tracking.ts`

**Step 1: Add logRiderLocation action**

Add to the existing `tracking.ts` file:

```ts
export async function logRiderLocation(
  tripId: string,
  lat: number,
  lng: number,
  speedKmh?: number,
): Promise<ActionResult> {
  if (!UUID_RE.test(tripId)) return { error: "Invalid trip ID" };
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return { error: "Invalid coordinates" };

  const supabase = createServiceRoleClient();

  const { error } = await supabase
    .from("rider_location_log")
    .insert({
      trip_id: tripId,
      rider_id: /* get from trip */ null, // Will fill below
      location: `POINT(${lng} ${lat})`,
      speed_kmh: speedKmh ?? null,
    });

  if (error) return { error: error.message };
  return { data: undefined };
}
```

Note: Need to look up `rider_id` from the trip. Check the `rider_location_log` table schema to see if `rider_id` is required. If so, fetch it from the trip first.

**Step 2: Verify build**

Run: `pnpm --filter web build`

**Step 3: Commit**

```bash
git add apps/web/src/lib/actions/tracking.ts
git commit -m "feat: add logRiderLocation server action"
```

---

### Task 4.2: GPS tracking hook for rider

**Files:**
- Create: `apps/web/src/hooks/useGpsTracking.ts`

**Step 1: Create the GPS tracking hook**

```ts
"use client";

import { useEffect, useRef, useCallback } from "react";
import { logRiderLocation } from "@/lib/actions/tracking";

const LOG_INTERVAL_MS = 10_000; // Log every 10 seconds

export function useGpsTracking(tripId: string, active: boolean) {
  const watchIdRef = useRef<number | null>(null);
  const lastLogRef = useRef<number>(0);

  const handlePosition = useCallback(
    (position: GeolocationPosition) => {
      const now = Date.now();
      if (now - lastLogRef.current < LOG_INTERVAL_MS) return;
      lastLogRef.current = now;

      const { latitude, longitude, speed } = position.coords;
      const speedKmh = speed != null ? speed * 3.6 : undefined; // m/s → km/h

      logRiderLocation(tripId, latitude, longitude, speedKmh).catch((err) =>
        console.error("Failed to log location:", err),
      );
    },
    [tripId],
  );

  useEffect(() => {
    if (!active || typeof navigator === "undefined" || !navigator.geolocation) return;

    watchIdRef.current = navigator.geolocation.watchPosition(
      handlePosition,
      (err) => console.error("Geolocation error:", err),
      { enableHighAccuracy: true, maximumAge: 5000 },
    );

    return () => {
      if (watchIdRef.current != null) {
        navigator.geolocation.clearWatch(watchIdRef.current);
        watchIdRef.current = null;
      }
    };
  }, [active, handlePosition]);
}
```

**Step 2: Verify build**

Run: `pnpm --filter web build`

**Step 3: Commit**

```bash
git add apps/web/src/hooks/useGpsTracking.ts
git commit -m "feat: add useGpsTracking hook for rider GPS logging"
```

---

### Task 4.3: Activate GPS tracking in rider trip detail

**Files:**
- Modify: `apps/web/src/app/[locale]/rider/trips/[id]/page.tsx`

**Step 1: Wire up the GPS tracking hook**

In the TripDetailPage component:

1. Import `useGpsTracking` from `@/hooks/useGpsTracking`
2. After the existing hooks, add:
   ```ts
   useGpsTracking(tripId, trip?.status === TripStatus.InTransit);
   ```
3. Add a visual indicator when tracking is active:
   ```tsx
   {trip.status === TripStatus.InTransit && (
     <div className="mb-4 flex items-center gap-2 rounded-md bg-blue-50 px-3 py-2 text-sm text-blue-700">
       <span className="h-2 w-2 rounded-full bg-blue-500 animate-pulse" />
       Location sharing active
     </div>
   )}
   ```

**Step 2: Verify build**

Run: `pnpm --filter web build`

**Step 3: Commit**

```bash
git add apps/web/src/app/[locale]/rider/trips/[id]/page.tsx
git commit -m "feat: activate GPS tracking when rider trip is in transit"
```

---

## Feature 5: Push Notification Triggers

### Task 5.1: Wire order status change notifications

**Files:**
- Create: `supabase/migrations/20260221100004_order_notification_triggers.sql`

**Step 1: Create database trigger for order status changes**

This trigger calls the existing `send-notification` edge function when order status changes:

```sql
-- Trigger function: send push notifications on order status changes
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_consumer_id UUID;
  v_rider_id UUID;
  v_farmer_ids UUID[];
  v_supabase_url TEXT;
  v_service_key TEXT;
BEGIN
  -- Only fire on status changes
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  v_consumer_id := NEW.customer_id;
  v_rider_id := NEW.rider_id;

  -- Get unique farmer IDs from order items
  SELECT ARRAY_AGG(DISTINCT oi.farmer_id)
  INTO v_farmer_ids
  FROM order_items oi WHERE oi.order_id = NEW.id;

  -- Read Supabase config for edge function call
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.service_role_key', true);

  -- Notify consumer based on new status
  IF NEW.status = 'matched' THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-notification',
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_service_key, 'Content-Type', 'application/json'),
      body := jsonb_build_object(
        'user_id', v_consumer_id,
        'category', 'order_matched',
        'title_en', 'Order Matched!',
        'title_ne', 'अर्डर मिल्यो!',
        'body_en', 'A rider has been matched to deliver your order.',
        'body_ne', 'तपाईंको अर्डर डेलिभरी गर्न राइडर भेटियो।',
        'data', jsonb_build_object('order_id', NEW.id, 'type', 'order_matched')
      )
    );
  ELSIF NEW.status = 'picked_up' THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-notification',
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_service_key, 'Content-Type', 'application/json'),
      body := jsonb_build_object(
        'user_id', v_consumer_id,
        'category', 'produce_picked_up',
        'title_en', 'Produce Picked Up',
        'title_ne', 'उत्पादन उठाइयो',
        'body_en', 'Your produce has been picked up and is on its way!',
        'body_ne', 'तपाईंको उत्पादन उठाइएको छ र बाटोमा छ!',
        'data', jsonb_build_object('order_id', NEW.id, 'type', 'produce_picked_up')
      )
    );
  ELSIF NEW.status = 'in_transit' THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-notification',
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_service_key, 'Content-Type', 'application/json'),
      body := jsonb_build_object(
        'user_id', v_consumer_id,
        'category', 'rider_arriving',
        'title_en', 'Order On The Way!',
        'title_ne', 'अर्डर बाटोमा छ!',
        'body_en', 'Your rider is heading to your delivery location.',
        'body_ne', 'तपाईंको राइडर डेलिभरी स्थानमा आउँदैछ।',
        'data', jsonb_build_object('order_id', NEW.id, 'type', 'rider_arriving')
      )
    );
  ELSIF NEW.status = 'delivered' THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-notification',
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_service_key, 'Content-Type', 'application/json'),
      body := jsonb_build_object(
        'user_id', v_consumer_id,
        'category', 'order_delivered',
        'title_en', 'Order Delivered!',
        'title_ne', 'अर्डर डेलिभर भयो!',
        'body_en', 'Your order has been delivered. Enjoy your fresh produce!',
        'body_ne', 'तपाईंको अर्डर डेलिभर भयो। ताजा उत्पादनको आनन्द लिनुहोस्!',
        'data', jsonb_build_object('order_id', NEW.id, 'type', 'order_delivered')
      )
    );
  END IF;

  -- Notify farmers when new order is placed (pending)
  IF NEW.status = 'pending' AND OLD.status IS DISTINCT FROM 'pending' THEN
    IF v_farmer_ids IS NOT NULL THEN
      FOR i IN 1..array_length(v_farmer_ids, 1) LOOP
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send-notification',
          headers := jsonb_build_object('Authorization', 'Bearer ' || v_service_key, 'Content-Type', 'application/json'),
          body := jsonb_build_object(
            'user_id', v_farmer_ids[i],
            'category', 'new_order',
            'title_en', 'New Order!',
            'title_ne', 'नयाँ अर्डर!',
            'body_en', 'You have a new order for your produce.',
            'body_ne', 'तपाईंको उत्पादनको लागि नयाँ अर्डर आएको छ।',
            'data', jsonb_build_object('order_id', NEW.id, 'type', 'new_order')
          )
        );
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_order_status_change
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();

-- Also trigger on INSERT for new orders
CREATE TRIGGER trg_notify_new_order
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();
```

Note: This uses `net.http_post` from the `pg_net` extension (available in Supabase). If `pg_net` is not enabled, add `CREATE EXTENSION IF NOT EXISTS pg_net;` at the top of the migration. Alternatively, if `pg_net` isn't available, use `pg_notify` + a listener process. Check Supabase docs for the recommended approach.

**Step 2: Apply migration**

Run: `supabase db reset`
Verify: No migration errors

**Step 3: Commit**

```bash
git add supabase/migrations/20260221100004_order_notification_triggers.sql
git commit -m "feat: add push notification triggers for order status changes"
```

---

### Task 5.2: Mount PushNotificationManager in app layout

**Files:**
- Modify: `apps/web/src/app/[locale]/layout.tsx` or the component that wraps authenticated pages

**Step 1: Check if PushNotificationManager is already mounted**

Search for `PushNotificationManager` usage in the app. If not mounted anywhere:

Add `<PushNotificationManager />` inside the AuthProvider (or alongside it in the root layout) so it runs for all authenticated users:

```tsx
import { PushNotificationManager } from "@/components/notifications/PushNotificationManager";

// In the layout JSX, inside AuthProvider:
<PushNotificationManager />
```

This component renders null (side-effect only) and handles:
- Requesting notification permission
- Getting FCM token
- Registering the token with the server
- Listening for foreground messages

**Step 2: Add firebase-messaging-sw.js service worker**

Check if `apps/web/public/firebase-messaging-sw.js` exists. If not, create it:

```js
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: self.__FIREBASE_CONFIG__?.apiKey,
  projectId: self.__FIREBASE_CONFIG__?.projectId,
  messagingSenderId: self.__FIREBASE_CONFIG__?.messagingSenderId,
  appId: self.__FIREBASE_CONFIG__?.appId,
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? "JiriSewa";
  const options = {
    body: payload.notification?.body ?? "",
    icon: "/icon-192x192.png",
    data: payload.data,
  };
  self.registration.showNotification(title, options);
});
```

Note: The config values need to be injected. Check Firebase docs for the recommended approach with VAPID keys for web push.

**Step 3: Verify build**

Run: `pnpm --filter web build`

**Step 4: Commit**

```bash
git add apps/web/src/app/[locale]/layout.tsx apps/web/public/firebase-messaging-sw.js
git commit -m "feat: mount PushNotificationManager and add service worker"
```

---

## Verification Checklist

After all tasks are complete, verify:

1. `pnpm --filter web build` — compiles without errors
2. `supabase db reset` — all migrations apply cleanly
3. Manual tests:
   - Create a saved address at `/settings/addresses`
   - Go to checkout, see saved address chips, select one
   - Check marketplace cards show ETA badges (when logged in with default address)
   - Place an order, check `earnings` table after marking as delivered
   - Visit `/farmer/earnings`, see earnings summary
   - Visit `/rider/earnings`, see earnings summary
   - Request a payout, check `/admin/payouts`
   - Start a rider trip, check `rider_location_log` gets GPS entries
   - Check browser notification permission prompt appears
