import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
} from "./helpers/supabase-mock";

test.describe("Registration flow", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
  });

  test("step 1: profile — name, language, address fields", async ({ page }) => {
    await page.goto("/en/auth/register");

    // Wait for the form to render
    await page.waitForSelector("#name");

    await expect(page.locator("h1")).toContainText("Complete");
    await expect(page.getByText(/step 1/i)).toBeVisible();
    await expect(page.locator("#name")).toBeVisible();
    await expect(page.getByText("नेपाली")).toBeVisible();
    await expect(page.getByText("English")).toBeVisible();
    await expect(page.locator("#address")).toBeVisible();
    await expect(page.locator("#municipality")).toBeVisible();

    await expect(page).toHaveScreenshot("register-step1-profile.png");
  });

  test("step 2: role selection — farmer, consumer, rider", async ({ page }) => {
    await page.goto("/en/auth/register");
    await page.waitForSelector("#name");

    // Fill step 1
    await page.fill("#name", "Test User");
    await page.getByRole("button", { name: /next/i }).click();

    // Step 2 — role selection
    await expect(page.getByText(/step 2/i)).toBeVisible();
    await expect(page.getByText(/farmer/i).first()).toBeVisible();
    await expect(page.getByText(/consumer/i).first()).toBeVisible();
    await expect(page.getByText(/rider/i).first()).toBeVisible();

    await expect(page).toHaveScreenshot("register-step2-roles.png");
  });

  test("step 3: role-specific details for rider", async ({ page }) => {
    await page.goto("/en/auth/register");
    await page.waitForSelector("#name");

    // Step 1
    await page.fill("#name", "Test Rider");
    await page.getByRole("button", { name: /next/i }).click();

    // Step 2 — select rider role
    await page.getByText(/rider/i).first().click();
    await page.getByRole("button", { name: /next/i }).click();

    // Step 3 — rider-specific fields
    await expect(page.getByText(/step 3/i)).toBeVisible();
    await expect(page.getByText(/vehicle type/i)).toBeVisible();
    await expect(page.locator("#capacity")).toBeVisible();

    // Vehicle type grid should show bike, car, truck, bus, other
    await expect(page.getByText("Bike")).toBeVisible();
    await expect(page.getByText("Car")).toBeVisible();
    await expect(page.getByText("Truck")).toBeVisible();

    await expect(page).toHaveScreenshot("register-step3-rider-details.png");
  });

  test("step 3: role-specific details for farmer", async ({ page }) => {
    await page.goto("/en/auth/register");
    await page.waitForSelector("#name");

    // Step 1
    await page.fill("#name", "Test Farmer");
    await page.getByRole("button", { name: /next/i }).click();

    // Step 2 — select farmer role
    await page.getByText(/farmer/i).first().click();
    await page.getByRole("button", { name: /next/i }).click();

    // Step 3 — farmer-specific fields
    await expect(page.getByText(/step 3/i)).toBeVisible();
    await expect(page.locator("#farmName")).toBeVisible();

    await expect(page).toHaveScreenshot("register-step3-farmer-details.png");
  });

  test("validation: name is required before proceeding", async ({ page }) => {
    await page.goto("/en/auth/register");
    await page.waitForSelector("#name");

    // Try to go to step 2 without name
    await page.getByRole("button", { name: /next/i }).click();

    await expect(page.locator(".text-red-600")).toBeVisible();
    await expect(page).toHaveScreenshot("register-name-required.png");
  });

  test("validation: role must be selected before proceeding", async ({ page }) => {
    await page.goto("/en/auth/register");
    await page.waitForSelector("#name");

    await page.fill("#name", "Test User");
    await page.getByRole("button", { name: /next/i }).click();

    // Step 2 — try to proceed without selecting a role
    await page.getByRole("button", { name: /next/i }).click();

    await expect(page.locator(".text-red-600")).toBeVisible();
    await expect(page).toHaveScreenshot("register-role-required.png");
  });
});
