import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for the marketplace page.
 * Route: /[locale]/marketplace
 */
export class MarketplacePage {
  readonly page: Page;
  readonly heading: Locator;
  readonly produceCards: Locator;
  readonly searchInput: Locator;
  readonly categoryFilters: Locator;
  readonly sortDropdown: Locator;
  readonly loadingSpinner: Locator;
  readonly emptyState: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.produceCards = page.locator("[data-testid='produce-card']").or(
      page.locator("article").or(page.locator("[class*='card']"))
    );
    this.searchInput = page.locator("input[type='search']").or(
      page.locator("input[placeholder*='search' i]").or(
        page.locator("input[placeholder*='खोज' i]")
      )
    );
    this.categoryFilters = page.locator("[data-testid='category-filter']").or(
      page.locator("[role='tablist']").or(page.locator("nav a[href*='marketplace']"))
    );
    this.sortDropdown = page.locator("select").or(
      page.locator("[data-testid='sort-dropdown']")
    );
    this.loadingSpinner = page.locator("[data-testid='loading']").or(
      page.locator("[class*='spinner']").or(page.locator("[class*='loading']"))
    );
    this.emptyState = page.locator("[data-testid='empty-state']").or(
      page.locator("text=/no.*produce|कुनै.*उत्पादन/i")
    );
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/marketplace`);
  }

  async waitForLoaded(): Promise<void> {
    await this.page.waitForLoadState("networkidle");
  }

  async search(query: string): Promise<void> {
    await this.searchInput.fill(query);
    await this.page.waitForLoadState("networkidle");
  }

  async getProduceCount(): Promise<number> {
    return this.produceCards.count();
  }
}
