import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { ShoppingCart } from "lucide-react";
import { getMyOrders } from "@/lib/actions/orders";
import { getOrderRatingStatus } from "@/lib/actions/ratings";
import { OrderCard } from "./_components/OrderCard";
import type { RatingStatus } from "@/lib/actions/ratings";

export default async function OrdersPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("orders");
  const ordersResult = await getMyOrders();

  if (!ordersResult.success) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center p-8">
        <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
        <p className="mt-2 text-gray-500">{t("loginRequired")}</p>
      </div>
    );
  }

  const orders = ordersResult.data;

  // Fetch rating status for all delivered orders in parallel
  const deliveredOrders = orders.filter((o) => o.status === "delivered");
  const ratingStatusResults = await Promise.all(
    deliveredOrders.map((o) => getOrderRatingStatus(o.id)),
  );

  const ratingStatusMap = new Map<string, RatingStatus>();
  deliveredOrders.forEach((order, idx) => {
    const result = ratingStatusResults[idx];
    if (result.success) {
      ratingStatusMap.set(order.id, result.data);
    }
  });

  return (
    <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground">{t("myOrders")}</h1>
      </div>

      {/* Orders list */}
      {orders.length === 0 ? (
        <div className="rounded-lg bg-white p-12 text-center">
          <ShoppingCart className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-gray-500">{t("noOrders")}</p>
          <Link
            href="/marketplace"
            className="mt-4 inline-flex items-center gap-2 rounded-md bg-primary px-6 h-12 font-semibold text-white transition-all duration-200 hover:bg-blue-600 hover:scale-105"
          >
            {t("browseMarketplace")}
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          {orders.map((order) => (
            <OrderCard
              key={order.id}
              order={order}
              ratingStatus={ratingStatusMap.get(order.id) ?? null}
            />
          ))}
        </div>
      )}
    </div>
  );
}
