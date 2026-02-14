import { test, expect } from "./fixtures/farmer";
import {
  mockSupabaseRoutes,
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

test.describe("Farmer Subscription Plans", () => {
  test.beforeEach(async ({ page }) => {
    // Register mock routes for subscription_plans before the general mock
    await page.route("**/rest/v1/subscription_plans*", async (route) => {
      const method = route.request().method();
      if (method === "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([demoSubscriptionPlan]),
        });
      } else if (method === "POST") {
        await route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({ id: "new-plan-id" }),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({}),
        });
      }
    });

    await page.route("**/rest/v1/subscriptions*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([]),
      });
    });

    await mockSupabaseRoutes(page);
  });

  test("displays subscription plans management page", async ({
    farmerDashboard: page,
  }) => {
    await page.goto("/en/farmer/subscriptions");
    await page.waitForLoadState("networkidle");

    // Verify page title
    await expect(
      page.getByRole("heading", { name: "Subscription Plans" }),
    ).toBeVisible();

    // Verify plan card is visible
    await expect(page.getByText("Weekly Veggie Box")).toBeVisible();

    // Verify plan details
    await expect(page.getByText("NPR 500")).toBeVisible();
    await expect(page.getByText(/Vegetables/)).toBeVisible();
    await expect(page.getByText(/5kg/)).toBeVisible();

    // Screenshot
    await expect(page).toHaveScreenshot("farmer-subscription-plans.png", {
      fullPage: true,
    });
  });

  test("shows create plan form", async ({ farmerDashboard: page }) => {
    await page.goto("/en/farmer/subscriptions");
    await page.waitForLoadState("networkidle");

    // Click create plan button
    await page.getByRole("button", { name: /Create Plan/i }).click();

    // Verify form is visible
    await expect(page.getByText("New Subscription Plan")).toBeVisible();
    await expect(
      page.getByPlaceholder("e.g. Weekly Veggie Box"),
    ).toBeVisible();

    // Screenshot
    await expect(page).toHaveScreenshot(
      "farmer-subscription-create-form.png",
      { fullPage: true },
    );
  });
});
