import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for the JiriSewa home/landing page.
 * Route: /[locale]
 */
export class HomePage {
  readonly page: Page;
  readonly heroHeading: Locator;
  readonly ctaBrowse: Locator;
  readonly ctaRider: Locator;
  readonly navMarketplace: Locator;
  readonly navOrders: Locator;
  readonly navRider: Locator;
  readonly languageSwitcher: Locator;
  readonly howItWorksSection: Locator;
  readonly statsSection: Locator;
  readonly footer: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heroHeading = page.locator("h1").first();
    this.ctaBrowse = page.locator("button", { hasText: /browse|बजार/i }).first();
    this.ctaRider = page.locator("button", { hasText: /rider|सवारी/i }).first();
    this.navMarketplace = page.locator("nav a", { hasText: /marketplace|बजार/i });
    this.navOrders = page.locator("nav a", { hasText: /orders|अर्डर/i });
    this.navRider = page.locator("nav a", { hasText: /rider|सवारी/i });
    this.languageSwitcher = page.locator("[data-testid='language-switcher']").or(
      page.locator("button", { hasText: /EN|NE|English|नेपाली/i })
    );
    this.howItWorksSection = page.locator("h2", { hasText: /how it works|कसरी/i });
    this.statsSection = page.locator("h2", {
      hasText: /growing every day|हरेक दिन बढ्दै|numbers|तथ्यांक/i,
    });
    this.footer = page.locator("footer").or(page.locator("text=JiriSewa").last());
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}`);
  }

  async navigateToMarketplace(): Promise<void> {
    await this.navMarketplace.click();
  }

  async navigateToOrders(): Promise<void> {
    await this.navOrders.click();
  }
}
