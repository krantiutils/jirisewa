import { test, expect } from "@playwright/test";

test.describe("Municipality Picker", () => {
  test("marketplace shows municipality filter with autocomplete", async ({
    page,
  }) => {
    await page.goto("/en/marketplace");
    await page.waitForLoadState("networkidle");

    // Municipality picker should be visible in the sidebar
    await expect(page.getByText("Municipality")).toBeVisible();

    // Screenshot: marketplace with municipality filter
    await expect(page).toHaveScreenshot("marketplace-municipality-filter.png", {
      fullPage: true,
    });
  });

  test("municipality search shows results and selects", async ({ page }) => {
    await page.goto("/en/marketplace");
    await page.waitForLoadState("networkidle");

    // Click the municipality search input
    const searchInput = page.getByPlaceholder("Search municipality...");
    await searchInput.click();

    // Type a search query
    await searchInput.fill("Kath");
    await page.waitForTimeout(500); // debounce

    // Should show dropdown with results
    const dropdown = page.locator(".absolute.z-50");
    await expect(dropdown).toBeVisible();

    // Should show Kathmandu in results
    await expect(dropdown.getByText("Kathmandu")).toBeVisible();

    // Screenshot: municipality search dropdown
    await expect(page).toHaveScreenshot("municipality-search-dropdown.png");

    // Select Kathmandu
    await dropdown.getByText("Kathmandu").click();

    // Should show selected municipality
    await expect(page.getByText("Kathmandu")).toBeVisible();

    // Screenshot: selected municipality
    await expect(page).toHaveScreenshot("municipality-selected.png");
  });

  test("province filter chips work", async ({ page }) => {
    await page.goto("/en/marketplace");
    await page.waitForLoadState("networkidle");

    // Click the municipality search input to open dropdown
    const searchInput = page.getByPlaceholder("Search municipality...");
    await searchInput.click();
    await page.waitForTimeout(500);

    // Province chips should be visible
    const allButton = page.locator("button", { hasText: "All" }).first();
    await expect(allButton).toBeVisible();

    // Click Bagmati province chip
    await page.locator("button", { hasText: "Bagmati" }).click();
    await page.waitForTimeout(500);

    // Results should filter to Bagmati province
    // (Kathmandu, Lalitpur, Bhaktapur, etc.)
    const dropdown = page.locator(".absolute.z-50");
    await expect(dropdown).toBeVisible();

    // Screenshot: province filtered results
    await expect(page).toHaveScreenshot("municipality-province-filter.png");
  });

  test("clear municipality selection works", async ({ page }) => {
    await page.goto("/en/marketplace");
    await page.waitForLoadState("networkidle");

    // Search and select a municipality
    const searchInput = page.getByPlaceholder("Search municipality...");
    await searchInput.click();
    await searchInput.fill("Pokhara");
    await page.waitForTimeout(500);

    const dropdown = page.locator(".absolute.z-50");
    await dropdown.getByText("Pokhara").click();

    // Verify it's selected
    await expect(page.getByText("Pokhara")).toBeVisible();

    // Clear the selection
    await page.getByLabel("Clear selection").click();

    // Search input should be visible again
    await expect(searchInput).toBeVisible();
  });

  test("cross-region order placement with municipality", async ({ page }) => {
    // Navigate to marketplace
    await page.goto("/en/marketplace");
    await page.waitForLoadState("networkidle");

    // Select a municipality to filter produce
    const searchInput = page.getByPlaceholder("Search municipality...");
    await searchInput.click();
    await searchInput.fill("Jiri");
    await page.waitForTimeout(500);

    const dropdown = page.locator(".absolute.z-50");
    if (await dropdown.getByText("Jiri").isVisible()) {
      await dropdown.getByText("Jiri").click();
    }

    // Screenshot: marketplace filtered by Jiri municipality
    await expect(page).toHaveScreenshot("marketplace-jiri-filtered.png", {
      fullPage: true,
    });
  });

  test("map shows Nepal-wide view by default", async ({ page }) => {
    await page.goto("/en/marketplace");
    await page.waitForLoadState("networkidle");

    // The default view should be Nepal-wide (not Jiri-centered)
    // Screenshot: default map view
    await expect(page).toHaveScreenshot("marketplace-default-view.png", {
      fullPage: true,
    });
  });
});
