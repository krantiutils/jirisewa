import { test, expect, type Page } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  DEMO_CONSUMER_ID,
  DEMO_FARMER_ID,
} from "./helpers/supabase-mock";

const DEMO_BUSINESS_ID = "cccccccc-0000-0000-0000-000000000001";
const DEMO_BULK_ORDER_ID = "dddddddd-0000-0000-0000-000000000001";

const demoBusinessProfile = {
  id: DEMO_BUSINESS_ID,
  user_id: DEMO_CONSUMER_ID,
  business_name: "Himalayan Kitchen",
  business_type: "restaurant",
  registration_number: "PAN-12345",
  address: "Thamel, Kathmandu",
  phone: "01-4123456",
  contact_person: "Ram Sharma",
  verified_at: null,
  created_at: "2026-02-14T00:00:00Z",
  updated_at: "2026-02-14T00:00:00Z",
};

const demoBulkOrder = {
  id: DEMO_BULK_ORDER_ID,
  business_id: DEMO_BUSINESS_ID,
  status: "submitted",
  delivery_address: "Thamel, Kathmandu",
  delivery_location: "POINT(85.3 27.7)",
  delivery_frequency: "weekly",
  delivery_schedule: null,
  total_amount: 5000,
  notes: "Need fresh produce every Monday morning",
  created_at: "2026-02-14T00:00:00Z",
  updated_at: "2026-02-14T00:00:00Z",
  items: [
    {
      id: "bulk-item-001",
      bulk_order_id: DEMO_BULK_ORDER_ID,
      produce_listing_id: "listing-001",
      farmer_id: DEMO_FARMER_ID,
      quantity_kg: 50,
      price_per_kg: 100,
      quoted_price_per_kg: null,
      status: "pending",
      farmer_notes: null,
      created_at: "2026-02-14T00:00:00Z",
      updated_at: "2026-02-14T00:00:00Z",
      listing: {
        name_en: "Fresh Tomatoes",
        name_ne: "ताजा गोलभेडा",
        photos: [],
      },
      farmer: {
        id: DEMO_FARMER_ID,
        name: "Demo Farmer",
        avatar_url: null,
      },
    },
  ],
  business: demoBusinessProfile,
};

async function mockBusinessRoutes(page: Page) {
  // Mock business_profiles
  await page.route("**/rest/v1/business_profiles*", async (route) => {
    const method = route.request().method();
    if (method === "GET") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(demoBusinessProfile),
      });
    } else if (method === "POST") {
      await route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify(demoBusinessProfile),
      });
    } else {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(demoBusinessProfile),
      });
    }
  });

  // Mock bulk_orders
  await page.route("**/rest/v1/bulk_orders*", async (route) => {
    const method = route.request().method();
    if (method === "GET") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([demoBulkOrder]),
      });
    } else if (method === "POST") {
      await route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify({ id: DEMO_BULK_ORDER_ID }),
      });
    } else {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(demoBulkOrder),
      });
    }
  });

  // Mock bulk_order_items
  await page.route("**/rest/v1/bulk_order_items*", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(demoBulkOrder.items),
    });
  });
}

test.describe("Business Registration", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays registration form", async ({ page }) => {
    // Return null for business profile (not registered)
    await page.route("**/rest/v1/business_profiles*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(null),
      });
    });

    await page.goto("/en/business/register");
    await page.waitForLoadState("networkidle");

    // Verify form elements
    await expect(
      page.getByRole("heading", { name: /Register Your Business/i }),
    ).toBeVisible();

    // Screenshot: registration form
    await expect(page).toHaveScreenshot("business-register-form.png", {
      fullPage: true,
    });

    // Verify business type options
    await expect(page.getByText("Restaurant")).toBeVisible();
    await expect(page.getByText("Hotel")).toBeVisible();
    await expect(page.getByText("Canteen")).toBeVisible();
  });
});

test.describe("Business Dashboard", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await mockBusinessRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays dashboard with profile and orders", async ({ page }) => {
    await page.goto("/en/business/dashboard");
    await page.waitForLoadState("networkidle");

    // Verify business name displays
    await expect(page.getByText("Himalayan Kitchen")).toBeVisible();

    // Verify stats cards
    await expect(page.getByText("Active Orders")).toBeVisible();
    await expect(page.getByText("Completed")).toBeVisible();
    await expect(page.getByText("Total Spent")).toBeVisible();

    // Screenshot: business dashboard
    await expect(page).toHaveScreenshot("business-dashboard.png", {
      fullPage: true,
    });
  });
});

test.describe("Bulk Order Creation", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await mockBusinessRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays new bulk order form", async ({ page }) => {
    await page.goto("/en/business/orders?action=new");
    await page.waitForLoadState("networkidle");

    // Verify form elements
    await expect(page.getByText("Create Bulk Order")).toBeVisible();
    await expect(page.getByPlaceholder(/Search for produce/i)).toBeVisible();

    // Verify frequency options
    await expect(page.getByText("One-time")).toBeVisible();
    await expect(page.getByText("Weekly")).toBeVisible();
    await expect(page.getByText("Biweekly")).toBeVisible();
    await expect(page.getByText("Monthly")).toBeVisible();

    // Screenshot: new order form
    await expect(page).toHaveScreenshot("business-new-order.png", {
      fullPage: true,
    });
  });
});

test.describe("Bulk Order Detail", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await mockBusinessRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays order detail with items", async ({ page }) => {
    await page.goto(`/en/business/orders/${DEMO_BULK_ORDER_ID}`);
    await page.waitForLoadState("networkidle");

    // Verify order detail header
    await expect(page.getByText("Bulk Order Detail")).toBeVisible();
    await expect(page.getByText("Submitted")).toBeVisible();

    // Verify delivery info
    await expect(page.getByText("Thamel, Kathmandu")).toBeVisible();
    await expect(page.getByText("Weekly")).toBeVisible();

    // Verify items
    await expect(page.getByText("Fresh Tomatoes")).toBeVisible();
    await expect(page.getByText("Demo Farmer")).toBeVisible();

    // Screenshot: order detail
    await expect(page).toHaveScreenshot("business-order-detail.png", {
      fullPage: true,
    });
  });
});
