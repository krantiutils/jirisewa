"use client";

import { useLocale, useTranslations } from "next-intl";
import { usePathname, useRouter } from "@/i18n/navigation";
import type { Locale } from "@/lib/i18n";

export function LanguageSwitcher() {
  const locale = useLocale() as Locale;
  const router = useRouter();
  const pathname = usePathname();
  const t = useTranslations("languageSwitcher");

  const otherLocale = locale === "ne" ? "en" : "ne";

  function handleSwitch() {
    router.replace(pathname, { locale: otherLocale });
  }

  return (
    <button
      onClick={handleSwitch}
      className="rounded border border-gray-300 px-3 py-1 text-sm font-medium transition-colors hover:bg-gray-100"
      aria-label={`Switch to ${t(otherLocale)}`}
    >
      {t(otherLocale)}
    </button>
  );
}
