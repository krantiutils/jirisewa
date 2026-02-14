import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for admin dashboard.
 * Route: /[locale]/admin
 */
export class AdminDashboardPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly sidebar: Locator;
  readonly usersLink: Locator;
  readonly ordersLink: Locator;
  readonly farmersLink: Locator;
  readonly disputesLink: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.sidebar = page.locator("[data-testid='admin-sidebar']").or(
      page.locator("aside").or(page.locator("nav").last())
    );
    this.usersLink = page.locator("a[href*='admin/users']");
    this.ordersLink = page.locator("a[href*='admin/orders']");
    this.farmersLink = page.locator("a[href*='admin/farmers']");
    this.disputesLink = page.locator("a[href*='admin/disputes']");
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/admin`);
  }
}
