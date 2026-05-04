/**
 * Drive every role on khetbata.xyz end-to-end:
 *   - customer  (email signup → onboarding → /customer marketplace)
 *   - farmer    (email signup → onboarding → /farmer/dashboard → create listing)
 *   - rider     (email signup → onboarding → /rider/dashboard)
 *   - admin     (email signup → service-role-promote is_admin → /admin)
 *   - hub       (login as seeded hub operator → /hub)
 *
 * Captures screenshots to apps/web/scripts/.runs/all-<timestamp>/<role>/.
 *
 * Run:
 *   pnpm --filter @jirisewa/web exec tsx scripts/drive-all-roles.ts
 *
 * Requires NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY in env so the
 * admin promotion step works. Reads from .env.local.prod if present.
 */
import { chromium, type Browser, type Page } from "@playwright/test";
import { createClient as createSupa } from "@supabase/supabase-js";
import fs from "node:fs";
import path from "node:path";

// Pull env from .env.local.prod if not already in shell
function loadEnvFile(p: string) {
  if (!fs.existsSync(p)) return;
  for (const line of fs.readFileSync(p, "utf8").split("\n")) {
    const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}
loadEnvFile(path.resolve(__dirname, "..", ".env.local.prod"));
loadEnvFile(path.resolve(__dirname, "..", ".env.local"));

const BASE_URL = process.env.BASE_URL ?? "https://khetbata.xyz";
const SUPA_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const RUN_ID = new Date().toISOString().replace(/[:.]/g, "-");
const RUN_DIR = path.resolve(__dirname, ".runs", `all-${RUN_ID}`);
const TS = Date.now();
const PASSWORD = "test-pw-jirisewa-2026";

interface ShotCtx { dir: string; n: number; }
const shot = async (page: Page, ctx: ShotCtx, name: string) => {
  ctx.n += 1;
  const filename = `${String(ctx.n).padStart(2, "0")}-${name}.png`;
  await page.screenshot({ path: path.join(ctx.dir, filename), fullPage: true });
};

async function newCtx(browser: Browser, role: string) {
  const dir = path.join(RUN_DIR, role);
  fs.mkdirSync(dir, { recursive: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await context.newPage();
  const errors: string[] = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("response", (r) => {
    if (r.status() >= 400 && !r.url().includes("favicon"))
      errors.push(`HTTP ${r.status()} ${r.url()}`);
  });
  return { context, page, ctx: { dir, n: 0 }, errors };
}

async function signUpEmail(page: Page, ctx: ShotCtx, email: string) {
  await page.goto(`${BASE_URL}/en/auth/login`, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => {});
  await shot(page, ctx, "login");
  await page.getByRole("button", { name: /^Email$/i }).first().click();
  await page.waitForTimeout(200);
  await page.getByRole("button", { name: /^Sign Up$/i }).first().click();
  await page.waitForTimeout(200);
  await page.locator('input[type="email"]').fill(email);
  const pw = page.locator('input[type="password"]');
  await pw.nth(0).fill(PASSWORD);
  if ((await pw.count()) > 1) await pw.nth(1).fill(PASSWORD);
  await shot(page, ctx, "signup-form");
  await page.getByRole("button", { name: /^Sign(?:ing)? Up$/i }).last().click();
  await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(2500);
  await shot(page, ctx, "after-signup");
}

async function pickRoleAndContinue(page: Page, ctx: ShotCtx, role: "Customer" | "Farmer" | "Rider", name: string) {
  if (!page.url().includes("/onboarding")) {
    await page.goto(`${BASE_URL}/en/onboarding`, { waitUntil: "domcontentloaded" });
    await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => {});
  }
  await page.locator("#fullName").fill(name);
  await page.locator("h3", { hasText: new RegExp(`^${role}$`, "i") }).first().click();
  await page.waitForTimeout(200);
  if (role === "Rider") {
    // pick the Bike vehicle type if visible
    const bike = page.getByRole("button", { name: /^Motorcycle|Bike$/i }).first();
    if (await bike.count()) await bike.click();
  }
  await shot(page, ctx, `onboarding-${role.toLowerCase()}`);
  await page.getByRole("button", { name: /^Continue$/i }).click();
  await page.waitForTimeout(3500);
  await shot(page, ctx, `after-continue-${role.toLowerCase()}`);
}

async function loginEmail(page: Page, ctx: ShotCtx, email: string, password: string) {
  await page.goto(`${BASE_URL}/en/auth/login`, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => {});
  await page.getByRole("button", { name: /^Email$/i }).first().click();
  await page.waitForTimeout(200);
  await page.locator('input[type="email"]').fill(email);
  await page.locator('input[type="password"]').first().fill(password);
  await shot(page, ctx, "login-filled");
  await page.getByRole("button", { name: /^Sign(?:ing)? In$/i }).last().click();
  await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(2500);
  await shot(page, ctx, "after-login");
}

async function main() {
  if (!SUPA_URL || !SERVICE_KEY) {
    throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in env");
  }
  fs.mkdirSync(RUN_DIR, { recursive: true });
  const admin = createSupa(SUPA_URL, SERVICE_KEY, { auth: { persistSession: false } });
  const browser = await chromium.launch({ headless: true });
  const summary: { role: string; finalUrl: string; errors: number }[] = [];

  // ─── Customer ──────────────────────────────────────────────
  {
    const { context, page, ctx, errors } = await newCtx(browser, "customer");
    const email = `e2e-customer-${TS}@jirisewa.test`;
    await signUpEmail(page, ctx, email);
    await pickRoleAndContinue(page, ctx, "Customer", "E2E Customer");
    await page.goto(`${BASE_URL}/en/marketplace`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(1500);
    await shot(page, ctx, "marketplace");
    summary.push({ role: "customer", finalUrl: page.url(), errors: errors.length });
    fs.writeFileSync(path.join(ctx.dir, "errors.json"), JSON.stringify(errors, null, 2));
    await context.close();
  }

  // ─── Farmer ────────────────────────────────────────────────
  let farmerEmail = "";
  {
    const { context, page, ctx, errors } = await newCtx(browser, "farmer");
    farmerEmail = `e2e-farmer-${TS}@jirisewa.test`;
    await signUpEmail(page, ctx, farmerEmail);
    await pickRoleAndContinue(page, ctx, "Farmer", "E2E Farmer");
    await page.goto(`${BASE_URL}/en/farmer/dashboard`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(2000);
    await shot(page, ctx, "farmer-dashboard");
    // Try to create a listing
    await page.goto(`${BASE_URL}/en/farmer/listings/new`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(1500);
    await shot(page, ctx, "new-listing-form");
    summary.push({ role: "farmer", finalUrl: page.url(), errors: errors.length });
    fs.writeFileSync(path.join(ctx.dir, "errors.json"), JSON.stringify(errors, null, 2));
    await context.close();
  }

  // ─── Rider ─────────────────────────────────────────────────
  {
    const { context, page, ctx, errors } = await newCtx(browser, "rider");
    const email = `e2e-rider-${TS}@jirisewa.test`;
    await signUpEmail(page, ctx, email);
    await pickRoleAndContinue(page, ctx, "Rider", "E2E Rider");
    await page.goto(`${BASE_URL}/en/rider/dashboard`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(2000);
    await shot(page, ctx, "rider-dashboard");
    summary.push({ role: "rider", finalUrl: page.url(), errors: errors.length });
    fs.writeFileSync(path.join(ctx.dir, "errors.json"), JSON.stringify(errors, null, 2));
    await context.close();
  }

  // ─── Admin (static jiri-admin user, provisioned by setup_admin_and_hub.sql) ─
  {
    const { context, page, ctx, errors } = await newCtx(browser, "admin");
    await loginEmail(page, ctx, "jiri-admin@jirisewa.local", "admin-pw");
    await page.goto(`${BASE_URL}/en/admin`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(2500);
    await shot(page, ctx, "admin-dashboard");
    await page.goto(`${BASE_URL}/en/admin/hubs`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(1500);
    await shot(page, ctx, "admin-hubs");
    await page.goto(`${BASE_URL}/en/admin/users`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(1500);
    await shot(page, ctx, "admin-users");
    summary.push({ role: "admin", finalUrl: page.url(), errors: errors.length });
    fs.writeFileSync(path.join(ctx.dir, "errors.json"), JSON.stringify(errors, null, 2));
    await context.close();
  }

  // ─── Hub operator (seeded user) ────────────────────────────
  {
    const { context, page, ctx, errors } = await newCtx(browser, "hub");
    await loginEmail(page, ctx, "jiri-hub-operator@jirisewa.local", "hub-operator-pw");
    await page.goto(`${BASE_URL}/en/hub`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(2500);
    await shot(page, ctx, "hub-dashboard");
    summary.push({ role: "hub_operator", finalUrl: page.url(), errors: errors.length });
    fs.writeFileSync(path.join(ctx.dir, "errors.json"), JSON.stringify(errors, null, 2));
    await context.close();
  }

  await browser.close();

  fs.writeFileSync(path.join(RUN_DIR, "summary.json"), JSON.stringify(summary, null, 2));
  console.log("\n=== Summary ===");
  summary.forEach((s) => {
    const tag = s.errors ? "⚠" : "✓";
    console.log(`${tag} ${s.role.padEnd(15)} → ${s.finalUrl}  (errors: ${s.errors})`);
  });
  console.log(`\nScreenshots: ${RUN_DIR}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
