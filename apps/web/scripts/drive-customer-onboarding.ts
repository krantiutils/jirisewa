/**
 * Drive the customer onboarding flow on khetbata.xyz end-to-end via email
 * signup (avoids SMS), and capture what happens when a fresh user clicks
 * the Customer role tile and presses Continue.
 *
 * Run: pnpm exec tsx apps/web/scripts/drive-customer-onboarding.ts
 */
import { chromium, type ConsoleMessage, type Response } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";

const BASE_URL = process.env.BASE_URL ?? "https://khetbata.xyz";
const RUN_ID = new Date().toISOString().replace(/[:.]/g, "-");
const OUT_DIR = path.resolve(__dirname, ".runs", `customer-${RUN_ID}`);
fs.mkdirSync(OUT_DIR, { recursive: true });

const TEST_EMAIL = `e2e-customer-${Date.now()}@jirisewa.test`;
const TEST_PW = "test-password-jirisewa-2026";
const TEST_NAME = "E2E Customer";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await context.newPage();

  const consoleErrors: string[] = [];
  const networkFails: { url: string; status: number; text: string }[] = [];
  page.on("console", (m: ConsoleMessage) => {
    if (m.type() === "error") consoleErrors.push(m.text());
  });
  page.on("response", async (r: Response) => {
    if (r.status() >= 400 && !r.url().includes("favicon")) {
      networkFails.push({ url: r.url(), status: r.status(), text: r.statusText() });
    }
  });

  const screenshot = async (name: string) => {
    await page.screenshot({ path: path.join(OUT_DIR, `${name}.png`), fullPage: true });
  };

  console.log(`testEmail=${TEST_EMAIL}`);

  // 1. Login page (English locale for stable selectors)
  await page.goto(`${BASE_URL}/en/auth/login`, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => {});
  await screenshot("01-login");

  // 2. Switch to Email tab (the second tab pill)
  await page.getByRole("button", { name: /^Email$/i }).first().click();
  await page.waitForTimeout(300);
  await screenshot("02-email-tab");

  // 3. Switch to Sign Up mode (the small "Sign Up" link under the form)
  await page.getByRole("button", { name: /^Sign Up$/i }).first().click();
  await page.waitForTimeout(300);
  await screenshot("03-signup-mode");

  // 4. Fill email + password + confirm password
  await page.locator('input[type="email"]').fill(TEST_EMAIL);
  const pwInputs = page.locator('input[type="password"]');
  await pwInputs.nth(0).fill(TEST_PW);
  if ((await pwInputs.count()) > 1) {
    await pwInputs.nth(1).fill(TEST_PW);
  }
  await screenshot("04-form-filled");

  // 5. Submit (the big "Sign Up" submit button — last of two buttons named Sign Up)
  const submitBtns = page.getByRole("button", { name: /^Sign(?:ing)? Up$/i });
  await submitBtns.last().click();
  await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(2500);
  await screenshot("05-after-signup-submit");
  console.log("after signup, url:", page.url());

  // 6. If we're not on onboarding yet, navigate there directly
  if (!page.url().includes("/onboarding")) {
    await page.goto(`${BASE_URL}/en/onboarding`, { waitUntil: "domcontentloaded" });
    await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => {});
  }
  await screenshot("06-onboarding-page");
  console.log("onboarding url:", page.url());

  // 7. Fill name
  const nameInput = page.locator('#fullName');
  if (await nameInput.count()) {
    await nameInput.fill(TEST_NAME);
  }
  await screenshot("07-name-filled");

  // 8. Click the Customer role tile (h3 within a Card)
  await page.locator('h3', { hasText: /Customer/i }).first().click();
  await page.waitForTimeout(300);
  await screenshot("08-customer-selected");

  // 9. Click Continue
  await page.getByRole("button", { name: /^Continue$/i }).click();
  await page.waitForTimeout(3500);
  await screenshot("09-after-continue");

  console.log("final url after continue:", page.url());

  // 10. Look for any error banner
  const errorBanner = page.locator('.bg-red-50, [class*="text-red"]').first();
  if (await errorBanner.count()) {
    const errText = await errorBanner.innerText().catch(() => "");
    console.log("error banner text:", errText);
  } else {
    console.log("no visible error banner");
  }

  await browser.close();

  fs.writeFileSync(
    path.join(OUT_DIR, "log.json"),
    JSON.stringify({ consoleErrors, networkFails, finalUrl: page.url() }, null, 2),
  );

  console.log("\n=== console errors ===");
  consoleErrors.forEach((e) => console.log("  ", e));
  console.log("\n=== network 4xx/5xx ===");
  networkFails.forEach((f) => console.log(`  ${f.status} ${f.url}`));

  console.log(`\nScreenshots: ${OUT_DIR}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
