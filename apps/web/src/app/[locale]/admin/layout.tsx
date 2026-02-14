import { setRequestLocale } from "next-intl/server";
import { requireAdmin } from "@/lib/admin/auth";
import { AdminSidebar } from "./_components/AdminSidebar";

export const dynamic = "force-dynamic";

export default async function AdminLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  await requireAdmin(locale);

  return (
    <div className="flex min-h-[calc(100vh-57px)]">
      <AdminSidebar locale={locale} />
      <main className="flex-1 bg-gray-50 p-6 overflow-auto">{children}</main>
    </div>
  );
}
