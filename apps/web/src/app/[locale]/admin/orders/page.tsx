import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { getOrders } from "@/lib/admin/queries";
import { Badge } from "@/components/ui";
import Link from "next/link";
import { OrderStatusFilter } from "../_components/OrderStatusFilter";

export default async function AdminOrdersPage({
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
  const { orders, total } = await getOrders(locale, {
    page,
    status: sp.status,
  });

  const totalPages = Math.ceil(total / 20);

  const statusColor = (status: string) => {
    switch (status) {
      case "delivered":
        return "success" as const;
      case "cancelled":
        return "danger" as const;
      case "disputed":
        return "warning" as const;
      case "in_transit":
      case "picked_up":
        return "accent" as const;
      case "matched":
        return "secondary" as const;
      default:
        return "primary" as const;
    }
  };

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">
          {t("orders.title")}
        </h1>
        <span className="text-sm text-gray-500">
          {total} {t("orders.totalOrders")}
        </span>
      </div>

      <OrderStatusFilter locale={locale} initialStatus={sp.status} />

      <div className="mt-4 rounded-lg bg-white">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("orders.id")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("orders.status")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("orders.consumer")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("orders.rider")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("orders.total")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("orders.payment")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("orders.date")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.actions")}
                </th>
              </tr>
            </thead>
            <tbody>
              {orders.map((order) => (
                <tr
                  key={order.id}
                  className="border-b border-gray-50 last:border-0"
                >
                  <td className="px-4 py-3 font-mono text-xs text-gray-500">
                    {order.id.slice(0, 8)}
                  </td>
                  <td className="px-4 py-3">
                    <Badge color={statusColor(order.status)}>
                      {order.status}
                    </Badge>
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {order.consumer?.name ?? "—"}
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {order.rider?.name ?? "—"}
                  </td>
                  <td className="px-4 py-3 font-medium text-foreground">
                    NPR {Number(order.total_price).toLocaleString()}
                  </td>
                  <td className="px-4 py-3">
                    <Badge
                      color={
                        order.payment_status === "settled"
                          ? "success"
                          : order.payment_status === "collected"
                            ? "accent"
                            : "primary"
                      }
                    >
                      {order.payment_status}
                    </Badge>
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {new Date(order.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/${locale}/admin/orders/${order.id}`}
                      className="text-primary font-medium hover:underline"
                    >
                      {t("orders.view")}
                    </Link>
                  </td>
                </tr>
              ))}
              {orders.length === 0 && (
                <tr>
                  <td
                    colSpan={8}
                    className="px-4 py-12 text-center text-gray-500"
                  >
                    {t("orders.noResults")}
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
                <Link
                  href={`/${locale}/admin/orders?page=${page - 1}${sp.status ? `&status=${sp.status}` : ""}`}
                  className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
                >
                  {t("pagination.prev")}
                </Link>
              )}
              {page < totalPages && (
                <Link
                  href={`/${locale}/admin/orders?page=${page + 1}${sp.status ? `&status=${sp.status}` : ""}`}
                  className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
                >
                  {t("pagination.next")}
                </Link>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
