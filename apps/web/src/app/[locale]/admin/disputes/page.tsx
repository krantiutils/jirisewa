import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { getDisputedOrders } from "@/lib/admin/queries";
import { Badge } from "@/components/ui";
import Link from "next/link";
import { AlertTriangle } from "lucide-react";

export default async function AdminDisputesPage({
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
  const { orders, total } = await getDisputedOrders(locale, { page });

  const totalPages = Math.ceil(total / 20);

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <AlertTriangle className="h-6 w-6 text-amber-500" />
          <h1 className="text-2xl font-bold text-foreground">
            {t("disputes.title")}
          </h1>
        </div>
        <span className="text-sm text-gray-500">
          {total} {t("disputes.activeDisputes")}
        </span>
      </div>

      {orders.length === 0 ? (
        <div className="rounded-lg bg-white p-12 text-center">
          <AlertTriangle className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-gray-500">{t("disputes.noDisputes")}</p>
        </div>
      ) : (
        <div className="space-y-3">
          {orders.map((order) => (
            <Link
              key={order.id}
              href={`/${locale}/admin/orders/${order.id}`}
              className="block rounded-lg bg-white p-5 transition-all duration-200 hover:scale-[1.01]"
            >
              <div className="flex items-start justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <Badge color="warning">Disputed</Badge>
                    <span className="font-mono text-xs text-gray-400">
                      {order.id.slice(0, 8)}
                    </span>
                  </div>
                  <div className="mt-2 flex gap-4 text-sm text-gray-500">
                    <span>
                      {t("orders.consumer")}: {order.consumer?.name ?? "—"}
                    </span>
                    <span>
                      {t("orders.rider")}: {order.rider?.name ?? "—"}
                    </span>
                  </div>
                  <p className="mt-1 text-sm text-gray-400">
                    {order.delivery_address}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-semibold text-foreground">
                    NPR {Number(order.total_price).toLocaleString()}
                  </p>
                  <p className="mt-1 text-sm text-gray-400">
                    {new Date(order.created_at).toLocaleDateString()}
                  </p>
                </div>
              </div>
            </Link>
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
                href={`/${locale}/admin/disputes?page=${page - 1}`}
                className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
              >
                {t("pagination.prev")}
              </Link>
            )}
            {page < totalPages && (
              <Link
                href={`/${locale}/admin/disputes?page=${page + 1}`}
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
