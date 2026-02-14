import { test, expect } from "./fixtures/farmer";

test.describe("Farmer Dashboard", () => {
  test("displays dashboard with stats and listings", async ({
    farmerDashboard: page,
  }) => {
    // Verify dashboard title
    await expect(
      page.getByRole("heading", { name: "Farmer Dashboard" }),
    ).toBeVisible();

    // Screenshot: full farmer dashboard
    await expect(page).toHaveScreenshot("farmer-dashboard.png", {
      fullPage: true,
    });

    // Verify stats cards
    await expect(page.getByText("Active Listings")).toBeVisible();
    await expect(page.getByText("Pending Orders")).toBeVisible();
    await expect(page.getByText("Total Earnings")).toBeVisible();

    // Verify active listing count is at least 2 (from seed data)
    const activeListingsCard = page
      .locator("div")
      .filter({ hasText: "Active Listings" })
      .first();
    await expect(activeListingsCard).toBeVisible();

    // Verify "My Listings" section
    await expect(
      page.getByRole("heading", { name: "My Listings" }),
    ).toBeVisible();

    // Verify seeded listings appear
    await expect(page.getByText("Fresh Tomatoes")).toBeVisible();
    await expect(page.getByText("Organic Potatoes")).toBeVisible();

    // Verify listing details: price and quantity visible
    await expect(page.getByText("NPR 120/kg")).toBeVisible();
    await expect(page.getByText("50 kg")).toBeVisible();

    // Verify Add Listing button
    await expect(
      page.getByRole("link", { name: /Add Listing/i }),
    ).toBeVisible();
  });

  test("shows active and inactive listing badges", async ({
    farmerDashboard: page,
  }) => {
    // Active listings should show "Active" badge
    const activeListings = page.getByText("Active", { exact: true });
    await expect(activeListings.first()).toBeVisible();

    // Inactive listing (Purple Onions from seed) should show "Inactive" badge
    await expect(page.getByText("Purple Onions")).toBeVisible();
    await expect(page.getByText("Inactive")).toBeVisible();

    // Screenshot: listings with badges
    await expect(page).toHaveScreenshot("farmer-dashboard-listing-badges.png", {
      fullPage: true,
    });
  });

  test("Add Listing button navigates to new listing form", async ({
    farmerDashboard: page,
  }) => {
    await page.getByRole("link", { name: /Add Listing/i }).first().click();
    await page.waitForURL("**/farmer/listings/new");
    await expect(
      page.getByRole("heading", { name: "Add New Listing" }),
    ).toBeVisible();
  });
});
