import type { Page } from "@playwright/test";

/**
 * Mock Supabase REST & Auth responses so pages render without a real backend.
 *
 * Intercepts all requests to the Supabase URL and returns sensible defaults.
 * Individual tests can register additional page.route() overrides before
 * calling mockSupabaseRoutes — Playwright matches later routes first.
 */

const configuredSupabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
const SUPABASE_URLS = Array.from(
  new Set(
    [
      configuredSupabaseUrl,
      "http://localhost:54321",
      "http://127.0.0.1:54321",
    ].filter((value): value is string => Boolean(value)),
  ),
);

function cookieNameFromSupabaseUrl(url: string): string {
  const hostname = new URL(url).hostname;
  const ref = hostname.split(".")[0];
  return `sb-${ref}-auth-token`;
}

// ── Demo IDs (match server actions) ──────────────────────────────────────
export const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";
export const DEMO_RIDER_ID = "00000000-0000-0000-0000-000000000000";
export const DEMO_FARMER_ID = "00000000-0000-0000-0000-000000000002";
export const DEMO_ADMIN_ID = "00000000-0000-0000-0000-000000000099";

export const DEMO_TRIP_ID = "aaaaaaaa-0000-0000-0000-000000000001";
export const DEMO_ORDER_ID = "bbbbbbbb-0000-0000-0000-000000000001";

// ── Fixture data ─────────────────────────────────────────────────────────

export const demoUser = {
  id: DEMO_RIDER_ID,
  phone: "+9779800000001",
  name: "Test Rider",
  lang: "en",
  avatar_url: null,
  rating_avg: 4.5,
  rating_count: 12,
  address: "Jiri",
  municipality: "Jiri Municipality",
  is_admin: false,
  created_at: "2026-01-01T00:00:00Z",
  updated_at: "2026-01-01T00:00:00Z",
};

export const demoAdminUser = {
  ...demoUser,
  id: DEMO_ADMIN_ID,
  name: "Admin User",
  is_admin: true,
};

export const demoTrip = {
  id: DEMO_TRIP_ID,
  rider_id: DEMO_RIDER_ID,
  origin: "POINT(86.2 27.6)",
  origin_name: "Jiri",
  destination: "POINT(85.3 27.7)",
  destination_name: "Kathmandu",
  route: null,
  departure_at: "2026-02-20T08:00:00Z",
  available_capacity_kg: 100,
  remaining_capacity_kg: 80,
  status: "scheduled",
  vehicle_type: "bike",
  created_at: "2026-02-14T00:00:00Z",
  updated_at: "2026-02-14T00:00:00Z",
};

export const demoOrder = {
  id: DEMO_ORDER_ID,
  consumer_id: DEMO_CONSUMER_ID,
  rider_id: DEMO_RIDER_ID,
  rider_trip_id: DEMO_TRIP_ID,
  status: "matched",
  delivery_address: "Kathmandu, Ward 10",
  delivery_location: "POINT(85.3 27.7)",
  total_price: 500,
  delivery_fee: 50,
  payment_method: "cash",
  payment_status: "pending",
  parent_order_id: null,
  created_at: "2026-02-14T00:00:00Z",
  updated_at: "2026-02-14T00:00:00Z",
  items: [
    {
      id: "item-001",
      order_id: DEMO_ORDER_ID,
      listing_id: "listing-001",
      farmer_id: DEMO_FARMER_ID,
      quantity_kg: 5,
      price_per_kg: 100,
      subtotal: 500,
      pickup_sequence: 1,
      pickup_status: "pending_pickup",
      pickup_confirmed: false,
      pickup_confirmed_at: null,
      pickup_location: "POINT(86.2 27.6)",
      delivery_confirmed: false,
      listing: {
        name_en: "Fresh Tomatoes",
        name_ne: "ताजा गोलभेडा",
        photos: [],
      },
      farmer: {
        id: DEMO_FARMER_ID,
        name: "Demo Farmer",
        avatar_url: null,
      },
    },
  ],
  rider: {
    id: DEMO_RIDER_ID,
    name: "Test Rider",
    avatar_url: null,
    phone: "+9779800000001",
    rating_avg: 4.5,
  },
  trip: {
    id: DEMO_TRIP_ID,
    origin_name: "Jiri",
    destination_name: "Kathmandu",
    departure_at: "2026-02-20T08:00:00Z",
  },
  farmerPayouts: [],
};

// ── Auth session mock ────────────────────────────────────────────────────

