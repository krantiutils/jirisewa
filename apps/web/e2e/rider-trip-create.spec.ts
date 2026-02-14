import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  mockOsrmRoutes,
  mockNominatim,
} from "./helpers/supabase-mock";

test.describe("Post a trip", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
    await mockOsrmRoutes(page);
    await mockNominatim(page);

    // Mock tile server to avoid external network requests
    await page.route("**/tile.openstreetmap.org/**", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "image/png",
        body: Buffer.alloc(100), // 1x1 blank PNG placeholder
      });
    });
  });

  test("displays trip form with step indicator and origin map", async ({ page }) => {
    await page.goto("/en/rider/trips/new");

    await expect(page.locator("h1")).toContainText("Post a Trip");
    await expect(page.getByText(/where are you starting/i)).toBeVisible();
    await expect(page.getByText(/tap the map/i)).toBeVisible();

    // Next button should be disabled until origin is selected
    const nextButton = page.getByRole("button", { name: /next/i });
    await expect(nextButton).toBeDisabled();

    await expect(page).toHaveScreenshot("trip-form-step1-origin.png");
  });

  test("step 2: destination selection", async ({ page }) => {
    await page.goto("/en/rider/trips/new");

    // Click on the map to select origin
    const mapContainer = page.locator(".leaflet-container").first();
    await mapContainer.waitFor();
    await mapContainer.click({ position: { x: 200, y: 200 } });

    // Wait for geocoding response
    await page.waitForTimeout(500);

    // Proceed to destination
    await page.getByRole("button", { name: /next/i }).click();

    await expect(page.getByText(/where are you heading/i)).toBeVisible();

    await expect(page).toHaveScreenshot("trip-form-step2-destination.png");
  });

  test("step 3: trip details with date, time, capacity, vehicle type", async ({ page }) => {
    await page.goto("/en/rider/trips/new");

    // Select origin
    const mapContainer = page.locator(".leaflet-container").first();
    await mapContainer.waitFor();
    await mapContainer.click({ position: { x: 200, y: 200 } });
    await page.waitForTimeout(500);
    await page.getByRole("button", { name: /next/i }).click();

    // Select destination
    await page.waitForTimeout(300);
    const destMap = page.locator(".leaflet-container").first();
    await destMap.click({ position: { x: 300, y: 150 } });
    await page.waitForTimeout(500);
    await page.getByRole("button", { name: /next/i }).click();

    // Step 3: details form
    await expect(page.getByText(/trip details/i)).toBeVisible();
    await expect(page.getByText(/departure date/i)).toBeVisible();
    await expect(page.getByText(/departure time/i)).toBeVisible();
    await expect(page.getByText(/available capacity/i)).toBeVisible();
    await expect(page.getByText(/vehicle type/i)).toBeVisible();

    await expect(page).toHaveScreenshot("trip-form-step3-details.png");
  });

  test("step 3: validation rejects empty fields", async ({ page }) => {
    await page.goto("/en/rider/trips/new");

    // Skip through origin and destination
    const mapContainer = page.locator(".leaflet-container").first();
    await mapContainer.waitFor();
    await mapContainer.click({ position: { x: 200, y: 200 } });
    await page.waitForTimeout(500);
    await page.getByRole("button", { name: /next/i }).click();
    await page.waitForTimeout(300);
    const destMap = page.locator(".leaflet-container").first();
    await destMap.click({ position: { x: 300, y: 150 } });
    await page.waitForTimeout(500);
    await page.getByRole("button", { name: /next/i }).click();

    // Try to proceed to review without filling fields
    await page.getByRole("button", { name: /review/i }).click();

    // Should show error
    await expect(page.locator(".text-red-700")).toBeVisible();
    await expect(page).toHaveScreenshot("trip-form-validation-error.png");
  });

  test("step 4: review shows trip summary before submission", async ({ page }) => {
    await page.goto("/en/rider/trips/new");

    // Select origin
    const mapContainer = page.locator(".leaflet-container").first();
    await mapContainer.waitFor();
    await mapContainer.click({ position: { x: 200, y: 200 } });
    await page.waitForTimeout(500);
    await page.getByRole("button", { name: /next/i }).click();

    // Select destination
    await page.waitForTimeout(300);
    const destMap = page.locator(".leaflet-container").first();
    await destMap.click({ position: { x: 300, y: 150 } });
    await page.waitForTimeout(500);
    await page.getByRole("button", { name: /next/i }).click();

    // Fill details
    await page.fill('input[type="date"]', "2026-02-20");
    await page.fill('input[type="time"]', "08:00");
    await page.fill('input[type="number"]', "50");

    await page.getByRole("button", { name: /review/i }).click();

    // Review step
    await expect(page.getByText(/review your trip/i)).toBeVisible();
    await expect(page.getByText("50 kg")).toBeVisible();
    await expect(page.getByText("2026-02-20")).toBeVisible();
    await expect(page.getByRole("button", { name: /post trip/i })).toBeVisible();

    await expect(page).toHaveScreenshot("trip-form-step4-review.png");
  });
});
