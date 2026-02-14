import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  demoAdminUser,
  demoOrder,
} from "./helpers/supabase-mock";

test.describe("Admin dashboard", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);

    // Override user query to return admin user
    await page.route("**/rest/v1/users*", async (route) => {
      const url = route.request().url();
      if (url.includes("is_admin")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([demoAdminUser]),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([demoAdminUser]),
        });
      }
    });
  });

  test("admin dashboard shows platform statistics", async ({ page }) => {
    await page.goto("/en/admin");

    // The admin page is server-rendered and calls getPlatformStats
    // which hits Supabase; the mock returns our fixture data
    await page.waitForTimeout(1000);

    await expect(page.getByText("Platform Dashboard")).toBeVisible();

    await expect(page).toHaveScreenshot("admin-dashboard.png");
  });

  test("admin users page shows user list", async ({ page }) => {
    await page.goto("/en/admin/users");
    await page.waitForTimeout(1000);

    await expect(page.getByText("User Management")).toBeVisible();

    await expect(page).toHaveScreenshot("admin-users-list.png");
  });

  test("admin orders page shows order management", async ({ page }) => {
    await page.route("**/rest/v1/orders*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([
          demoOrder,
          { ...demoOrder, id: "order-002", status: "delivered", total_price: 750 },
          { ...demoOrder, id: "order-003", status: "cancelled", total_price: 300 },
        ]),
      });
    });

    await page.goto("/en/admin/orders");
    await page.waitForTimeout(1000);

    await expect(page.getByText("Order Management")).toBeVisible();

    await expect(page).toHaveScreenshot("admin-order-management.png");
  });

  test("admin disputes page shows disputed orders or empty state", async ({ page }) => {
    const disputedOrder = {
      ...demoOrder,
      status: "disputed",
      id: "dispute-001",
    };

    await page.route("**/rest/v1/orders*", async (route) => {
      const url = route.request().url();
      if (url.includes("disputed")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([disputedOrder]),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([disputedOrder]),
        });
      }
    });

    await page.goto("/en/admin/disputes");
    await page.waitForTimeout(1000);

    await expect(page.getByText("Dispute Resolution")).toBeVisible();

    await expect(page).toHaveScreenshot("admin-dispute-resolution.png");
  });
});
