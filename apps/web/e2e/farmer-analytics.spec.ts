import { test, expect } from "./fixtures/farmer";

test.describe("Farmer Analytics Dashboard", () => {
  test("analytics page loads and displays all sections", async ({
    farmerDashboard: page,
  }) => {
    // Navigate to analytics from dashboard
    await page.getByRole("link", { name: /Analytics/i }).click();
    await page.waitForURL("**/farmer/analytics**");

    // Verify page title
    await expect(
      page.getByRole("heading", { name: "Analytics" }),
    ).toBeVisible();

    // Verify summary cards
    await expect(page.getByText("Total Revenue")).toBeVisible();
    await expect(page.getByText("Total Orders")).toBeVisible();
    await expect(page.getByText("Avg Rating")).toBeVisible();

    // Verify period selector
    await expect(page.getByRole("button", { name: "7 days" })).toBeVisible();
    await expect(page.getByRole("button", { name: "30 days" })).toBeVisible();
    await expect(page.getByRole("button", { name: "90 days" })).toBeVisible();

    // Verify chart sections exist
    await expect(
      page.getByRole("heading", { name: "Revenue Trend" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Sales by Category" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Top Products" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Fulfillment Rate" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Price Comparison" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Rating Breakdown" }),
    ).toBeVisible();

    // Screenshot: full analytics dashboard
    await expect(page).toHaveScreenshot("farmer-analytics-dashboard.png", {
      fullPage: true,
    });
  });

  test("period selector changes data range", async ({
    farmerDashboard: page,
  }) => {
    await page.getByRole("link", { name: /Analytics/i }).click();
    await page.waitForURL("**/farmer/analytics**");

    // Switch to 7 days
    await page.getByRole("button", { name: "7 days" }).click();
    await page.waitForURL("**/farmer/analytics?days=7");

    // Switch to 90 days
    await page.getByRole("button", { name: "90 days" }).click();
    await page.waitForURL("**/farmer/analytics?days=90");
  });
});
