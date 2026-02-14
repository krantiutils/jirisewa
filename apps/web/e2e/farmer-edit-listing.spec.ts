import { test, expect } from "./fixtures/farmer";

test.describe("Edit Produce Listing", () => {
  test("navigates to edit form with pre-filled data", async ({
    farmerDashboard: page,
  }) => {
    // Click edit button on first listing (Fresh Tomatoes)
    const editButtons = page.getByRole("link", { name: "Edit listing" });
    await expect(editButtons.first()).toBeVisible();
    await editButtons.first().click();

    // Should navigate to edit page
    await page.waitForURL("**/farmer/listings/*/edit");
    await page.waitForLoadState("networkidle");

    // Verify edit page title
    await expect(
      page.getByRole("heading", { name: "Edit Listing" }),
    ).toBeVisible();

    // Screenshot: pre-filled edit form
    await expect(page).toHaveScreenshot("listing-edit-form-prefilled.png", {
      fullPage: true,
    });

    // Verify fields are pre-populated with existing data
    await expect(page.getByPlaceholder("e.g. Fresh Tomatoes")).toHaveValue(
      "Fresh Tomatoes",
    );
    await expect(page.getByPlaceholder("e.g. ताजा गोलभेडा")).toHaveValue(
      "ताजा गोलभेडा",
    );
    await expect(page.getByPlaceholder("0.00")).toHaveValue("120");
    await expect(page.getByPlaceholder("0.0")).toHaveValue("50");

    // Verify Update button shows instead of Create
    await expect(
      page.getByRole("button", { name: "Update Listing" }),
    ).toBeVisible();
  });

  test("updates price and quantity, verifies changes persist", async ({
    farmerDashboard: page,
  }) => {
    // Navigate to edit form for first listing
    const editButtons = page.getByRole("link", { name: "Edit listing" });
    await editButtons.first().click();
    await page.waitForURL("**/farmer/listings/*/edit");
    await page.waitForLoadState("networkidle");

    // Change price
    const priceInput = page.getByPlaceholder("0.00");
    await priceInput.clear();
    await priceInput.fill("150");

    // Change quantity
    const qtyInput = page.getByPlaceholder("0.0");
    await qtyInput.clear();
    await qtyInput.fill("75");

    // Screenshot: form with updated values
    await expect(page).toHaveScreenshot("listing-edit-form-modified.png", {
      fullPage: true,
    });

    // Submit the update
    await page.getByRole("button", { name: "Update Listing" }).click();

    // Should redirect to dashboard
    await page.waitForURL("**/farmer/dashboard");

    // Verify updated values on dashboard
    await expect(page.getByText("NPR 150/kg")).toBeVisible();
    await expect(page.getByText("75 kg")).toBeVisible();

    // Screenshot: dashboard showing updated listing
    await expect(page).toHaveScreenshot("listing-edit-changes-persisted.png", {
      fullPage: true,
    });
  });
});