export const demoSession = {
  access_token: "test-access-token",
  refresh_token: "test-refresh-token",
  token_type: "bearer",
  expires_in: 3600,
  expires_at: Math.floor(Date.now() / 1000) + 3600,
  user: {
    id: DEMO_RIDER_ID,
    phone: "+9779800000001",
    email: null,
    role: "authenticated",
    aud: "authenticated",
    app_metadata: { provider: "phone" },
    user_metadata: {},
    created_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
  },
};

// ── Platform stats (admin) ───────────────────────────────────────────────

export const demoPlatformStats = {
  totalUsers: 150,
  totalOrders: 87,
  totalRevenue: 45000,
  activeListings: 42,
  totalFarmers: 60,
  totalConsumers: 70,
  totalRiders: 20,
  pendingDisputes: 3,
  unverifiedFarmers: 5,
};

// ── Route handler ────────────────────────────────────────────────────────

export async function mockSupabaseRoutes(page: Page) {
  for (const supabaseUrl of SUPABASE_URLS) {
    // Mock Auth: getSession / getUser
    await page.route(`${supabaseUrl}/auth/v1/token*`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(demoSession),
      });
    });

    await page.route(`${supabaseUrl}/auth/v1/user`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(demoSession.user),
      });
    });

    await page.route(`${supabaseUrl}/auth/v1/otp`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({}),
      });
    });

    // Mock Realtime
    await page.route(`${supabaseUrl}/realtime/**`, async (route) => {
      await route.abort();
    });

    // Mock REST: catch-all for Supabase PostgREST
    await page.route(`${supabaseUrl}/rest/v1/**`, async (route) => {
      const url = route.request().url();

      if (url.includes("rider_trips")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([demoTrip]),
        });
        return;
      }

      if (url.includes("orders")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([demoOrder]),
        });
        return;
      }

      if (url.includes("users")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([demoUser]),
        });
        return;
      }

      if (url.includes("order_pings")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([]),
        });
        return;
      }

      if (url.includes("produce_listings")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([]),
        });
        return;
      }

      if (url.includes("produce_categories")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([]),
        });
        return;
      }

      if (url.includes("notifications")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([]),
        });
        return;
      }

      // Default: empty array
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([]),
      });
    });

    // Mock RPC calls
    await page.route(`${supabaseUrl}/rest/v1/rpc/**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([]),
      });
    });
  }
}

/**
 * Inject a fake auth session cookie so the Next.js middleware / AuthProvider
 * treats the visitor as logged in.
 */
export async function injectAuthCookies(page: Page) {
  // Clear any persisted auth cookies from storageState to avoid mixing
  // multiple Supabase cookie formats across test files.
  await page.context().clearCookies();

  const baseUrl = process.env.BASE_URL ?? "http://localhost:3000";
  const cookieDomain = new URL(baseUrl).hostname;
  const sessionCookieValue = JSON.stringify({
    access_token: demoSession.access_token,
    refresh_token: demoSession.refresh_token,
    expires_at: demoSession.expires_at,
    expires_in: demoSession.expires_in,
    token_type: "bearer",
    user: demoSession.user,
  });

  const cookieTargets = Array.from(
    new Set([
      cookieNameFromSupabaseUrl(SUPABASE_URLS[0] ?? "http://localhost:54321"),
      "sb-localhost-auth-token",
      "sb-127-auth-token",
    ]),
  );

  await page.context().addCookies(
    cookieTargets.map((name) => ({
      name,
      value: sessionCookieValue,
      domain: cookieDomain,
      path: "/",
    })),
  );
}

/**
 * Mock OSRM route API used by the trip creation flow.
 */
export async function mockOsrmRoutes(page: Page) {
  await page.route("**/route/v1/driving/**", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        code: "Ok",
        routes: [
          {
            distance: 185000,
            duration: 18000,
            geometry: {
              type: "LineString",
              coordinates: [
                [86.2, 27.6],
                [85.7, 27.65],
                [85.3, 27.7],
              ],
            },
          },
        ],
      }),
    });
  });
}

/**
 * Mock Nominatim reverse geocoding used by LocationPicker.
 */
export async function mockNominatim(page: Page) {
  await page.route("**/reverse*format=json*", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        display_name: "Jiri, Dolakha, Nepal",
        address: {
          town: "Jiri",
          county: "Dolakha",
          country: "Nepal",
        },
      }),
    });
  });
}
