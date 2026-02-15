import { defineConfig, devices } from "@playwright/test";

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
  // Broader role-specific specs under e2e/ can be enabled explicitly.
  testMatch:
    process.env.FULL_E2E === "1"
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
    baseURL: process.env.BASE_URL ?? "http://localhost:3000",
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
    process.env.FULL_E2E === "1"
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

  webServer: {
    command: "pnpm dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
