import { getTranslations, setRequestLocale } from "next-intl/server";
import { NotificationPreferences } from "@/components/notifications/NotificationPreferences";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "notifications" });
  return { title: t("preferences.title") };
}

export default async function NotificationsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <main className="mx-auto max-w-2xl px-4 py-8">
      <NotificationPreferences />
    </main>
  );
}
