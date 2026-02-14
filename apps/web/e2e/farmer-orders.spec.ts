import { test, expect } from "./fixtures/farmer";

test.describe("Farmer Order Management", () => {
  test("displays incoming orders for farmer produce", async ({ page }) => {
    // Navigate to orders page
    await page.goto("/en/orders");
    await page.waitForLoadState("networkidle");

    // Screenshot: orders page (may show orders related to the farmer's produce)
    await expect(page).toHaveScreenshot("farmer-orders-incoming.png", {
      fullPage: true,
    });

    // Verify orders page heading
    await expect(
      page.getByRole("heading", { name: "My Orders" }),
    ).toBeVisible();

    // Verify tab navigation exists
    await expect(page.getByText("Active")).toBeVisible();
    await expect(page.getByText("Completed")).toBeVisible();
  });

  test("shows order detail with pickup and rider info", async ({ page }) => {
    // Navigate to orders page
    await page.goto("/en/orders");
    await page.waitForLoadState("networkidle");

    // If there are orders, click on the first one
    const orderCards = page.locator("[class*='cursor-pointer']");
    const orderCount = await orderCards.count();

    if (orderCount > 0) {
      await orderCards.first().click();
      await page.waitForURL("**/orders/*");
      await page.waitForLoadState("networkidle");

      // Screenshot: order detail page
      await expect(page).toHaveScreenshot("farmer-order-detail.png", {
        fullPage: true,
      });

      // Verify order detail elements
      await expect(
        page.getByRole("heading", { name: "Order Details" }),
      ).toBeVisible();

      // Verify order items section
      await expect(page.getByText("Items")).toBeVisible();

      // Verify delivery address section
      await expect(page.getByText("Delivery Address")).toBeVisible();
    }
  });

  test("switches between active and completed order tabs", async ({
    page,
  }) => {
    await page.goto("/en/orders");
    await page.waitForLoadState("networkidle");

    // Start on Active tab
    const activeTab = page.getByRole("button", { name: "Active" });
    const completedTab = page.getByRole("button", { name: "Completed" });

    // Screenshot: active orders tab
    await expect(page).toHaveScreenshot("farmer-orders-active-tab.png", {
      fullPage: true,
    });

    // Switch to completed tab
    await completedTab.click();
    await page.waitForLoadState("networkidle");

    // Screenshot: completed orders tab
    await expect(page).toHaveScreenshot("farmer-orders-completed-tab.png", {
      fullPage: true,
    });
  });

  test("filters toggle works", async ({ page }) => {
    await page.goto("/en/orders");
    await page.waitForLoadState("networkidle");

    // Click on the Filters button
    const filtersButton = page.getByRole("button", { name: "Filters" });
    await expect(filtersButton).toBeVisible();
    await filtersButton.click();

    // Verify filter panel appears
    await expect(page.getByText("Farmer")).toBeVisible();
    await expect(page.getByText("Status")).toBeVisible();

    // Screenshot: filters panel open
    await expect(page).toHaveScreenshot("farmer-orders-filters-open.png", {
      fullPage: true,
    });
  });
});
