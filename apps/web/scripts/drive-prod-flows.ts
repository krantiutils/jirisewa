/**
 * Drive end-to-end flows on khetbata.xyz from a real Chromium browser.
 * Captures a screenshot per step into apps/web/scripts/.runs/<timestamp>/
 * and writes any console errors / network failures to errors.json.
 *
 * Run:  pnpm tsx apps/web/scripts/drive-prod-flows.ts
 *
 * What this drives:
 *  - /ne                   landing page renders
 *  - /ne/marketplace       public produce browse
 *  - /ne/auth/login        login form (phone + OTP). OTP can't be entered
 *                          without an SMS, so we go up to the OTP screen
 *                          and stop, but report what we saw.
 *  - /ne/onboarding        what an unauthed visitor sees (should redirect)
 *  - /ne/farmer/dashboard  what an unauthed visitor sees
 *  - /ne/admin             what an unauthed visitor sees
 *
 * Future: when test users are pre-provisioned via service role, this
 * script can use storageState to skip OTP and drive the full role flows.
 */
import { chromium, type Page, type ConsoleMessage, type Response } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";

const BASE_URL = process.env.BASE_URL ?? "https://khetbata.xyz";
const RUN_ID = new Date().toISOString().replace(/[:.]/g, "-");
const OUT_DIR = path.resolve(__dirname, ".runs", RUN_ID);
fs.mkdirSync(OUT_DIR, { recursive: true });

interface StepResult {
  name: string;
  url: string;
  finalUrl: string;
  status: number | null;
  consoleErrors: string[];
  networkFailures: { url: string; status: number; statusText: string }[];
  screenshot: string;
}

async function captureStep(
  page: Page,
  name: string,
  navigate: () => Promise<void>,
): Promise<StepResult> {
  const consoleErrors: string[] = [];
  const networkFailures: StepResult["networkFailures"] = [];

  const onConsole = (msg: ConsoleMessage) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  };
  const onResponse = async (resp: Response) => {
    if (resp.status() >= 400 && !resp.url().includes("favicon")) {
      networkFailures.push({
        url: resp.url(),
        status: resp.status(),
        statusText: resp.statusText(),
      });
    }
  };

  page.on("console", onConsole);
  page.on("response", onResponse);

  let status: number | null = null;
  await navigate().then(
    () => { /* ok */ },
    (e) => consoleErrors.push("navigate error: " + (e as Error).message),
  );

  try {
    await page.waitForLoadState("networkidle", { timeout: 8000 });
  } catch {
    /* timed out - still capture */
  }

  const screenshotPath = path.join(OUT_DIR, `${name}.png`);
  await page.screenshot({ path: screenshotPath, fullPage: true });

  page.off("console", onConsole);
  page.off("response", onResponse);

  return {
    name,
    url: page.url(),
    finalUrl: page.url(),
    status,
    consoleErrors,
    networkFailures,
    screenshot: path.relative(process.cwd(), screenshotPath),
  };
}

async function run() {
  console.log(`Driving ${BASE_URL} (run ${RUN_ID})`);
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 900 },
    locale: "en-US",
  });
  const page = await context.newPage();

  const results: StepResult[] = [];

  results.push(
    await captureStep(page, "01-landing", () =>
      page.goto(`${BASE_URL}/ne`, { waitUntil: "domcontentloaded" }).then(() => {}),
    ),
  );
  results.push(
    await captureStep(page, "02-marketplace", () =>
      page.goto(`${BASE_URL}/ne/marketplace`, { waitUntil: "domcontentloaded" }).then(() => {}),
    ),
  );
  results.push(
    await captureStep(page, "03-login-phone", () =>
      page.goto(`${BASE_URL}/ne/auth/login`, { waitUntil: "domcontentloaded" }).then(() => {}),
    ),
  );

  // Try to advance: fill the phone number and click "Send OTP" so we can see
  // whether the form errors or progresses to the OTP screen. Whatever the
  // outcome, screenshot it.
  results.push(
    await captureStep(page, "04-login-after-send-otp", async () => {
      try {
        const phoneInput = page.getByPlaceholder(/9\d{2}/i).first();
        if (await phoneInput.count()) {
          await phoneInput.fill("9800000099");
          // Find a Continue/Send button by text in either locale
          const btn = page.getByRole("button", {
            name: /continue|send|पठाउनुहोस्|जारी/i,
          });
          if (await btn.count()) {
            await btn.first().click({ trial: false });
            await page.waitForTimeout(1500);
          }
        }
      } catch (e) {
        // swallow — we'll just screenshot what's visible
      }
    }),
  );

  results.push(
    await captureStep(page, "05-onboarding-unauth", () =>
      page.goto(`${BASE_URL}/ne/onboarding`, { waitUntil: "domcontentloaded" }).then(() => {}),
    ),
  );
  results.push(
    await captureStep(page, "06-farmer-dashboard-unauth", () =>
      page.goto(`${BASE_URL}/ne/farmer/dashboard`, { waitUntil: "domcontentloaded" }).then(() => {}),
    ),
  );
  results.push(
    await captureStep(page, "07-admin-unauth", () =>
      page.goto(`${BASE_URL}/ne/admin`, { waitUntil: "domcontentloaded" }).then(() => {}),
    ),
  );
  results.push(
    await captureStep(page, "08-android", () =>
      page.goto(`${BASE_URL}/ne/android`, { waitUntil: "domcontentloaded" }).then(() => {}),
    ),
  );

  await browser.close();

  fs.writeFileSync(
    path.join(OUT_DIR, "results.json"),
    JSON.stringify(results, null, 2),
  );

  console.log("\n=== Summary ===");
  for (const r of results) {
    const errors = r.consoleErrors.length;
    const fails = r.networkFailures.length;
    const tag = errors || fails ? "⚠" : "✓";
    console.log(`${tag} ${r.name}`);
    console.log(`    final url: ${r.finalUrl}`);
    if (errors) console.log(`    console errors: ${errors}`);
    if (fails) console.log(`    HTTP failures: ${fails}`);
  }
  console.log(`\nScreenshots: ${OUT_DIR}`);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
