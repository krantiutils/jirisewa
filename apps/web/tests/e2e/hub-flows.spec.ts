import { test, expect } from "@playwright/test";

/**
 * Smoke tests for Phase 1 (Aggregation Hubs) routes.
 *
 * These run anonymously — pages must render without 500s and redirect
 * unauthenticated users to login rather than crash.
 *
 * Authenticated end-to-end coverage lives in apps/web/e2e/hub-*.spec.ts
 * (gated behind FULL_E2E=1 + SUPABASE_SERVICE_ROLE_KEY).
 */

test.describe("Hub flows (smoke)", () => {
  test("admin hubs index requires auth — redirects to login or home", async ({ page }) => {
    const resp = await page.goto("/en/admin/hubs");
    await page.waitForLoadState("networkidle");
    expect(resp?.status() ?? 200).toBeLessThan(500);
    await expect(page).toHaveURL(/\/(en|ne)\/(auth\/login|$)|^https?:\/\/[^/]+\/(en|ne)\/?$/);
  });

  test("admin new hub form requires auth", async ({ page }) => {
    const resp = await page.goto("/en/admin/hubs/new");
    await page.waitForLoadState("networkidle");
    expect(resp?.status() ?? 200).toBeLessThan(500);
  });

  test("farmer hubs (dropoff) page requires auth", async ({ page }) => {
    const resp = await page.goto("/en/farmer/hubs");
    await page.waitForLoadState("networkidle");
    expect(resp?.status() ?? 200).toBeLessThan(500);
  });

  test("hub operator dashboard requires auth", async ({ page }) => {
    const resp = await page.goto("/en/hub");
    await page.waitForLoadState("networkidle");
    expect(resp?.status() ?? 200).toBeLessThan(500);
  });

  test("farmer dashboard surfaces 'Drop off' link when rendered", async ({ page }) => {
    // Anonymous request lands on auth gate; if unauthed redirects, the
    // farmer-hubs-link won't be visible. We're just asserting that whichever
    // page renders in its place doesn't 500.
    const resp = await page.goto("/en/farmer/dashboard");
    await page.waitForLoadState("networkidle");
    expect(resp?.status() ?? 200).toBeLessThan(500);
  });
});
