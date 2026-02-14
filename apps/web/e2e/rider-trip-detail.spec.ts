import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  demoTrip,
  demoOrder,
  DEMO_TRIP_ID,
  DEMO_FARMER_ID,
} from "./helpers/supabase-mock";

test.describe("Trip detail with matched orders", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);

    // Mock tile server
    await page.route("**/tile.openstreetmap.org/**", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "image/png",
        body: Buffer.alloc(100),
      });
    });
  });

  test("displays trip detail with route, info, and matched orders", async ({ page }) => {
    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);

    // Wait for page to load
    await page.waitForSelector("h1");

    await expect(page.locator("h1")).toContainText("Trip Detail");
    await expect(page.getByText("Jiri")).toBeVisible();
    await expect(page.getByText("Kathmandu")).toBeVisible();
    await expect(page.getByText("100 kg")).toBeVisible(); // total capacity
    await expect(page.getByText("80 kg")).toBeVisible();  // remaining capacity

    await expect(page).toHaveScreenshot("trip-detail-overview.png");
  });

  test("shows matched order with farmer items and pickup buttons", async ({ page }) => {
    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    // Matched orders section
    await expect(page.getByText("Matched Orders")).toBeVisible();
    await expect(page.getByText("Fresh Tomatoes")).toBeVisible();
    await expect(page.getByText("5 kg")).toBeVisible();
    await expect(page.getByText("NPR 500")).toBeVisible();

    // Pickup confirmation button
    await expect(page.getByRole("button", { name: /confirm pickup/i })).toBeVisible();

    await expect(page).toHaveScreenshot("trip-detail-matched-orders.png");
  });

  test("scheduled trip shows edit, start, and cancel buttons", async ({ page }) => {
    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    await expect(page.getByRole("button", { name: /edit/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /start trip/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /cancel trip/i })).toBeVisible();

    await expect(page).toHaveScreenshot("trip-detail-scheduled-actions.png");
  });

  test("in-transit trip shows complete trip button", async ({ page }) => {
    const inTransitTrip = { ...demoTrip, status: "in_transit" };

    await page.route("**/rest/v1/rider_trips*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([inTransitTrip]),
      });
    });

    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    await expect(page.getByRole("button", { name: /complete trip/i })).toBeVisible();

    await expect(page).toHaveScreenshot("trip-detail-in-transit.png");
  });

  test("multi-farmer order shows per-farmer pickup cards", async ({ page }) => {
    const multiFarmerOrder = {
      ...demoOrder,
      items: [
        {
          ...demoOrder.items[0],
          farmer_id: DEMO_FARMER_ID,
          pickup_sequence: 1,
          farmer: { id: DEMO_FARMER_ID, name: "Farmer Ram", avatar_url: null },
        },
        {
          ...demoOrder.items[0],
          id: "item-002",
          farmer_id: "00000000-0000-0000-0000-000000000003",
          pickup_sequence: 2,
          listing: { name_en: "Potatoes", name_ne: "आलु", photos: [] },
          farmer: { id: "00000000-0000-0000-0000-000000000003", name: "Farmer Sita", avatar_url: null },
        },
      ],
    };

    await page.route("**/rest/v1/orders*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([multiFarmerOrder]),
      });
    });

    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    // Should show per-farmer groups
    await expect(page.getByText("Farmer Ram")).toBeVisible();
    await expect(page.getByText("Farmer Sita")).toBeVisible();
    await expect(page.getByText("Fresh Tomatoes")).toBeVisible();
    await expect(page.getByText("Potatoes")).toBeVisible();

    await expect(page).toHaveScreenshot("trip-detail-multi-farmer.png");
  });
});
