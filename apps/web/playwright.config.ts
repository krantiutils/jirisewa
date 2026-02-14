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
  testMatch: ["tests/e2e/**/*.spec.ts", "e2e/**/*.spec.ts"],

  /* Global setup and teardown — seed/cleanup test data */
  globalSetup: require.resolve("./tests/global-setup"),
  globalTeardown: require.resolve("./tests/global-teardown"),

  fullyParallel: true,

  /* Maximum time one test can run */
  timeout: 30_000,

  /* Fail the build on CI if you accidentally left test.only in the source code */
  forbidOnly: !!process.env.CI,

  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,

  /* Limit parallel workers on CI to avoid resource contention */
  workers: process.env.CI ? 1 : undefined,

  /* Reporter: concise on CI, verbose locally */
  reporter: process.env.CI
    ? [["github"], ["html", { open: "never" }]]
    : [["list"], ["html", { open: "on-failure" }]],

  /* Shared settings for all projects */
  use: {
    baseURL: "http://localhost:3000",

    /* Collect trace on first retry for debugging */
    trace: "on-first-retry",

    /* Screenshot on failure for every test */
    screenshot: "only-on-failure",

    /* Video on first retry */
    video: "on-first-retry",

    /* Default locale for the app */
    locale: "en-US",
  },

  /* Visual regression snapshot config */
  expect: {
    toHaveScreenshot: {
      /* Allow 0.2% pixel mismatch to handle anti-aliasing differences */
      maxDiffPixelRatio: 0.002,

      /* Threshold for individual pixel color diff (0-1, lower = stricter) */
      threshold: 0.2,

      /* Animation stabilization */
      animations: "disabled",
    },
    toMatchSnapshot: {
      maxDiffPixelRatio: 0.002,
    },
  },

  /* Screenshot snapshot path template */
  snapshotPathTemplate:
    "{testDir}/../screenshots/{testFilePath}/{arg}{-projectName}{ext}",

  /* Browser projects — Chromium only for now, expand later */
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    // Uncomment when ready to expand browser coverage:
    // {
    //   name: "firefox",
    //   use: { ...devices["Desktop Firefox"] },
    // },
    // {
    //   name: "webkit",
    //   use: { ...devices["Desktop Safari"] },
    // },
  ],

  /* Run the Next.js dev server before starting tests */
  webServer: {
    command: "pnpm dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: "pipe",
    stderr: "pipe",
  },
});
