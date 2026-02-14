import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { getOrderDetail } from "@/lib/admin/queries";
import { Badge } from "@/components/ui";
import { notFound } from "next/navigation";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { OrderActions } from "../../_components/OrderActions";

export default async function AdminOrderDetailPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale, id } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("admin");
  const order = await getOrderDetail(locale, id);

  if (!order) {
    notFound();
  }

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
      default:
        return "primary" as const;
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <Link
        href={`/${locale}/admin/orders`}
        className="mb-4 inline-flex items-center gap-1 text-sm text-gray-500 hover:text-primary"
      >
        <ArrowLeft className="h-4 w-4" />
        {t("orders.backToOrders")}
      </Link>

      {/* Order header */}
      <div className="mb-6 rounded-lg bg-white p-6">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-bold text-foreground">
              {t("orders.orderDetail")}
            </h1>
            <p className="mt-1 font-mono text-sm text-gray-500">
              {order.id}
            </p>
          </div>
          <Badge color={statusColor(order.status)}>{order.status}</Badge>
        </div>

        <div className="mt-4 grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-gray-500">{t("orders.consumer")}</p>
            <p className="font-medium text-foreground">
              {order.consumer?.name ?? "—"}
            </p>
            {order.consumer?.phone && (
              <p className="text-gray-400">{order.consumer.phone}</p>
            )}
          </div>
          <div>
            <p className="text-gray-500">{t("orders.rider")}</p>
            <p className="font-medium text-foreground">
              {order.rider?.name ?? t("orders.noRider")}
            </p>
            {order.rider?.phone && (
              <p className="text-gray-400">{order.rider.phone}</p>
            )}
          </div>
          <div>
            <p className="text-gray-500">{t("orders.deliveryAddress")}</p>
            <p className="font-medium text-foreground">
              {order.delivery_address}
            </p>
          </div>
          <div>
            <p className="text-gray-500">{t("orders.date")}</p>
            <p className="font-medium text-foreground">
              {new Date(order.created_at).toLocaleString()}
            </p>
          </div>
        </div>
      </div>

      {/* Order items */}
      <div className="mb-6 rounded-lg bg-white p-6">
        <h2 className="mb-4 text-lg font-semibold text-foreground">
          {t("orders.items")}
        </h2>
        <div className="space-y-3">
          {order.items.map((item) => (
            <div
              key={item.id}
              className="flex items-center justify-between rounded-md bg-gray-50 p-3"
            >
              <div>
                <p className="font-medium text-foreground">
                  {item.listing?.name_en ?? "Unknown"}
                </p>
                <p className="text-sm text-gray-500">
                  {t("orders.fromFarmer", {
                    farmer: item.farmer?.name ?? "Unknown",
                  })}
                </p>
                <div className="mt-1 flex gap-2">
                  {item.pickup_confirmed && (
                    <Badge color="success">{t("orders.pickedUp")}</Badge>
                  )}
                  {item.delivery_confirmed && (
                    <Badge color="success">{t("orders.delivered")}</Badge>
                  )}
                </div>
              </div>
              <div className="text-right">
                <p className="font-medium text-foreground">
                  NPR {Number(item.subtotal).toLocaleString()}
                </p>
                <p className="text-sm text-gray-500">
                  {item.quantity_kg} kg @ NPR {Number(item.price_per_kg).toLocaleString()}/kg
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* Totals */}
        <div className="mt-4 border-t border-gray-100 pt-4 space-y-1 text-sm">
          <div className="flex justify-between text-gray-500">
            <span>{t("orders.subtotal")}</span>
            <span>
              NPR{" "}
              {(
                Number(order.total_price) - Number(order.delivery_fee)
              ).toLocaleString()}
            </span>
          </div>
          <div className="flex justify-between text-gray-500">
            <span>{t("orders.deliveryFee")}</span>
            <span>NPR {Number(order.delivery_fee).toLocaleString()}</span>
          </div>
          <div className="flex justify-between font-semibold text-foreground">
            <span>{t("orders.total")}</span>
            <span>NPR {Number(order.total_price).toLocaleString()}</span>
          </div>
          <div className="flex justify-between text-gray-500">
            <span>{t("orders.paymentMethod")}</span>
            <span>{order.payment_method}</span>
          </div>
          <div className="flex justify-between text-gray-500">
            <span>{t("orders.paymentStatus")}</span>
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
          </div>
        </div>
      </div>

      {/* Admin actions */}
      <OrderActions locale={locale} orderId={order.id} status={order.status} />
    </div>
  );
}
