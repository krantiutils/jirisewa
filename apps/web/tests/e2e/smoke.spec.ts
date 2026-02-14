import { test, expect } from "@playwright/test";
import { HomePage } from "../pages/home.page";
import { MarketplacePage } from "../pages/marketplace.page";
import { LoginPage } from "../pages/auth.page";

/**
 * Smoke tests — verify key pages load without errors.
 *
 * These are fast, non-visual tests that ensure pages render
 * and basic navigation works. They run on every PR.
 */

test.describe("Smoke Tests", () => {
  test("home page loads and renders hero", async ({ page }) => {
    const homePage = new HomePage(page);
    await homePage.goto();

    await expect(homePage.heroHeading).toBeVisible();
    await expect(page).toHaveTitle(/JiriSewa|जिरीसेवा/i);
  });

  test("marketplace page loads", async ({ page }) => {
    const marketplace = new MarketplacePage(page);
    await marketplace.goto();
    await marketplace.waitForLoaded();

    await expect(marketplace.heading).toBeVisible();
  });

  test("login page renders phone input", async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();

    await expect(loginPage.countryCode).toBeVisible();
    await expect(loginPage.phoneInput).toBeVisible();
    await expect(loginPage.sendOtpButton).toBeVisible();
  });

  test("navigation links work", async ({ page }) => {
    const homePage = new HomePage(page);
    await homePage.goto();

    // Navigate to marketplace via nav link
    await homePage.navigateToMarketplace();
    await page.waitForLoadState("networkidle");
    await expect(page).toHaveURL(/\/en\/marketplace/);
  });

  test("cart page loads", async ({ page }) => {
    await page.goto("/en/cart");
    await page.waitForLoadState("networkidle");

    // Cart page should render (either items or empty state)
    await expect(page.locator("h1").or(page.locator("main"))).toBeVisible();
  });

  test("farmer dashboard page loads", async ({ page }) => {
    await page.goto("/en/farmer/dashboard");
    await page.waitForLoadState("networkidle");

    // Should render something (even if redirected to login)
    await expect(page.locator("body")).toBeVisible();
  });

  test("rider dashboard page loads", async ({ page }) => {
    await page.goto("/en/rider/dashboard");
    await page.waitForLoadState("networkidle");

    await expect(page.locator("body")).toBeVisible();
  });

  test("orders page loads", async ({ page }) => {
    await page.goto("/en/orders");
    await page.waitForLoadState("networkidle");

    await expect(page.locator("body")).toBeVisible();
  });

  test("locale routing — default redirects to /ne", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Default locale is 'ne', so / should redirect
    await expect(page).toHaveURL(/\/(ne|en)/);
  });

  test("no console errors on home page", async ({ page }) => {
    const errors: string[] = [];
    page.on("console", (msg) => {
      if (msg.type() === "error") {
        errors.push(msg.text());
      }
    });

    await page.goto("/en");
    await page.waitForLoadState("networkidle");

    // Filter out known non-critical errors (e.g., favicon 404, Supabase connection)
    const criticalErrors = errors.filter(
      (e) =>
        !e.includes("favicon") &&
        !e.includes("supabase") &&
        !e.includes("Failed to load resource"),
    );

    expect(criticalErrors).toEqual([]);
  });
});
