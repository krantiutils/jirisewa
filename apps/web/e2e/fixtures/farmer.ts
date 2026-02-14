import { test as base, expect, type Page } from "@playwright/test";

/**
 * Extended test fixture for farmer E2E tests.
 *
 * All tests using this fixture run with authenticated farmer session
 * (via storageState in playwright.config.ts).
 */
export const test = base.extend<{
  farmerDashboard: Page;
}>({
  farmerDashboard: async ({ page }, use) => {
    await page.goto("/en/farmer/dashboard");
    await page.waitForLoadState("networkidle");
    // eslint-disable-next-line react-hooks/rules-of-hooks
    await use(page);
  },
});

export { expect };
