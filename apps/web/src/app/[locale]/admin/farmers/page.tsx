import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { getUnverifiedFarmers } from "@/lib/admin/queries";
import { Badge } from "@/components/ui";
import { UserCheck } from "lucide-react";
import Link from "next/link";
import { FarmerVerifyActions } from "../_components/FarmerVerifyActions";

export default async function AdminFarmersPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ page?: string }>;
}) {
  const { locale } = await params;
  const sp = await searchParams;
  setRequestLocale(locale);

  const t = await getTranslations("admin");

  const page = Number(sp.page) || 1;
  const { farmers, total } = await getUnverifiedFarmers(locale, { page });

  const totalPages = Math.ceil(total / 20);

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <UserCheck className="h-6 w-6 text-emerald-500" />
          <h1 className="text-2xl font-bold text-foreground">
            {t("farmers.title")}
          </h1>
        </div>
        <span className="text-sm text-gray-500">
          {total} {t("farmers.pendingVerification")}
        </span>
      </div>

      {farmers.length === 0 ? (
        <div className="rounded-lg bg-white p-12 text-center">
          <UserCheck className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-gray-500">{t("farmers.allVerified")}</p>
        </div>
      ) : (
        <div className="space-y-3">
          {farmers.map((entry) => (
            <div
              key={entry.id}
              className="rounded-lg bg-white p-5"
            >
              <div className="flex items-start justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-foreground">
                      {entry.user?.name ?? "Unknown"}
                    </span>
                    <Badge color="warning">{t("farmers.unverified")}</Badge>
                  </div>
                  <p className="mt-1 text-sm text-gray-500">
                    {entry.user?.phone}
                  </p>
                  {entry.farm_name && (
                    <p className="mt-1 text-sm text-gray-500">
                      {t("farmers.farmName")}: {entry.farm_name}
                    </p>
                  )}
                  {entry.user?.address && (
                    <p className="text-sm text-gray-400">
                      {entry.user.address}
                    </p>
                  )}
                  <p className="mt-1 text-xs text-gray-400">
                    {t("farmers.registered")}:{" "}
                    {new Date(entry.created_at).toLocaleDateString()}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <Link
                    href={`/${locale}/admin/users/${entry.user_id}`}
                    className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200 transition-colors"
                  >
                    {t("farmers.viewProfile")}
                  </Link>
                  <FarmerVerifyActions
                    locale={locale}
                    roleId={entry.id}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between">
          <span className="text-sm text-gray-500">
            {t("pagination.showing", {
              from: (page - 1) * 20 + 1,
              to: Math.min(page * 20, total),
              total,
            })}
          </span>
          <div className="flex gap-2">
            {page > 1 && (
              <Link
                href={`/${locale}/admin/farmers?page=${page - 1}`}
                className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
              >
                {t("pagination.prev")}
              </Link>
            )}
            {page < totalPages && (
              <Link
                href={`/${locale}/admin/farmers?page=${page + 1}`}
                className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
              >
                {t("pagination.next")}
              </Link>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
