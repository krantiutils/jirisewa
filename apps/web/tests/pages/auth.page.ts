import { type Page, type Locator } from "@playwright/test";

/**
 * Page object model for the login page.
 * Route: /[locale]/auth/login
 */
export class LoginPage {
  readonly page: Page;
  readonly phoneInput: Locator;
  readonly sendOtpButton: Locator;
  readonly otpInput: Locator;
  readonly verifyButton: Locator;
  readonly errorMessage: Locator;
  readonly countryCode: Locator;
  readonly changePhoneButton: Locator;
  readonly resendButton: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.phoneInput = page.locator("#phone").or(
      page.locator("input[type='tel']")
    );
    this.sendOtpButton = page.locator("button", { hasText: /send.*otp|OTP पठाउनुहोस्/i });
    this.otpInput = page.locator("input[maxlength='6']").or(
      page.locator("input[inputmode='numeric']").last()
    );
    this.verifyButton = page.locator("button", { hasText: /verify|प्रमाणित/i });
    this.errorMessage = page.locator(".text-red-600").or(
      page.locator("[role='alert']")
    );
    this.countryCode = page.locator("text=+977");
    this.changePhoneButton = page.locator("button", { hasText: /change.*phone|फोन बदल/i });
    this.resendButton = page.locator("button", { hasText: /resend|पुन: पठाउ/i });
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/auth/login`);
  }

  async enterPhone(phone: string): Promise<void> {
    await this.phoneInput.fill(phone);
  }

  async submitPhone(): Promise<void> {
    await this.sendOtpButton.click();
  }

  async enterOtp(otp: string): Promise<void> {
    await this.otpInput.fill(otp);
  }

  async submitOtp(): Promise<void> {
    await this.verifyButton.click();
  }
}

/**
 * Page object model for the registration page.
 * Route: /[locale]/auth/register
 */
export class RegisterPage {
  readonly page: Page;
  readonly heading: Locator;

  constructor(page: Page, readonly locale = "en") {
    this.page = page;
    this.heading = page.locator("h1").first();
  }

  async goto(): Promise<void> {
    await this.page.goto(`/${this.locale}/auth/register`);
  }
}
