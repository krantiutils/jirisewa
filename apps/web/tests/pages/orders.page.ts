import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for orders list page.
 * Route: /[locale]/orders
 */
export class OrdersPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly orderCards: Locator;
  readonly emptyState: Locator;
  readonly statusFilters: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.orderCards = page.locator("[data-testid='order-card']").or(
      page.locator("article").or(page.locator("[class*='OrderCard']"))
    );
    this.emptyState = page.locator("[data-testid='empty-state']").or(
      page.locator("text=/no.*orders|कुनै.*अर्डर/i")
    );
    this.statusFilters = page.locator("[data-testid='status-filter']").or(
      page.locator("[role='tablist']")
    );
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/orders`);
  }

  async getOrderCount(): Promise<number> {
    return this.orderCards.count();
  }
}

/**
 * Page object model for order detail page.
 * Route: /[locale]/orders/[id]
 */
export class OrderDetailPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly statusBadge: Locator;
  readonly orderItems: Locator;
  readonly mapSection: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.statusBadge = page.locator("[data-testid='order-status']").or(
      page.locator("[class*='badge']").first()
    );
    this.orderItems = page.locator("[data-testid='order-item']").or(
      page.locator("li").or(page.locator("tr"))
    );
    this.mapSection = page.locator("[data-testid='order-map']").or(
      page.locator("[class*='leaflet']")
    );
  }

  async goto(orderId: string): Promise<void> {
    await this.page.goto(`/${this.locale}/orders/${orderId}`);
  }
}
