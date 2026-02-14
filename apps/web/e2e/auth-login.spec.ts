import { test, expect } from "@playwright/test";
import { mockSupabaseRoutes, demoSession } from "./helpers/supabase-mock";

test.describe("Login page", () => {
  test.beforeEach(async ({ page }) => {
    await mockSupabaseRoutes(page);
  });

  test("displays login form with phone input", async ({ page }) => {
    await page.goto("/en/auth/login");
    await page.waitForSelector("#phone");

    await expect(page.locator("h1")).toContainText("Log in");
    await expect(page.locator("#phone")).toBeVisible();
    await expect(page.getByText("+977")).toBeVisible();

    await expect(page).toHaveScreenshot("login-phone-step.png");
  });

  test("shows validation error for invalid phone number", async ({ page }) => {
    await page.goto("/en/auth/login");
    await page.waitForSelector("#phone");

    await page.fill("#phone", "123");
    await page.getByRole("button", { name: /send otp/i }).click();

    await expect(page.locator(".text-red-600")).toBeVisible();
    await expect(page).toHaveScreenshot("login-invalid-phone.png");
  });

  test("transitions to OTP step after sending OTP", async ({ page }) => {
    await page.goto("/en/auth/login");
    await page.waitForSelector("#phone");

    await page.fill("#phone", "9800000001");

    const sendButton = page.getByRole("button", { name: /send otp/i });
    await expect(sendButton).toBeEnabled();
    await sendButton.click();

    // Wait for OTP step
    await page.waitForSelector('input[maxlength="6"]');

    await expect(page.locator("h1")).toContainText("Enter OTP");
    await expect(page.getByText("+9779800000001")).toBeVisible();
    await expect(page.getByText(/change phone/i)).toBeVisible();
    await expect(page.getByText(/resend/i)).toBeVisible();

    await expect(page).toHaveScreenshot("login-otp-step.png");
  });

  test("shows error for incorrect OTP", async ({ page }) => {
    // Override verify to fail
    await page.route("**/auth/v1/token*", async (route) => {
      const body = route.request().postDataJSON();
      if (body?.type === "phone" || body?.grant_type === "otp") {
        await route.fulfill({
          status: 400,
          contentType: "application/json",
          body: JSON.stringify({ error: "invalid_grant", error_description: "OTP expired" }),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(demoSession),
        });
      }
    });

    await page.goto("/en/auth/login");
    await page.waitForSelector("#phone");

    await page.fill("#phone", "9800000001");
    await page.getByRole("button", { name: /send otp/i }).click();

    await page.waitForSelector('input[maxlength="6"]');
    await page.fill('input[maxlength="6"]', "000000");
    await page.getByRole("button", { name: /verify/i }).click();

    await expect(page.locator(".text-red-600")).toBeVisible();
    await expect(page).toHaveScreenshot("login-otp-error.png");
  });
});
