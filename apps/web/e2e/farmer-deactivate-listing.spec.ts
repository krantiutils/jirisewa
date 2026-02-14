import { test, expect } from "./fixtures/farmer";

test.describe("Deactivate Listing", () => {
  test("toggles listing from active to inactive", async ({
    farmerDashboard: page,
  }) => {
    // Find an active listing card (Fresh Tomatoes)
    const tomatoCard = page
      .locator("div")
      .filter({ hasText: "Fresh Tomatoes" })
      .filter({ hasText: "Active" })
      .first();
    await expect(tomatoCard).toBeVisible();

    // Click the deactivate toggle button on the first active listing
    const deactivateButton = page
      .getByRole("button", { name: "Deactivate listing" })
      .first();
    await expect(deactivateButton).toBeVisible();
    await deactivateButton.click();

    // Wait for the server action to complete and page to revalidate
    await page.waitForLoadState("networkidle");

    // The listing should now show "Inactive" badge
    // Screenshot: deactivated listing state
    await expect(page).toHaveScreenshot("listing-deactivated-state.png", {
      fullPage: true,
    });

    // Verify the listing now shows an "Activate listing" button
    const activateButton = page
      .getByRole("button", { name: "Activate listing" });
    await expect(activateButton.first()).toBeVisible();
  });

  test("toggles listing from inactive back to active", async ({
    farmerDashboard: page,
  }) => {
    // Purple Onions is seeded as inactive
    const onionCard = page
      .locator("div")
      .filter({ hasText: "Purple Onions" })
      .first();
    await expect(onionCard).toBeVisible();

    // Click the activate toggle button for the inactive listing
    const activateButton = page
      .getByRole("button", { name: "Activate listing" })
      .first();
    await expect(activateButton).toBeVisible();
    await activateButton.click();

    // Wait for the toggle action to complete
    await page.waitForLoadState("networkidle");

    // Verify it now shows as active
    await expect(page).toHaveScreenshot("listing-reactivated-state.png", {
      fullPage: true,
    });
  });

  test("deactivated listing is not visible in marketplace", async ({
    farmerDashboard: page,
  }) => {
    // Verify there's at least one inactive listing on the dashboard
    await expect(page.getByText("Inactive")).toBeVisible();

    // Navigate to marketplace to verify the inactive listing doesn't appear
    await page.goto("/en/marketplace");
    await page.waitForLoadState("networkidle");

    // Purple Onions (seeded as inactive) should NOT appear in the marketplace
    await expect(page.getByText("Purple Onions")).not.toBeVisible();

    // Screenshot: marketplace without the deactivated listing
    await expect(page).toHaveScreenshot("marketplace-no-inactive-listings.png", {
      fullPage: true,
    });
  });
});
