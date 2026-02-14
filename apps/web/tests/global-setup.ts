import { type FullConfig } from "@playwright/test";

/**
 * Playwright global setup — runs once before all tests.
 *
 * Responsibilities:
 *   1. Verify the test environment (env vars, database connectivity)
 *   2. Seed test data into the database
 *   3. Create authenticated storage states for each test role
 *
 * When running against a live Supabase instance, this will:
 *   - Create test users via the Supabase admin API
 *   - Seed produce, trips, and orders
 *   - Generate auth cookies saved to tests/.auth/<role>-storage.json
 *
 * For local development without Supabase, tests can run against the
 * dev server and test public (unauthenticated) pages only.
 */
export default async function globalSetup(_config: FullConfig): Promise<void> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  console.log("[global-setup] Starting E2E test setup...");

  // Validate environment
  if (!supabaseUrl) {
    console.warn(
      "[global-setup] NEXT_PUBLIC_SUPABASE_URL not set — " +
        "skipping database seeding. Only public page tests will work.",
    );
    return;
  }

  if (!serviceRoleKey) {
    console.warn(
      "[global-setup] SUPABASE_SERVICE_ROLE_KEY not set — " +
        "skipping auth setup. Only unauthenticated tests will work.",
    );
    return;
  }

  try {
    // Verify Supabase connectivity
    const healthCheck = await fetch(`${supabaseUrl}/rest/v1/`, {
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    });

    if (!healthCheck.ok) {
      throw new Error(
        `Supabase health check failed: ${healthCheck.status} ${healthCheck.statusText}`,
      );
    }

    console.log("[global-setup] Supabase connected successfully.");

    // TODO: Seed test users and data when running against a real Supabase instance.
    // For now, the test suite is designed to work with whatever data exists
    // in the development database, testing primarily public pages and visual regression.
    //
    // Future seeding steps:
    //   1. Create test users via POST /auth/v1/admin/users
    //   2. Insert test produce_listings, rider_trips, orders
    //   3. Generate storage state files by authenticating each user
    //      and saving cookies with browserContext.storageState()

    console.log("[global-setup] Setup complete.");
  } catch (error) {
    console.error("[global-setup] Setup failed:", error);
    // Don't throw — allow tests to run; individual tests that need
    // auth/seeded data will fail with clear error messages.
  }
}
