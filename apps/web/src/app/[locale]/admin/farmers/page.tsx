import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { getUnverifiedFarmers } from "@/lib/admin/queries";
import { Badge } from "@/components/ui";
import { UserCheck, FileText, ExternalLink } from "lucide-react";
import Link from "next/link";
import { FarmerVerifyActions } from "../_components/FarmerVerifyActions";

export default async function AdminFarmersPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ page?: string; status?: string }>;
}) {
  const { locale } = await params;
  const sp = await searchParams;
  setRequestLocale(locale);

  const t = await getTranslations("admin");

  const page = Number(sp.page) || 1;
  const statusFilter = (sp.status ?? "pending") as "pending" | "unverified" | "rejected" | "all";
  const { farmers, total } = await getUnverifiedFarmers(locale, { page, statusFilter });

  const totalPages = Math.ceil(total / 20);

  const statusTabs = [
    { key: "pending", label: t("farmers.pending") },
    { key: "unverified", label: t("farmers.unverified") },
    { key: "rejected", label: t("farmers.rejected") },
  ] as const;

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

      {/* Status filter tabs */}
      <div className="mb-4 flex gap-2">
        {statusTabs.map((tab) => (
          <Link
            key={tab.key}
            href={`/${locale}/admin/farmers?status=${tab.key}`}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              statusFilter === tab.key
                ? "bg-primary text-white"
                : "bg-muted text-foreground hover:bg-gray-200"
            }`}
          >
            {tab.label}
          </Link>
        ))}
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
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-foreground">
                      {entry.user?.name ?? "Unknown"}
                    </span>
                    <Badge
                      color={
                        entry.verification_status === "pending"
                          ? "warning"
                          : entry.verification_status === "rejected"
                          ? "danger"
                          : "accent"
                      }
                    >
                      {t(`farmers.${entry.verification_status}` as const)}
                    </Badge>
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

                  {/* Documents section */}
                  {entry.documents ? (
                    <div className="mt-3 rounded-md bg-gray-50 p-3">
                      <div className="mb-2 flex items-center gap-2 text-sm font-medium text-gray-700">
                        <FileText className="h-4 w-4" />
                        {t("farmers.viewDocuments")}
                        <span className="text-xs text-gray-400">
                          ({t("farmers.submittedOn", { date: new Date(entry.documents.created_at).toLocaleDateString() })})
                        </span>
                      </div>
                      <div className="flex flex-wrap gap-3">
                        <a
                          href={entry.documents.citizenship_photo_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 rounded bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 hover:bg-blue-100 transition-colors"
                        >
                          {t("farmers.citizenshipPhoto")}
                          <ExternalLink className="h-3 w-3" />
                        </a>
                        <a
                          href={entry.documents.farm_photo_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 rounded bg-emerald-50 px-2 py-1 text-xs font-medium text-emerald-700 hover:bg-emerald-100 transition-colors"
                        >
                          {t("farmers.farmPhoto")}
                          <ExternalLink className="h-3 w-3" />
                        </a>
                        {entry.documents.municipality_letter_url && (
                          <a
                            href={entry.documents.municipality_letter_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 rounded bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700 hover:bg-amber-100 transition-colors"
                          >
                            {t("farmers.municipalityLetter")}
                            <ExternalLink className="h-3 w-3" />
                          </a>
                        )}
                      </div>
                      {entry.documents.admin_notes && (
                        <p className="mt-2 text-xs text-red-600">
                          {t("farmers.rejectionNotes")}: {entry.documents.admin_notes}
                        </p>
                      )}
                    </div>
                  ) : (
                    <p className="mt-3 text-xs text-gray-400 italic">
                      {t("farmers.noDocuments")}
                    </p>
                  )}
                </div>
                <div className="ml-4 flex shrink-0 flex-col items-end gap-2">
                  <Link
                    href={`/${locale}/admin/users/${entry.user_id}`}
                    className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200 transition-colors"
                  >
                    {t("farmers.viewProfile")}
                  </Link>
                  <FarmerVerifyActions
                    locale={locale}
                    roleId={entry.id}
                    hasDocuments={entry.documents !== null}
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
                href={`/${locale}/admin/farmers?status=${statusFilter}&page=${page - 1}`}
                className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
              >
                {t("pagination.prev")}
              </Link>
            )}
            {page < totalPages && (
              <Link
                href={`/${locale}/admin/farmers?status=${statusFilter}&page=${page + 1}`}
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
