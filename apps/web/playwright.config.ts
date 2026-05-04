import { defineConfig, devices } from "@playwright/test";

const FULL_E2E = process.env.FULL_E2E === "1";
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
const HAS_REAL_SUPABASE_KEY = SERVICE_ROLE_KEY.split(".").length === 3;
const INCLUDE_LEGACY_E2E = FULL_E2E && HAS_REAL_SUPABASE_KEY;
const WEB_PORT = process.env.PORT ?? "3000";
const LOCAL_BASE_URL = `http://localhost:${WEB_PORT}`;
const BASE_URL = process.env.BASE_URL ?? LOCAL_BASE_URL;

/**
 * Playwright E2E test configuration for JiriSewa web app.
 *
 * Usage:
 *   pnpm test:e2e                    — run all tests (headless)
 *   pnpm test:e2e:headed             — run with browser visible
 *   pnpm test:e2e:update-snapshots   — regenerate screenshot baselines
 *   pnpm test:e2e:ui                 — run with Playwright UI
 */
export default defineConfig({
  testDir: ".",
  // Default CI/local runs focus on deterministic browser-flows in tests/e2e.
  // Broader role-specific specs under e2e/ require a real Supabase JWT key.
  testMatch: INCLUDE_LEGACY_E2E
    ? ["tests/e2e/**/*.spec.ts", "e2e/**/*.spec.ts"]
    : ["tests/e2e/**/*.spec.ts"],

  timeout: 30_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI
    ? [["github"], ["html", { open: "never" }]]
    : [["list"], ["html", { open: "on-failure" }]],

  use: {
    baseURL: BASE_URL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "on-first-retry",
    locale: "en-US",
  },

  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.05,
      animations: "disabled",
    },
  },

  projects:
    INCLUDE_LEGACY_E2E
      ? [
          {
            name: "setup",
            testMatch: /global-setup\.ts/,
            teardown: "teardown",
          },
          {
            name: "teardown",
            testMatch: /global-teardown\.ts/,
          },
          {
            name: "chromium",
            use: {
              ...devices["Desktop Chrome"],
              storageState: "e2e/.auth/farmer.json",
            },
            dependencies: ["setup"],
          },
        ]
      : [
          {
            name: "chromium",
            use: {
              ...devices["Desktop Chrome"],
            },
          },
        ],

  webServer: process.env.BASE_URL
    ? undefined
    : {
        command: `pnpm dev --port ${WEB_PORT}`,
        url: LOCAL_BASE_URL,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
      },
});
