/**
 * Capture demo screenshots for the Jiri municipality deck.
 *
 *   cd apps/web && npx tsx scripts/capture-demo-shots.ts
 *
 * Output: docs/demo/screenshots/web/<slug>.png at repo root
 *
 * Demo users (seeded into local Supabase by 002_jiri_bazaar_hub.sql + ad-hoc):
 *   farmer@ff.com / demo-pw-1234           — farmer + admin
 *   jiri-hub-operator@jirisewa.local / demo-pw-1234 — hub operator
 */

import { chromium, type BrowserContext, type Page } from "@playwright/test";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const BASE = process.env.BASE_URL ?? "http://localhost:3000";
const OUT = resolve(__dirname, "../../../docs/demo/screenshots/web");

interface Shot {
  slug: string;
  path: string;
  wait?: number;
  fullPage?: boolean;
}

/**
 * Drive the email login form in the actual UI to set httpOnly session cookies
 * via @supabase/ssr. localStorage-based session injection doesn't work here.
 */
async function loginAs(ctx: BrowserContext, email: string, password: string) {
  const page = await ctx.newPage();
  await page.goto(`${BASE}/en/auth/login`, { waitUntil: "networkidle" });
  // Switch to Email tab.
  await page.getByRole("button", { name: /email/i }).first().click();
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  await page.getByRole("button", { name: /^sign in$/i }).click();
  // Wait for navigation away from login or for an authenticated cookie.
  await page.waitForURL((url) => !url.pathname.includes("/auth/login"), { timeout: 15_000 }).catch(() => {});
  await page.waitForTimeout(1500);
  await page.close();
}

async function shot(page: Page, s: Shot, suffix = "") {
  console.log(`  capturing ${s.slug}${suffix} → ${s.path}`);
  try {
    await page.goto(`${BASE}${s.path}`, { waitUntil: "networkidle", timeout: 20_000 });
  } catch (e) {
    console.warn(`    timeout: ${(e as Error).message}`);
  }
  await page.waitForTimeout(s.wait ?? 2500);
  await page.evaluate(() => {
    const overlay = document.querySelector("nextjs-portal");
    if (overlay) (overlay as HTMLElement).style.display = "none";
  });
  await page.screenshot({ path: `${OUT}/${s.slug}${suffix}.png`, fullPage: s.fullPage ?? true });
}

async function main() {
  await mkdir(OUT, { recursive: true });
  const browser = await chromium.launch();

  // ── Public / anonymous shots ────────────────────────────────────────────
  console.log("Public shots:");
  {
    const ctx = await browser.newContext({
      viewport: { width: 1280, height: 800 },
      deviceScaleFactor: 2,
    });
    const page = await ctx.newPage();
    const PUBLIC: Shot[] = [
      { slug: "01-landing", path: "/en" },
      { slug: "02-marketplace", path: "/en/marketplace" },
      { slug: "03-login", path: "/en/auth/login" },
    ];
    for (const s of PUBLIC) await shot(page, s);

    // First produce listing detail
    await page.goto(`${BASE}/en/marketplace`, { waitUntil: "networkidle" }).catch(() => {});
    const firstHref = await page.locator('a[href*="/produce/"]').first().getAttribute("href").catch(() => null);
    if (firstHref) {
      await shot(page, { slug: "04-produce-detail", path: firstHref });
    }

    await ctx.close();
  }

  // ── Farmer + admin shots ───────────────────────────────────────────────
  console.log("Farmer/admin shots:");
  {
    const ctx = await browser.newContext({
      viewport: { width: 1280, height: 800 },
      deviceScaleFactor: 2,
    });
    await loginAs(ctx, "farmer@ff.com", "demo-pw-1234");
    const page = await ctx.newPage();
    const FARMER: Shot[] = [
      { slug: "10-farmer-dashboard", path: "/en/farmer/dashboard" },
      { slug: "11-farmer-listings-new", path: "/en/farmer/listings/new" },
      { slug: "12-farmer-orders", path: "/en/farmer/orders" },
      { slug: "13-farmer-analytics", path: "/en/farmer/analytics", wait: 2000 },
      { slug: "14-farmer-hubs-dropoff", path: "/en/farmer/hubs" },
      { slug: "20-admin-hubs", path: "/en/admin/hubs" },
      { slug: "21-admin-hubs-new", path: "/en/admin/hubs/new" },
      { slug: "22-admin-users", path: "/en/admin/users" },
      { slug: "23-admin-orders", path: "/en/admin/orders" },
      { slug: "24-admin-dashboard", path: "/en/admin" },
    ];
    for (const s of FARMER) await shot(page, s);

    // Drive the dropoff form to completion: select first listing, type qty, submit.
    try {
      await page.goto(`${BASE}/en/farmer/hubs`, { waitUntil: "networkidle" });
      await page.fill('[data-testid="dropoff-qty"]', "5");
      await page.click('[data-testid="dropoff-submit"]');
      await page.waitForSelector('[data-testid="dropoff-success"]', { timeout: 10_000 });
      await shot(page, { slug: "15-farmer-hubs-success", path: "/en/farmer/hubs", wait: 500 });
    } catch (e) {
      console.warn(`  dropoff submit failed: ${(e as Error).message}`);
    }

    await ctx.close();
  }

  // ── Hub operator shots ─────────────────────────────────────────────────
  console.log("Hub operator shots:");
  {
    const ctx = await browser.newContext({
      viewport: { width: 1280, height: 800 },
      deviceScaleFactor: 2,
    });
    await loginAs(ctx, "jiri-hub-operator@jirisewa.local", "demo-pw-1234");
    const page = await ctx.newPage();
    await shot(page, { slug: "30-hub-inventory", path: "/en/hub" });
    await shot(page, { slug: "31-hub-inventory-dropped-off", path: "/en/hub?status=dropped_off" });
    await shot(page, { slug: "32-hub-inventory-in-inventory", path: "/en/hub?status=in_inventory" });
    await ctx.close();
  }

  await browser.close();
  console.log(`Done. Output → ${OUT}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
