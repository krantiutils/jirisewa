import { test, expect } from "./fixtures/farmer";

test.describe("Create Produce Listing", () => {
  test("navigates to empty listing form and takes screenshot", async ({
    page,
  }) => {
    await page.goto("/en/farmer/listings/new");
    await page.waitForLoadState("networkidle");

    // Verify page title
    await expect(
      page.getByRole("heading", { name: "Add New Listing" }),
    ).toBeVisible();

    // Screenshot: empty listing form
    await expect(page).toHaveScreenshot("listing-form-empty.png", {
      fullPage: true,
    });

    // Verify all form fields are present
    await expect(page.getByText("Category")).toBeVisible();
    await expect(page.getByText("Name (English)")).toBeVisible();
    await expect(page.getByText("Name (Nepali)")).toBeVisible();
    await expect(page.getByText("Description")).toBeVisible();
    await expect(page.getByText("Price per kg (NPR)")).toBeVisible();
    await expect(page.getByText("Available Quantity (kg)")).toBeVisible();
    await expect(page.getByText("Freshness Date")).toBeVisible();
    await expect(page.getByText("Photos")).toBeVisible();

    // Verify submit and cancel buttons
    await expect(
      page.getByRole("button", { name: "Create Listing" }),
    ).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Cancel" }),
    ).toBeVisible();
  });

  test("fills form and creates a new listing", async ({ page }) => {
    await page.goto("/en/farmer/listings/new");
    await page.waitForLoadState("networkidle");

    // Select category (first option after placeholder)
    const categorySelect = page.locator("select").first();
    await categorySelect.selectOption({ index: 1 });

    // Fill name fields
    await page
      .getByPlaceholder("e.g. Fresh Tomatoes")
      .fill("E2E Test Spinach");
    await page
      .getByPlaceholder("e.g. ताजा गोलभेडा")
      .fill("E2E टेस्ट पालुंगो");

    // Fill description
    await page
      .getByPlaceholder("Describe your produce...")
      .fill("Fresh spinach grown for E2E testing purposes.");

    // Fill price
    await page.getByPlaceholder("0.00").fill("95");

    // Fill quantity
    await page.getByPlaceholder("0.0").fill("25");

    // Fill freshness date (today)
    const today = new Date().toISOString().split("T")[0];
    await page.locator('input[type="date"]').fill(today);

    // Screenshot: filled listing form before submission
    await expect(page).toHaveScreenshot("listing-form-filled.png", {
      fullPage: true,
    });

    // Submit the form
    await page.getByRole("button", { name: "Create Listing" }).click();

    // Should redirect to dashboard
    await page.waitForURL("**/farmer/dashboard");

    // Verify the new listing appears on the dashboard
    await expect(page.getByText("E2E Test Spinach")).toBeVisible();
    await expect(page.getByText("NPR 95/kg")).toBeVisible();

    // Screenshot: dashboard with newly created listing
    await expect(page).toHaveScreenshot("listing-created-confirmation.png", {
      fullPage: true,
    });
  });

  test("shows validation errors for empty required fields", async ({
    page,
  }) => {
    await page.goto("/en/farmer/listings/new");
    await page.waitForLoadState("networkidle");

    // Try to submit without filling required fields
    await page.getByRole("button", { name: "Create Listing" }).click();

    // Browser native validation should prevent submission
    // The category select is required and empty — browser will show validation popup
    // Check that we're still on the new listing page
    await expect(page).toHaveURL(/.*farmer\/listings\/new/);
  });

  test("cancel button returns to dashboard", async ({ page }) => {
    await page.goto("/en/farmer/listings/new");
    await page.waitForLoadState("networkidle");

    await page.getByRole("button", { name: "Cancel" }).click();
    await page.waitForURL("**/farmer/dashboard");
    await expect(
      page.getByRole("heading", { name: "Farmer Dashboard" }),
    ).toBeVisible();
  });
});
