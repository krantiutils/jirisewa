import { hasLocale } from "next-intl";
import { NextIntlClientProvider } from "next-intl";
import {
  getMessages,
  getTranslations,
  setRequestLocale,
} from "next-intl/server";
import { notFound } from "next/navigation";
import { Outfit } from "next/font/google";
import Link from "next/link";
import { routing } from "@/i18n/routing";
import { LanguageSwitcher } from "@/components/LanguageSwitcher";
import { AuthProvider } from "@/components/AuthProvider";
import { CartProvider } from "@/lib/cart";
import { CartHeaderLink } from "@/components/cart/CartHeaderLink";
import { NotificationBell } from "@/components/notifications/NotificationBell";
import { PushNotificationManager } from "@/components/notifications/PushNotificationManager";

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
});

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? "https://jirisewa.com";
  const messages = (await import(`../../../messages/${locale}.json`)).default;

  return {
    title: messages.metadata.title,
    description: messages.metadata.description,
    alternates: {
      canonical: `${baseUrl}/${locale}`,
      languages: Object.fromEntries(
        routing.locales.map((loc) => [loc, `${baseUrl}/${loc}`]),
      ),
    },
  };
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }

  setRequestLocale(locale);

  const [messages, nav] = await Promise.all([
    getMessages(),
    getTranslations("nav"),
  ]);

  return (
    <html lang={locale} dir="ltr">
      <body className={`${outfit.variable} font-sans antialiased`}>
        <NextIntlClientProvider messages={messages}>
          <AuthProvider>
            <CartProvider>
              <header className="flex items-center justify-between border-b border-gray-200 px-6 py-3">
                <div className="flex items-center gap-6">
                  <Link
                    href={`/${locale}`}
                    className="text-lg font-bold text-primary"
                  >
                    {locale === "ne" ? "जिरीसेवा" : "JiriSewa"}
                  </Link>
                  <nav className="hidden items-center gap-4 text-sm sm:flex">
                    <Link
                      href={`/${locale}/marketplace`}
                      className="text-gray-600 hover:text-primary transition-colors"
                    >
                      {nav("marketplace")}
                    </Link>
                    <Link
                      href={`/${locale}/orders`}
                      className="text-gray-600 hover:text-primary transition-colors"
                    >
                      {nav("orders")}
                    </Link>
                    <Link
                      href={`/${locale}/rider/dashboard`}
                      className="text-gray-600 hover:text-primary transition-colors"
                    >
                      {nav("rider")}
                    </Link>
                  </nav>
                </div>
                <div className="flex items-center gap-3">
                  <NotificationBell />
                  <CartHeaderLink locale={locale} />
                  <LanguageSwitcher />
                </div>
              </header>
              <PushNotificationManager />
              {children}
            </CartProvider>
          </AuthProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
