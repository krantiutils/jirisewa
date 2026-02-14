import { test as setup } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import path from "node:path";
import fs from "node:fs";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AdminClient = SupabaseClient<any, "public", any>;

const STORAGE_STATE_PATH = path.join(__dirname, ".auth/farmer.json");

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "http://127.0.0.1:54321";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

const TEST_FARMER_PHONE = "+9779800000001";
const TEST_FARMER_NAME = "E2E Test Farmer";
const TEST_FARM_NAME = "E2E Test Farm";
const TEST_PASSWORD = "e2e-test-password-jirisewa-2026";

setup("authenticate as farmer and seed data", async ({ page }) => {
  if (!SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error(
      "SUPABASE_SERVICE_ROLE_KEY is required for E2E tests. " +
        "Set it in your environment or .env.test file.",
    );
  }
  if (!SUPABASE_ANON_KEY) {
    throw new Error(
      "NEXT_PUBLIC_SUPABASE_ANON_KEY is required for E2E tests.",
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // --- Create or find the test farmer user ---
  const { data: existingUsers } = await supabase.auth.admin.listUsers();
  let userId: string;

  const existingUser = existingUsers?.users?.find(
    (u) => u.phone === TEST_FARMER_PHONE,
  );

  if (existingUser) {
    userId = existingUser.id;
    // Ensure password is set for programmatic login
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await (supabase.auth.admin as any).updateUser(userId, { password: TEST_PASSWORD });
  } else {
    const { data: newUser, error: createError } =
      await supabase.auth.admin.createUser({
        phone: TEST_FARMER_PHONE,
        phone_confirm: true,
        password: TEST_PASSWORD,
      });
    if (createError)
      throw new Error(`Failed to create test user: ${createError.message}`);
    userId = newUser.user.id;

    // Create user profile
    const { error: profileError } = await supabase.from("users").upsert({
      id: userId,
      phone: TEST_FARMER_PHONE,
      name: TEST_FARMER_NAME,
      role: "farmer",
      lang: "en",
    });
    if (profileError)
      throw new Error(
        `Failed to create user profile: ${profileError.message}`,
      );

    // Create farmer role
    const { error: roleError } = await supabase.from("user_roles").upsert(
      {
        user_id: userId,
        role: "farmer",
        farm_name: TEST_FARM_NAME,
      },
      { onConflict: "user_id,role" },
    );
    if (roleError)
      throw new Error(`Failed to create farmer role: ${roleError.message}`);
  }

  // --- Seed test data ---

  // Verify produce categories exist
  const { data: categories } = await supabase
    .from("produce_categories")
    .select("id, name_en")
    .order("sort_order")
    .limit(3);

  if (!categories || categories.length === 0) {
    throw new Error(
      "No produce categories found — run Supabase migrations first.",
    );
  }

  // Clean up existing test listings for this farmer
  await supabase.from("produce_listings").delete().eq("farmer_id", userId);

  // Create test listings
  const testListings = [
    {
      farmer_id: userId,
      category_id: categories[0].id,
      name_en: "Fresh Tomatoes",
      name_ne: "ताजा गोलभेडा",
      description: "Organically grown fresh tomatoes from our farm.",
      price_per_kg: 120,
      available_qty_kg: 50,
      freshness_date: new Date().toISOString().split("T")[0],
      photos: [],
      is_active: true,
    },
    {
      farmer_id: userId,
      category_id: categories[1].id,
      name_en: "Organic Potatoes",
      name_ne: "जैविक आलु",
      description: "Premium organic potatoes, harvested today.",
      price_per_kg: 80,
      available_qty_kg: 100,
      freshness_date: new Date().toISOString().split("T")[0],
      photos: [],
      is_active: true,
    },
    {
      farmer_id: userId,
      category_id: categories[2].id,
      name_en: "Purple Onions",
      name_ne: "बैजनी प्याज",
      description: "Fresh purple onions, great for cooking.",
      price_per_kg: 60,
      available_qty_kg: 30,
      freshness_date: new Date().toISOString().split("T")[0],
      photos: [],
      is_active: false,
    },
  ];

  const { error: listingError } = await supabase
    .from("produce_listings")
    .insert(testListings);
  if (listingError)
    throw new Error(`Failed to seed listings: ${listingError.message}`);

  // Seed a test order for order management tests
  await seedTestOrder(supabase, userId);

  // --- Authenticate via Supabase REST API and inject session cookies ---

  // Sign in via GoTrue REST API to get access/refresh tokens
  const tokenResponse = await fetch(
    `${SUPABASE_URL}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({
        phone: TEST_FARMER_PHONE,
        password: TEST_PASSWORD,
      }),
    },
  );

  if (!tokenResponse.ok) {
    const errorBody = await tokenResponse.text();
    throw new Error(
      `Failed to sign in test user: ${tokenResponse.status} ${errorBody}`,
    );
  }

  const session = await tokenResponse.json();

  // Construct the session cookie value matching @supabase/ssr format
  // The cookie name follows: sb-{hostname_first_part}-auth-token
  const supabaseHostname = new URL(SUPABASE_URL).hostname;
  const ref = supabaseHostname.split(".")[0];
  const cookieName = `sb-${ref}-auth-token`;

  // @supabase/ssr stores the session JSON, chunked into ~3.5KB cookie pieces
  const sessionJson = JSON.stringify({
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_at: session.expires_at,
    expires_in: session.expires_in,
    token_type: session.token_type,
    user: session.user,
  });

  // Navigate to the app first to establish the domain for cookies
  const baseUrl = process.env.BASE_URL ?? "http://localhost:3000";
  await page.goto(baseUrl);

  // Chunk the session cookie value (Supabase SSR chunks at ~3600 chars)
  const CHUNK_SIZE = 3600;
  const chunks = chunkString(sessionJson, CHUNK_SIZE);

  const baseUrlObj = new URL(baseUrl);
  const cookieDomain = baseUrlObj.hostname;

  if (chunks.length === 1) {
    // Single cookie (session fits in one cookie)
    await page.context().addCookies([
      {
        name: cookieName,
        value: sessionJson,
        domain: cookieDomain,
        path: "/",
        httpOnly: false,
        secure: false,
        sameSite: "Lax",
      },
    ]);
  } else {
    // Chunked cookies
    const cookies = chunks.map((chunk, i) => ({
      name: `${cookieName}.${i}`,
      value: chunk,
      domain: cookieDomain,
      path: "/",
      httpOnly: false,
      secure: false,
      sameSite: "Lax" as const,
    }));
    await page.context().addCookies(cookies);
  }

  // Verify auth works by navigating to the farmer dashboard
  await page.goto(`${baseUrl}/en/farmer/dashboard`);
  await page.waitForLoadState("networkidle");

  // Save the authenticated storage state
  fs.mkdirSync(path.dirname(STORAGE_STATE_PATH), { recursive: true });
  await page.context().storageState({ path: STORAGE_STATE_PATH });
});

function chunkString(str: string, size: number): string[] {
  const chunks: string[] = [];
  for (let i = 0; i < str.length; i += size) {
    chunks.push(str.slice(i, i + size));
  }
  return chunks;
}

async function seedTestOrder(
  supabase: AdminClient,
  farmerId: string,
) {
  // Create a test consumer
  const consumerPhone = "+9779800000002";
  const { data: existingUsers } = await supabase.auth.admin.listUsers();
  let consumerId: string;

  const existingConsumer = existingUsers?.users?.find(
    (u) => u.phone === consumerPhone,
  );

  if (existingConsumer) {
    consumerId = existingConsumer.id;
  } else {
    const { data: newConsumer, error: consumerError } =
      await supabase.auth.admin.createUser({
        phone: consumerPhone,
        phone_confirm: true,
      });
    if (consumerError)
      throw new Error(
        `Failed to create test consumer: ${consumerError.message}`,
      );
    consumerId = newConsumer.user.id;

    await supabase.from("users").upsert({
      id: consumerId,
      phone: consumerPhone,
      name: "E2E Test Consumer",
      role: "consumer",
      lang: "en",
    });
    await supabase.from("user_roles").upsert(
      { user_id: consumerId, role: "consumer" },
      { onConflict: "user_id,role" },
    );
  }

  // Get an active listing from the farmer
  const { data: listing } = await supabase
    .from("produce_listings")
    .select("id")
    .eq("farmer_id", farmerId)
    .eq("is_active", true)
    .limit(1)
    .single();

  if (!listing) return;

  // Clean up existing test order items for this farmer
  await supabase.from("order_items").delete().eq("farmer_id", farmerId);

  // Clean up orders from test consumer
  await supabase.from("orders").delete().eq("consumer_id", consumerId);

  // Create test order
  const { data: order, error: orderError } = await supabase
    .from("orders")
    .insert({
      consumer_id: consumerId,
      status: "pending",
      delivery_address: "Kathmandu, Nepal",
      delivery_location: "SRID=4326;POINT(85.3240 27.7172)",
      total_price: 240,
      delivery_fee: 50,
      payment_method: "cash",
    })
    .select("id")
    .single();

  if (orderError || !order) return;

  await supabase.from("order_items").insert({
    order_id: order.id,
    listing_id: listing.id,
    farmer_id: farmerId,
    quantity_kg: 2,
    price_per_kg: 120,
    subtotal: 240,
  });
}
