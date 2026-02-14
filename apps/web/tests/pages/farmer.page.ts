import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for farmer dashboard.
 * Route: /[locale]/farmer/dashboard
 */
export class FarmerDashboardPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly listingsSection: Locator;
  readonly ordersSection: Locator;
  readonly earningsSection: Locator;
  readonly addListingButton: Locator;
  readonly verificationBanner: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.listingsSection = page.locator("[data-testid='listings-section']").or(
      page.locator("text=/listings|सूची/i").first()
    );
    this.ordersSection = page.locator("[data-testid='orders-section']").or(
      page.locator("text=/orders|अर्डर/i").first()
    );
    this.earningsSection = page.locator("[data-testid='earnings-section']").or(
      page.locator("text=/earnings|आम्दानी/i").first()
    );
    this.addListingButton = page.locator("a[href*='listings/new']").or(
      page.locator("button", { hasText: /add.*listing|नयाँ सूची/i })
    );
    this.verificationBanner = page.locator("[data-testid='verification-banner']").or(
      page.locator("text=/verification|प्रमाणिकरण/i").first()
    );
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/farmer/dashboard`);
  }

  async navigateToNewListing(): Promise<void> {
    await this.addListingButton.click();
  }
}

/**
 * Page object model for new listing page.
 * Route: /[locale]/farmer/listings/new
 */
export class NewListingPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly nameInput: Locator;
  readonly priceInput: Locator;
  readonly quantityInput: Locator;
  readonly submitButton: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.nameInput = page.locator("[name='name']").or(
      page.locator("input").first()
    );
    this.priceInput = page.locator("[name='price']").or(
      page.locator("input[type='number']").first()
    );
    this.quantityInput = page.locator("[name='quantity']").or(
      page.locator("input[type='number']").last()
    );
    this.submitButton = page.locator("button[type='submit']").or(
      page.locator("button", { hasText: /create|save|बनाउ/i })
    );
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/farmer/listings/new`);
  }
}
