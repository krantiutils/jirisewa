import { hasLocale } from "next-intl";
import { NextIntlClientProvider } from "next-intl";
import { getMessages, setRequestLocale } from "next-intl/server";
import { notFound } from "next/navigation";
import { Outfit } from "next/font/google";
import { routing } from "@/i18n/routing";
import { LanguageSwitcher } from "@/components/LanguageSwitcher";

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

  const messages = await getMessages();

  return (
    <html lang={locale} dir="ltr">
      <body className={`${outfit.variable} font-sans antialiased`}>
        <NextIntlClientProvider messages={messages}>
          <header className="flex items-center justify-between border-b border-gray-200 px-6 py-3">
            <span className="text-lg font-bold text-primary">
              {locale === "ne" ? "जिरीसेवा" : "JiriSewa"}
            </span>
            <LanguageSwitcher />
          </header>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
