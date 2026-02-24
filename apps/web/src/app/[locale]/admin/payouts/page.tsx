import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { listPayoutRequests } from "@/lib/actions/admin/payouts";
import { Badge } from "@/components/ui";
import { PayoutStatusFilter } from "../_components/PayoutStatusFilter";
import { PayoutActions } from "../_components/PayoutActions";

export default async function AdminPayoutsPage({
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
  const { requests, total } = await listPayoutRequests(locale, {
    page,
    status: sp.status,
  });

  const totalPages = Math.ceil(total / 20);

  const statusColor = (status: string) => {
    switch (status) {
      case "completed":
        return "success" as const;
      case "rejected":
        return "danger" as const;
      case "processing":
        return "accent" as const;
      default:
        return "primary" as const;
    }
  };

  const methodLabel = (method: string) => {
    switch (method) {
      case "esewa":
        return "eSewa";
      case "khalti":
        return "Khalti";
      case "bank":
        return "Bank Transfer";
      default:
        return method;
    }
  };

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">
          {t("payouts.title")}
        </h1>
        <span className="text-sm text-gray-500">
          {total} {t("payouts.totalRequests")}
        </span>
      </div>

      <PayoutStatusFilter locale={locale} initialStatus={sp.status} />

      <div className="mt-4 rounded-lg bg-white">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("payouts.user")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("payouts.phone")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("payouts.amount")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("payouts.method")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("payouts.status")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("payouts.date")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.actions")}
                </th>
              </tr>
            </thead>
            <tbody>
              {requests.map((req) => {
                const user = Array.isArray(req.user)
                  ? req.user[0]
                  : req.user;
                return (
                  <tr
                    key={req.id}
                    className="border-b border-gray-50 last:border-0"
                  >
                    <td className="px-4 py-3 font-medium text-foreground">
                      {user?.name ?? "Unknown"}
                    </td>
                    <td className="px-4 py-3 text-gray-600">
                      {user?.phone ?? "--"}
                    </td>
                    <td className="px-4 py-3 font-medium text-foreground">
                      NPR {Number(req.amount).toLocaleString()}
                    </td>
                    <td className="px-4 py-3 text-gray-600">
                      {methodLabel(req.method)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge color={statusColor(req.status)}>
                        {t(`payouts.statusLabels.${req.status}` as never)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-gray-600">
                      {new Date(req.created_at).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3">
                      <PayoutActions
                        locale={locale}
                        payoutId={req.id}
                        currentStatus={req.status}
                      />
                      {req.admin_notes && (
                        <p className="mt-1 text-xs text-gray-400 italic">
                          {req.admin_notes}
                        </p>
                      )}
                    </td>
                  </tr>
                );
              })}
              {requests.length === 0 && (
                <tr>
                  <td
                    colSpan={7}
                    className="px-4 py-12 text-center text-gray-500"
                  >
                    {t("payouts.noResults")}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-gray-100 px-4 py-3">
            <span className="text-sm text-gray-500">
              {t("pagination.showing", {
                from: (page - 1) * 20 + 1,
                to: Math.min(page * 20, total),
                total,
              })}
            </span>
            <div className="flex gap-2">
              {page > 1 && (
                <a
                  href={`/${locale}/admin/payouts?page=${page - 1}${sp.status ? `&status=${sp.status}` : ""}`}
                  className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
                >
                  {t("pagination.prev")}
                </a>
              )}
              {page < totalPages && (
                <a
                  href={`/${locale}/admin/payouts?page=${page + 1}${sp.status ? `&status=${sp.status}` : ""}`}
                  className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
                >
                  {t("pagination.next")}
                </a>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
