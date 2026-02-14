import { test, expect } from "@playwright/test";
import { HomePage } from "../pages/home.page";
import { MarketplacePage } from "../pages/marketplace.page";
import { LoginPage, RegisterPage } from "../pages/auth.page";
import { CartPage } from "../pages/cart.page";

/**
 * Visual regression tests for key public pages.
 *
 * These tests use toHaveScreenshot() to capture baseline screenshots
 * and detect visual regressions on subsequent runs.
 *
 * To update baselines:
 *   pnpm test:e2e:update-snapshots
 *
 * Screenshot baselines are stored in:
 *   tests/screenshots/
 */

test.describe("Visual Regression — Public Pages", () => {
  test.describe.configure({ mode: "parallel" });

  test("home page — full page", async ({ page }) => {
    const homePage = new HomePage(page);
    await homePage.goto();
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("home-full.png", {
      fullPage: true,
      mask: [page.locator("time")],
    });
  });

  test("home page — hero section", async ({ page }) => {
    const homePage = new HomePage(page);
    await homePage.goto();
    await page.waitForLoadState("networkidle");

    // Capture just the hero/above-the-fold area
    await expect(page).toHaveScreenshot("home-hero.png", {
      clip: { x: 0, y: 0, width: 1280, height: 800 },
    });
  });

  test("marketplace page", async ({ page }) => {
    const marketplace = new MarketplacePage(page);
    await marketplace.goto();
    await marketplace.waitForLoaded();

    await expect(page).toHaveScreenshot("marketplace.png", {
      fullPage: true,
      mask: [page.locator("time"), page.locator("img")],
    });
  });

  test("login page", async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("login.png", {
      fullPage: true,
    });
  });

  test("registration page", async ({ page }) => {
    const registerPage = new RegisterPage(page);
    await registerPage.goto();
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("register.png", {
      fullPage: true,
    });
  });

  test("cart page — empty state", async ({ page }) => {
    const cartPage = new CartPage(page);
    await cartPage.goto();
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("cart-empty.png", {
      fullPage: true,
    });
  });

  test("farmer dashboard page", async ({ page }) => {
    await page.goto("/en/farmer/dashboard");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("farmer-dashboard.png", {
      fullPage: true,
      mask: [page.locator("time"), page.locator("img")],
    });
  });

  test("farmer verification page", async ({ page }) => {
    await page.goto("/en/farmer/verification");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("farmer-verification.png", {
      fullPage: true,
    });
  });

  test("rider dashboard page", async ({ page }) => {
    await page.goto("/en/rider/dashboard");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("rider-dashboard.png", {
      fullPage: true,
      mask: [page.locator("time"), page.locator("img")],
    });
  });

  test("orders page", async ({ page }) => {
    await page.goto("/en/orders");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("orders.png", {
      fullPage: true,
      mask: [page.locator("time")],
    });
  });

  test("checkout page", async ({ page }) => {
    await page.goto("/en/checkout");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("checkout.png", {
      fullPage: true,
    });
  });

  test("notifications page", async ({ page }) => {
    await page.goto("/en/notifications");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("notifications.png", {
      fullPage: true,
      mask: [page.locator("time")],
    });
  });

  test("admin dashboard page", async ({ page }) => {
    await page.goto("/en/admin");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot("admin-dashboard.png", {
      fullPage: true,
      mask: [page.locator("time")],
    });
  });
});
