import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for rider dashboard.
 * Route: /[locale]/rider/dashboard
 */
export class RiderDashboardPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly tripsSection: Locator;
  readonly earningsSection: Locator;
  readonly createTripButton: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.tripsSection = page.locator("[data-testid='trips-section']").or(
      page.locator("text=/trips|यात्रा/i").first()
    );
    this.earningsSection = page.locator("[data-testid='earnings-section']").or(
      page.locator("text=/earnings|आम्दानी/i").first()
    );
    this.createTripButton = page.locator("a[href*='trips']").or(
      page.locator("button", { hasText: /create.*trip|post.*trip|नयाँ यात्रा/i })
    );
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/rider/dashboard`);
  }
}
