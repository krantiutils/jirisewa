import { test, expect } from "@playwright/test";
import { mockSupabaseRoutes, injectAuthCookies } from "./helpers/supabase-mock";

test.describe("Language switching", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
  });

  test("landing page renders in English", async ({ page }) => {
    await page.goto("/en");

    await expect(page.getByText("Fresh from farm to your door")).toBeVisible();
    await expect(page.getByText("How It Works")).toBeVisible();
    await expect(page.getByText("Browse Produce")).toBeVisible();

    await expect(page).toHaveScreenshot("page-in-english.png");
  });

  test("toggle to Nepali switches all text", async ({ page }) => {
    await page.goto("/en");

    // Click the language switcher (shows "नेपाली" when current locale is English)
    const switcher = page.getByRole("button", { name: /नेपाली/i });
    await expect(switcher).toBeVisible();
    await switcher.click();

    // Wait for navigation to /ne
    await page.waitForURL("**/ne/**", { timeout: 5000 }).catch(() => {
      // URL might just be /ne without trailing slash
    });
    await page.waitForTimeout(500);

    // Nepali content should be visible
    // The nav and content switch to Nepali
    await expect(page.url()).toContain("/ne");

    await expect(page).toHaveScreenshot("page-in-nepali.png");
  });

  test("Nepali page shows English toggle and can switch back", async ({ page }) => {
    await page.goto("/ne");
    await page.waitForTimeout(500);

    // Language switcher should show "English" when on Nepali page
    const switcher = page.getByRole("button", { name: /english/i });
    await expect(switcher).toBeVisible();

    await expect(page).toHaveScreenshot("nepali-page-with-english-toggle.png");

    // Switch back to English
    await switcher.click();
    await page.waitForURL("**/en/**", { timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(500);

    await expect(page.url()).toContain("/en");
    await expect(page.getByText("Fresh from farm to your door")).toBeVisible();

    await expect(page).toHaveScreenshot("switched-back-to-english.png");
  });

  test("login page switches language correctly", async ({ page }) => {
    await page.goto("/en/auth/login");
    await page.waitForSelector("#phone");

    // English login text
    await expect(page.locator("h1")).toContainText("Log in");

    await expect(page).toHaveScreenshot("login-english.png");

    // Switch to Nepali
    const switcher = page.getByRole("button", { name: /नेपाली/i });
    await switcher.click();

    await page.waitForURL("**/ne/**", { timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(500);

    // Should be on /ne/auth/login now
    await expect(page.url()).toContain("/ne/auth/login");

    await expect(page).toHaveScreenshot("login-nepali.png");
  });
});
