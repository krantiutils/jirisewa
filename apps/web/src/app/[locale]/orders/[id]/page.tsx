"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import {
  ArrowLeft,
  MapPin,
  Clock,
  User,
  Star,
  Phone,
  Loader2,
  CheckCircle,
} from "lucide-react";
import { OrderStatus } from "@jirisewa/shared";
import { getOrder, cancelOrder, confirmDelivery } from "@/lib/actions/orders";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import { Button } from "@/components/ui/Button";
import type { OrderWithDetails } from "@/lib/types/order";
import type { Locale } from "@/lib/i18n";

const STATUS_STEPS: OrderStatus[] = [
  OrderStatus.Pending,
  OrderStatus.Matched,
  OrderStatus.PickedUp,
  OrderStatus.InTransit,
  OrderStatus.Delivered,
];

export default function OrderDetailPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const orderId = params.id as string;
  const router = useRouter();
  const t = useTranslations("orders");

  const [order, setOrder] = useState<OrderWithDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    async function load() {
      setLoading(true);
      const result = await getOrder(orderId);
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
    setError(null);
    const result = await cancelOrder(orderId);
    if (result.error) {
      setError(result.error);
    } else {
      const refreshed = await getOrder(orderId);
      if (refreshed.data) setOrder(refreshed.data);
    }
    setActionLoading(false);
  };

  const handleConfirmDelivery = async () => {
    setActionLoading(true);
    setError(null);
    const result = await confirmDelivery(orderId);
    if (result.error) {
      setError(result.error);
    } else {
      const refreshed = await getOrder(orderId);
      if (refreshed.data) setOrder(refreshed.data);
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
        <div className="mx-auto max-w-2xl px-4 py-16 text-center">
          <p className="text-gray-500">{error ?? t("notFound")}</p>
          <Button
            variant="outline"
            className="mt-4"
            onClick={() => router.push(`/${locale}/orders`)}
          >
            {t("backToOrders")}
          </Button>
        </div>
      </main>
    );
  }

  const currentStepIndex = STATUS_STEPS.indexOf(
    order.status as OrderStatus,
  );
  const isCancelled = order.status === OrderStatus.Cancelled;
  const isDelivered = order.status === OrderStatus.Delivered;

  const dateStr = new Date(order.created_at).toLocaleDateString(
    locale === "ne" ? "ne-NP" : "en-US",
    {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    },
  );

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-6 sm:px-6">
        {/* Back */}
        <button
          onClick={() => router.push(`/${locale}/orders`)}
          className="mb-4 inline-flex items-center gap-2 text-sm font-medium text-gray-500 hover:text-primary transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("backToOrders")}
        </button>

        {/* Header */}
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-2xl font-bold text-foreground">
              {t("orderDetail")}
            </h1>
            <p className="mt-1 text-sm text-gray-500">
              <Clock className="mr-1 inline h-3 w-3" />
              {dateStr}
            </p>
          </div>
          <OrderStatusBadge status={order.status as import("@/lib/types/order").OrderStatus} />
        </div>

        {error && (
          <div className="mt-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Status timeline */}
        {!isCancelled && (
          <section className="mt-6 rounded-lg bg-white p-4">
            <div className="flex items-center justify-between">
              {STATUS_STEPS.map((step, idx) => {
                const isCompleted = idx <= currentStepIndex;
                const isCurrent = idx === currentStepIndex;
                return (
                  <div key={step} className="flex flex-1 items-center">
                    <div className="flex flex-col items-center">
                      <div
                        className={`flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold ${
                          isCompleted
                            ? "bg-primary text-white"
                            : "bg-gray-200 text-gray-400"
                        } ${isCurrent ? "ring-2 ring-primary ring-offset-2" : ""}`}
                      >
                        {isCompleted ? (
                          <CheckCircle className="h-4 w-4" />
                        ) : (
                          idx + 1
                        )}
                      </div>
                      <span
                        className={`mt-1 text-[10px] ${
                          isCompleted
                            ? "font-semibold text-primary"
                            : "text-gray-400"
                        }`}
                      >
                        {t(`status.${step}`)}
                      </span>
                    </div>
                    {idx < STATUS_STEPS.length - 1 && (
                      <div
                        className={`h-0.5 flex-1 mx-1 ${
                          idx < currentStepIndex
                            ? "bg-primary"
                            : "bg-gray-200"
                        }`}
                      />
                    )}
                  </div>
                );
              })}
            </div>
          </section>
        )}

        {/* Items */}
        <section className="mt-6">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("items")}
          </h2>
          <div className="mt-3 space-y-2">
            {order.items.map((item) => {
              const itemName =
                locale === "ne"
                  ? item.listing?.name_ne
                  : item.listing?.name_en;
              return (
                <div
                  key={item.id}
                  className="flex items-center gap-3 rounded-lg bg-white p-3"
                >
                  <div className="relative h-12 w-12 shrink-0 overflow-hidden rounded bg-gray-100">
                    {item.listing?.photos?.[0] ? (
                      <Image
                        src={item.listing.photos[0]}
                        alt={itemName ?? ""}
                        fill
                        sizes="48px"
                        className="object-cover"
                        unoptimized
                      />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center text-lg text-gray-300">
                        🌿
                      </div>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="truncate text-sm font-semibold">{itemName}</p>
                    <p className="text-xs text-gray-500">
                      {t("fromFarmer", {
                        farmer: item.farmer?.name ?? "",
                      })}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-bold">
                      NPR {Number(item.subtotal).toFixed(2)}
                    </p>
                    <p className="text-xs text-gray-500">
                      {item.quantity_kg} kg
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* Delivery info */}
        <section className="mt-6 rounded-lg bg-white p-4">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            <MapPin className="mr-1 inline h-4 w-4" />
            {t("deliveryAddress")}
          </h2>
          <p className="mt-2 text-sm text-foreground">
            {order.delivery_address}
          </p>
        </section>

        {/* Rider info (if matched) */}
        {order.rider && (
          <section className="mt-6 rounded-lg bg-white p-4">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
              {t("riderInfo")}
            </h2>
            <div className="mt-3 flex items-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-secondary/10">
                {order.rider.avatar_url ? (
                  <Image
                    src={order.rider.avatar_url}
                    alt={order.rider.name}
                    width={48}
                    height={48}
                    className="rounded-full object-cover"
                    unoptimized
                  />
                ) : (
                  <User className="h-6 w-6 text-secondary" />
                )}
              </div>
              <div className="flex-1">
                <p className="font-semibold">{order.rider.name}</p>
                <div className="flex items-center gap-2 text-sm text-gray-500">
                  {order.rider.rating_avg > 0 && (
                    <span className="flex items-center gap-0.5">
                      <Star className="h-3 w-3 fill-amber-400 text-amber-400" />
                      {Number(order.rider.rating_avg).toFixed(1)}
                    </span>
                  )}
                  <span className="flex items-center gap-0.5">
                    <Phone className="h-3 w-3" />
                    {order.rider.phone}
                  </span>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Price summary */}
        <section className="mt-6 rounded-lg bg-white p-4">
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">{t("subtotal")}</span>
              <span>NPR {Number(order.total_price).toFixed(2)}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">{t("deliveryFee")}</span>
              <span>NPR {Number(order.delivery_fee).toFixed(2)}</span>
            </div>
            <div className="border-t pt-2">
              <div className="flex justify-between font-bold">
                <span>{t("total")}</span>
                <span>
                  NPR{" "}
                  {(
                    Number(order.total_price) + Number(order.delivery_fee)
                  ).toFixed(2)}
                </span>
              </div>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">{t("paymentMethod")}</span>
              <span className="capitalize">{order.payment_method}</span>
            </div>
          </div>
        </section>

        {/* Actions */}
        <section className="mt-6 space-y-3">
          {order.status === OrderStatus.InTransit && (
            <Button
              variant="primary"
              className="w-full h-14 text-base"
              onClick={handleConfirmDelivery}
              disabled={actionLoading}
            >
              {actionLoading ? (
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              ) : (
                <CheckCircle className="mr-2 h-5 w-5" />
              )}
              {t("confirmDelivery")}
            </Button>
          )}

          {(order.status === OrderStatus.Pending ||
            order.status === OrderStatus.Matched) && (
            <Button
              variant="outline"
              className="w-full h-14 text-base text-red-600 border-red-300 hover:bg-red-50 hover:text-red-700"
              onClick={handleCancel}
              disabled={actionLoading}
            >
              {actionLoading ? (
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              ) : null}
              {t("cancelOrder")}
            </Button>
          )}

          {isDelivered && (
            <div className="rounded-lg bg-green-50 p-4 text-center">
              <CheckCircle className="mx-auto h-8 w-8 text-green-600" />
              <p className="mt-2 font-semibold text-green-700">
                {t("deliveryConfirmed")}
              </p>
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
