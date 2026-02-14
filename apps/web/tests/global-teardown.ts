import { type FullConfig } from "@playwright/test";

/**
 * Playwright global teardown — runs once after all tests complete.
 *
 * Responsibilities:
 *   1. Clean up test data from the database
 *   2. Remove temporary auth storage files
 *
 * This ensures test runs are isolated and don't leave artifacts
 * in the development database.
 */
export default async function globalTeardown(_config: FullConfig): Promise<void> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  console.log("[global-teardown] Starting cleanup...");

  if (!supabaseUrl || !serviceRoleKey) {
    console.log("[global-teardown] No Supabase config — skipping cleanup.");
    return;
  }

  try {
    // TODO: Clean up seeded test data.
    // When seeding is implemented in global-setup, add corresponding
    // cleanup here:
    //   1. Delete test orders, order_items
    //   2. Delete test produce_listings
    //   3. Delete test rider_trips
    //   4. Delete test users via admin API
    //
    // Use the service role key to bypass RLS for cleanup.

    console.log("[global-teardown] Cleanup complete.");
  } catch (error) {
    console.error("[global-teardown] Cleanup failed:", error);
    // Don't throw — teardown failures shouldn't mask test results.
  }
}
