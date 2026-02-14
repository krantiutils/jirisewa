"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import {
  ArrowLeft,
  Loader2,
  CheckCircle,
  XCircle,
  Calendar,
  MapPin,
  MessageSquare,
} from "lucide-react";
import { getBulkOrder, cancelBulkOrder, acceptBulkOrder } from "@/lib/actions/business";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import type { Locale } from "@/lib/i18n";
import type { BulkOrderWithDetails } from "@/lib/types/business";

const STATUS_COLORS: Record<string, "primary" | "accent" | "success" | "danger" | "warning"> = {
  draft: "primary",
  submitted: "accent",
  quoted: "warning",
  accepted: "success",
  in_progress: "primary",
  fulfilled: "success",
  cancelled: "danger",
};

const ITEM_STATUS_COLORS: Record<string, "primary" | "accent" | "success" | "danger" | "warning"> = {
  pending: "accent",
  quoted: "warning",
  accepted: "success",
  rejected: "danger",
  fulfilled: "success",
  cancelled: "danger",
};

export default function BulkOrderDetailPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const orderId = params.id as string;
  const router = useRouter();
  const t = useTranslations("business");

  const [order, setOrder] = useState<BulkOrderWithDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    async function load() {
      const result = await getBulkOrder(orderId);
      if (result.error) {
        setError(result.error);
      } else if (result.data) {
        setOrder(result.data);
      }
      setLoading(false);
    }
    load();
  }, [orderId]);

  const handleCancel = async () => {
    setActionLoading(true);
    const result = await cancelBulkOrder(orderId);
    if (result.error) {
      setError(result.error);
    } else {
      // Reload
      const reload = await getBulkOrder(orderId);
      if (reload.data) setOrder(reload.data);
    }
    setActionLoading(false);
  };

  const handleAccept = async () => {
    setActionLoading(true);
    const result = await acceptBulkOrder(orderId);
    if (result.error) {
      setError(result.error);
    } else {
      const reload = await getBulkOrder(orderId);
      if (reload.data) setOrder(reload.data);
    }
    setActionLoading(false);
  };

  if (loading) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  if (!order) {
    return (
      <main className="min-h-screen bg-muted">
        <div className="mx-auto max-w-3xl px-4 py-8 text-center">
          <p className="text-gray-500">{error ?? t("orders.notFound")}</p>
          <Button
            variant="secondary"
            className="mt-4"
            onClick={() => router.push(`/${locale}/business/orders`)}
          >
            <ArrowLeft className="mr-2 h-4 w-4" />
            {t("orders.backToOrders")}
          </Button>
        </div>
      </main>
    );
  }

  const dateStr = new Date(order.created_at).toLocaleDateString(
    locale === "ne" ? "ne-NP" : "en-US",
    { month: "long", day: "numeric", year: "numeric" },
  );

  // Group items by farmer
  const farmerGroups = new Map<string, typeof order.items>();
  for (const item of order.items) {
    const farmerId = item.farmer_id;
    const group = farmerGroups.get(farmerId) ?? [];
    group.push(item);
    farmerGroups.set(farmerId, group);
  }

  const canCancel = ["draft", "submitted", "quoted"].includes(order.status);
  const canAccept = order.status === "quoted";

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
        {/* Back button */}
        <button
          onClick={() => router.push(`/${locale}/business/orders`)}
          className="mb-4 flex items-center gap-1 text-sm text-gray-500 hover:text-primary transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("orders.backToOrders")}
        </button>

        {/* Header */}
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-bold text-foreground">
                {t("orders.orderDetail")}
              </h1>
              <Badge color={STATUS_COLORS[order.status] ?? "primary"}>
                {t(`status.${order.status}`)}
              </Badge>
            </div>
            <p className="mt-1 text-sm text-gray-500">{dateStr}</p>
          </div>
        </div>

        {error && (
          <div className="mt-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Order info */}
        <div className="mt-6 space-y-4">
          <div className="rounded-lg bg-white p-5">
            <div className="flex items-center gap-2 text-sm text-gray-500">
              <MapPin className="h-4 w-4" />
              <span className="font-medium">{t("orders.deliveryAddress")}</span>
            </div>
            <p className="mt-1 text-foreground">{order.delivery_address}</p>
          </div>

          <div className="rounded-lg bg-white p-5">
            <div className="flex items-center gap-2 text-sm text-gray-500">
              <Calendar className="h-4 w-4" />
              <span className="font-medium">{t("orders.deliveryFrequency")}</span>
            </div>
            <p className="mt-1 text-foreground">
              {t(`frequency.${order.delivery_frequency}`)}
            </p>
          </div>

          {order.notes && (
            <div className="rounded-lg bg-white p-5">
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <MessageSquare className="h-4 w-4" />
                <span className="font-medium">{t("orders.notes")}</span>
              </div>
              <p className="mt-1 text-foreground">{order.notes}</p>
            </div>
          )}
        </div>

        {/* Items grouped by farmer */}
        <section className="mt-6">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("orders.items")} ({order.items.length})
          </h2>

          <div className="mt-3 space-y-4">
            {[...farmerGroups.entries()].map(([farmerId, items], groupIdx) => {
              const farmer = items[0]?.farmer;
              const groupTotal = items.reduce(
                (sum, item) =>
                  sum + item.quantity_kg * (item.quoted_price_per_kg ?? item.price_per_kg),
                0,
              );

              return (
                <div key={farmerId} className="rounded-lg bg-white p-4">
                  <div className="mb-3 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="flex h-6 w-6 items-center justify-center rounded-full bg-emerald-100 text-xs font-bold text-emerald-600">
                        {groupIdx + 1}
                      </span>
                      <span className="text-sm font-semibold text-foreground">
                        {farmer?.name ?? t("orders.unknownFarmer")}
                      </span>
                    </div>
                    <span className="text-sm font-bold">
                      NPR {groupTotal.toLocaleString()}
                    </span>
                  </div>

                  <div className="space-y-2">
                    {items.map((item) => {
                      const name =
                        locale === "ne"
                          ? item.listing?.name_ne
                          : item.listing?.name_en;
                      const hasQuote = item.quoted_price_per_kg !== null;
                      const priceChanged =
                        hasQuote && item.quoted_price_per_kg !== item.price_per_kg;

                      return (
                        <div
                          key={item.id}
                          className="flex items-center gap-3 rounded-md bg-gray-50 p-3"
                        >
                          <div className="relative h-10 w-10 shrink-0 overflow-hidden rounded bg-gray-100">
                            {item.listing?.photos?.[0] ? (
                              <Image
                                src={item.listing.photos[0]}
                                alt={name ?? ""}
                                fill
                                sizes="40px"
                                className="object-cover"
                                unoptimized
                              />
                            ) : (
                              <div className="flex h-full w-full items-center justify-center text-sm text-gray-300">
                                🌿
                              </div>
                            )}
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="truncate text-sm font-semibold">{name}</p>
                            <p className="text-xs text-gray-500">
                              {item.quantity_kg} kg ×{" "}
                              {hasQuote ? (
                                <>
                                  <span
                                    className={
                                      priceChanged
                                        ? "line-through text-gray-400 mr-1"
                                        : ""
                                    }
                                  >
                                    NPR {item.price_per_kg}
                                  </span>
                                  {priceChanged && (
                                    <span className="font-medium text-foreground">
                                      NPR {item.quoted_price_per_kg}
                                    </span>
                                  )}
                                </>
                              ) : (
                                <span>NPR {item.price_per_kg}</span>
                              )}
                            </p>
                            {item.farmer_notes && (
                              <p className="mt-1 text-xs italic text-gray-500">
                                &quot;{item.farmer_notes}&quot;
                              </p>
                            )}
                          </div>
                          <Badge color={ITEM_STATUS_COLORS[item.status] ?? "primary"}>
                            {t(`itemStatus.${item.status}`)}
                          </Badge>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* Total */}
        <div className="mt-6 rounded-lg bg-white p-5">
          <div className="flex justify-between text-lg font-bold">
            <span>{t("orders.total")}</span>
            <span>NPR {Number(order.total_amount).toLocaleString()}</span>
          </div>
        </div>

        {/* Actions */}
        {(canAccept || canCancel) && (
          <div className="mt-6 flex gap-3">
            {canAccept && (
              <Button
                variant="primary"
                className="flex-1 h-14"
                onClick={handleAccept}
                disabled={actionLoading}
              >
                {actionLoading ? (
                  <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                ) : (
                  <CheckCircle className="mr-2 h-5 w-5" />
                )}
                {t("orders.acceptQuotes")}
              </Button>
            )}
            {canCancel && (
              <Button
                variant="outline"
                className="flex-1 h-14 border-red-500 text-red-500 hover:bg-red-500 hover:text-white"
                onClick={handleCancel}
                disabled={actionLoading}
              >
                {actionLoading ? (
                  <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                ) : (
                  <XCircle className="mr-2 h-5 w-5" />
                )}
                {t("orders.cancelOrder")}
              </Button>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
