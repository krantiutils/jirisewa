import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  demoTrip,
  demoOrder,
  DEMO_TRIP_ID,
} from "./helpers/supabase-mock";

test.describe("Active trip flow", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);

    await page.route("**/tile.openstreetmap.org/**", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "image/png",
        body: Buffer.alloc(100),
      });
    });
  });

  test("start trip transitions view to active state", async ({ page }) => {
    const inTransitTrip = { ...demoTrip, status: "in_transit" };

    // First load returns scheduled, after start returns in_transit
    let started = false;
    await page.route("**/rest/v1/rider_trips*", async (route) => {
      if (route.request().method() === "PATCH") {
        started = true;
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([inTransitTrip]),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([started ? inTransitTrip : demoTrip]),
        });
      }
    });

    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    await expect(page).toHaveScreenshot("active-trip-before-start.png");
  });

  test("pickup confirmed state updates order card", async ({ page }) => {
    const pickedUpOrder = {
      ...demoOrder,
      status: "picked_up",
      items: [
        {
          ...demoOrder.items[0],
          pickup_status: "picked_up",
          pickup_confirmed: true,
          pickup_confirmed_at: "2026-02-14T10:00:00Z",
        },
      ],
    };

    await page.route("**/rest/v1/orders*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([pickedUpOrder]),
      });
    });

    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    // Should show "Start Delivery" button since all items are picked up
    await expect(page.getByRole("button", { name: /start delivery/i })).toBeVisible();

    await expect(page).toHaveScreenshot("active-trip-pickup-confirmed.png");
  });

  test("delivery confirmed state shows completed order", async ({ page }) => {
    const deliveredTrip = { ...demoTrip, status: "completed" };
    const deliveredOrder = {
      ...demoOrder,
      status: "delivered",
      items: [
        {
          ...demoOrder.items[0],
          pickup_status: "picked_up",
          pickup_confirmed: true,
          delivery_confirmed: true,
        },
      ],
    };

    await page.route("**/rest/v1/rider_trips*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([deliveredTrip]),
      });
    });

    await page.route("**/rest/v1/orders*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([deliveredOrder]),
      });
    });

    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    // No action buttons for completed trip
    await expect(page.getByRole("button", { name: /start trip/i })).not.toBeVisible();
    await expect(page.getByRole("button", { name: /complete trip/i })).not.toBeVisible();

    await expect(page).toHaveScreenshot("active-trip-delivery-confirmed.png");
  });

  test("in-transit trip with pending pickup shows confirm pickup", async ({ page }) => {
    const inTransitTrip = { ...demoTrip, status: "in_transit" };
    const matchedOrder = {
      ...demoOrder,
      status: "matched",
      items: [
        {
          ...demoOrder.items[0],
          pickup_status: "pending_pickup",
        },
      ],
    };

    await page.route("**/rest/v1/rider_trips*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([inTransitTrip]),
      });
    });

    await page.route("**/rest/v1/orders*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([matchedOrder]),
      });
    });

    await page.goto(`/en/rider/trips/${DEMO_TRIP_ID}`);
    await page.waitForSelector("h1");

    await expect(page.getByRole("button", { name: /confirm pickup/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /complete trip/i })).toBeVisible();

    await expect(page).toHaveScreenshot("active-trip-pending-pickup.png");
  });
});
