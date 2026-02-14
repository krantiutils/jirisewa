import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  DEMO_CONSUMER_ID,
  DEMO_FARMER_ID,
} from "./helpers/supabase-mock";

const demoSubscriptionPlan = {
  id: "cccccccc-0000-0000-0000-000000000001",
  farmer_id: DEMO_FARMER_ID,
  name_en: "Weekly Veggie Box",
  name_ne: "हप्ताको तरकारी बाकस",
  description_en: "Fresh seasonal vegetables every week",
  description_ne: "हरेक हप्ता ताजा मौसमी तरकारी",
  price: 500,
  frequency: "weekly",
  items: [
    { category_en: "Vegetables", category_ne: "तरकारी", approx_kg: 5 },
    { category_en: "Herbs", category_ne: "जडिबुटी", approx_kg: 0.5 },
  ],
  max_subscribers: 50,
  delivery_day: 6,
  is_active: true,
  created_at: "2026-02-14T00:00:00Z",
  updated_at: "2026-02-14T00:00:00Z",
};

const demoFarmer = {
  id: DEMO_FARMER_ID,
  name: "Demo Farmer",
  avatar_url: null,
  rating_avg: 4.5,
  rating_count: 12,
};

test.describe("Consumer Subscription Browse", () => {
  test.beforeEach(async ({ page }) => {
    // Mock subscription plans
    await page.route("**/rest/v1/subscription_plans*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([demoSubscriptionPlan]),
      });
    });

    // Mock subscriptions (none yet)
    await page.route("**/rest/v1/subscriptions*", async (route) => {
      const method = route.request().method();
      if (method === "POST") {
        await route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({
            id: "new-sub-id",
            plan_id: demoSubscriptionPlan.id,
            consumer_id: DEMO_CONSUMER_ID,
            status: "active",
            next_delivery_date: "2026-02-21",
          }),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([]),
        });
      }
    });

    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays subscription browse page with available plans", async ({
    page,
  }) => {
    await page.goto("/en/subscriptions");
    await page.waitForLoadState("networkidle");

    // Verify page title
    await expect(
      page.getByRole("heading", { name: "Subscription Boxes" }),
    ).toBeVisible();

    // Verify subtitle
    await expect(
      page.getByText("Fresh produce delivered to your door every week"),
    ).toBeVisible();

    // Verify tabs
    await expect(page.getByText("Browse Plans")).toBeVisible();
    await expect(page.getByText("My Subscriptions")).toBeVisible();

    // Verify plan card
    await expect(page.getByText("Weekly Veggie Box")).toBeVisible();
    await expect(page.getByText("NPR 500")).toBeVisible();
    await expect(page.getByText(/Vegetables/)).toBeVisible();

    // Screenshot: browse page
    await expect(page).toHaveScreenshot("subscription-browse.png", {
      fullPage: true,
    });
  });

  test("shows empty state on My Subscriptions tab", async ({ page }) => {
    await page.goto("/en/subscriptions");
    await page.waitForLoadState("networkidle");

    // Switch to My Subscriptions tab
    await page.getByText("My Subscriptions").click();

    // Verify empty state
    await expect(
      page.getByText("You have no active subscriptions."),
    ).toBeVisible();

    // Screenshot: empty subscriptions
    await expect(page).toHaveScreenshot("subscription-my-empty.png", {
      fullPage: true,
    });
  });
});
