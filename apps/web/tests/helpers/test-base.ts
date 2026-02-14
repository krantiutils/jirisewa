import { test as base, expect } from "@playwright/test";

/**
 * Extended test base with common utilities for JiriSewa E2E tests.
 *
 * Usage:
 *   import { test, expect } from '../helpers/test-base';
 *
 * This extends the default Playwright test with:
 *   - Locale-aware navigation helpers
 *   - Common assertions
 *   - Shared fixtures
 */
export const test = base.extend<{
  locale: string;
}>({
  locale: async ({}, use) => {
    await use("en");
  },
});

export { expect };

/**
 * Navigate to a locale-prefixed path.
 * All app routes live under /[locale]/, so this saves boilerplate.
 */
export async function navigateTo(
  page: import("@playwright/test").Page,
  path: string,
  locale = "en",
): Promise<void> {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  await page.goto(`/${locale}${normalizedPath}`);
}

/**
 * Wait for the page to be fully loaded and hydrated.
 * Next.js pages may take a moment for client-side hydration.
 */
export async function waitForHydration(
  page: import("@playwright/test").Page,
): Promise<void> {
  // Wait for Next.js to finish hydrating
  await page.waitForLoadState("networkidle");
  // Give React a tick to settle
  await page.waitForTimeout(500);
}

/**
 * Mask dynamic content before taking screenshots.
 * This prevents flaky visual regressions from timestamps, UUIDs, etc.
 */
export function screenshotMasks(page: import("@playwright/test").Page) {
  return {
    mask: [
      // Mask any elements with data-testid="dynamic-content"
      page.locator("[data-testid='dynamic-content']"),
      // Mask timestamps
      page.locator("time"),
    ],
  };
}
