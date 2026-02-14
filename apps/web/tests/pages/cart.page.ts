import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for the cart page.
 * Route: /[locale]/cart
 */
export class CartPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly cartItems: Locator;
  readonly emptyState: Locator;
  readonly totalPrice: Locator;
  readonly checkoutButton: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
    this.cartItems = page.locator("[data-testid='cart-item']").or(
      page.locator("article").or(page.locator("[class*='cart-item']"))
    );
    this.emptyState = page.locator("[data-testid='empty-cart']").or(
      page.locator("text=/empty.*cart|खाली.*कार्ट/i")
    );
    this.totalPrice = page.locator("[data-testid='total-price']").or(
      page.locator("text=/total|जम्मा/i")
    );
    this.checkoutButton = page.locator("a[href*='checkout']").or(
      page.locator("button", { hasText: /checkout|चेकआउट/i })
    );
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/cart`);
  }

  async getItemCount(): Promise<number> {
    return this.cartItems.count();
  }
}
