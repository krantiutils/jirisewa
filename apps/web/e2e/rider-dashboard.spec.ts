import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  demoTrip,
} from "./helpers/supabase-mock";

test.describe("Rider dashboard", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays rider dashboard with title and post trip button", async ({ page }) => {
    await page.goto("/en/rider/dashboard");

    await expect(page.locator("h1")).toContainText("Rider Dashboard");
    await expect(page.getByRole("button", { name: /post a trip/i })).toBeVisible();

    await expect(page).toHaveScreenshot("rider-dashboard.png");
  });

  test("shows three tabs: upcoming, active, completed", async ({ page }) => {
    await page.goto("/en/rider/dashboard");

    await expect(page.getByText("Upcoming")).toBeVisible();
    await expect(page.getByText("Active")).toBeVisible();
    await expect(page.getByText("Completed")).toBeVisible();

    await expect(page).toHaveScreenshot("rider-dashboard-tabs.png");
  });

  test("upcoming tab shows trip cards with origin/destination", async ({ page }) => {
    await page.goto("/en/rider/dashboard");

    // Wait for trip data to load
    await page.waitForTimeout(1000);

    await expect(page.getByText("Jiri")).toBeVisible();
    await expect(page.getByText("Kathmandu")).toBeVisible();

    await expect(page).toHaveScreenshot("rider-dashboard-trips.png");
  });

  test("active tab shows empty state when no active trips", async ({ page }) => {
    // Override to return empty trips for in_transit
    await page.route("**/rest/v1/rider_trips*", async (route) => {
      const url = route.request().url();
      if (url.includes("in_transit")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([]),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([demoTrip]),
        });
      }
    });

    await page.goto("/en/rider/dashboard");

    // Switch to Active tab
    await page.getByText("Active").click();
    await page.waitForTimeout(500);

    await expect(page.getByText(/no trips/i)).toBeVisible();

    await expect(page).toHaveScreenshot("rider-dashboard-active-empty.png");
  });

  test("completed tab shows completed trips", async ({ page }) => {
    const completedTrip = {
      ...demoTrip,
      id: "completed-trip-1",
      status: "completed",
      origin_name: "Charikot",
      destination_name: "Dhulikhel",
    };

    await page.route("**/rest/v1/rider_trips*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([completedTrip]),
      });
    });

    await page.goto("/en/rider/dashboard");

    // Switch to Completed tab
    await page.getByText("Completed").click();
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot("rider-dashboard-completed.png");
  });
});
