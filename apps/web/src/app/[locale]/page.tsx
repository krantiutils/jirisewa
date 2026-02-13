import { useTranslations } from "next-intl";
import { setRequestLocale } from "next-intl/server";
import { use } from "react";

export default function HomePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  setRequestLocale(locale);

  const t = useTranslations("home");

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8">
      <h1 className="text-4xl font-bold text-green-700">{t("title")}</h1>
      <p className="mt-2 text-xl text-gray-600">{t("subtitle")}</p>
      <p className="mt-4 max-w-md text-center text-gray-500">
        {t("description")}
      </p>
    </main>
  );
}
