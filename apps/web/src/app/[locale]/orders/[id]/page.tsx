"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
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
  Shield,
  AlertCircle,
  RefreshCw,
  FileText,
  AlertTriangle,
  XCircle,
  Package,
} from "lucide-react";
import dynamic from "next/dynamic";
import { OrderStatus, OrderItemStatus } from "@jirisewa/shared";
import {
  getOrder,
  cancelOrder,
  confirmDelivery,
  checkReorderAvailability,
} from "@/lib/actions/orders";
import { retryEsewaPayment, retryKhaltiPayment, retryConnectIPSPayment } from "@/lib/actions/payments";
import type { ReorderItemAvailability } from "@/lib/helpers/orders";
import { useCart } from "@/lib/cart";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import { Button } from "@/components/ui/Button";
import type { OrderWithDetails } from "@/lib/types/order";
import type { EsewaPaymentFormData, ConnectIPSPaymentFormData } from "@/lib/types/order";
import type { Locale } from "@/lib/i18n";
import { parseGeoPoint } from "@/lib/types/trip";

const RiderTrackingSection = dynamic(
  () => import("@/components/orders/RiderTrackingSection"),
  { ssr: false },
);

/**
 * Parse delivery_location (PostGIS geography) into {lat, lng}.
 * Handles both GeoJSON and WKT from Supabase.
 */
function parseDeliveryLocation(
  value: unknown,
): { lat: number; lng: number } | null {
  if (!value || typeof value !== "string") return null;
  try {
    return parseGeoPoint(value);
  } catch {
    return null;
  }
}

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
  const searchParams = useSearchParams();
  const t = useTranslations("orders");
  const esewaFormRef = useRef<HTMLFormElement>(null);
  const connectipsFormRef = useRef<HTMLFormElement>(null);
  const { addItem, clearCart } = useCart();

  const [order, setOrder] = useState<OrderWithDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [esewaForm, setEsewaForm] = useState<EsewaPaymentFormData | null>(null);
  const [connectipsForm, setConnectipsForm] = useState<ConnectIPSPaymentFormData | null>(null);

  // Derive payment status message from URL params (after eSewa redirect)
  const paymentMessage = useMemo(() => {
    const paymentParam = searchParams.get("payment");
    if (paymentParam === "success") return t("paymentSuccess");
    if (paymentParam === "failed") return t("paymentFailed");
    if (paymentParam === "verification_failed") return t("paymentVerificationFailed");
    return null;
  }, [searchParams, t]);

  // Auto-submit payment forms when set
  useEffect(() => {
    if (esewaForm && esewaFormRef.current) {
      esewaFormRef.current.submit();
    }
  }, [esewaForm]);

  useEffect(() => {
    if (connectipsForm && connectipsFormRef.current) {
      connectipsFormRef.current.submit();
    }
  }, [connectipsForm]);

  // Reorder state
  const [reorderLoading, setReorderLoading] = useState(false);
  const [reorderItems, setReorderItems] = useState<ReorderItemAvailability[] | null>(null);
  const [reorderError, setReorderError] = useState<string | null>(null);

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

  const handleRetryEsewaPayment = async () => {
    setActionLoading(true);
    setError(null);
    const result = await retryEsewaPayment(orderId);
    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      setEsewaForm(result.data);
    }
    setActionLoading(false);
  };

  const handleRetryKhaltiPayment = async () => {
    setActionLoading(true);
    setError(null);
    const result = await retryKhaltiPayment(orderId);
    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      window.location.href = result.data.paymentUrl;
    }
    setActionLoading(false);
  };

  const handleRetryConnectIPSPayment = async () => {
    setActionLoading(true);
    setError(null);
    const result = await retryConnectIPSPayment(orderId);
    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      setConnectipsForm(result.data);
    }
    setActionLoading(false);
  };

  const handleCheckReorder = async () => {
    setReorderLoading(true);
    setReorderError(null);
    setReorderItems(null);

    const result = await checkReorderAvailability(orderId);

    if (result.error) {
      setReorderError(result.error);
    } else if (result.data) {
      setReorderItems(result.data);
    }

    setReorderLoading(false);
  };

  const handleAddToCart = () => {
    if (!reorderItems) return;

    const availableItems = reorderItems.filter((item) => item.available);
    if (availableItems.length === 0) return;

    clearCart();

    for (const item of availableItems) {
      const qty = Math.min(
        item.originalQtyKg,
        item.availableQtyKg ?? item.originalQtyKg,
      );
      addItem({
        listingId: item.listingId,
        farmerId: item.farmerId,
        quantityKg: qty,
        pricePerKg: item.currentPricePerKg ?? item.originalPricePerKg,
        nameEn: item.nameEn,
        nameNe: item.nameNe,
        farmerName: item.farmerName,
        photo: item.photo,
      });
    }

    router.push(`/${locale}/cart`);
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
  const isTerminal = isDelivered || isCancelled || order.status === OrderStatus.Disputed;

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

  const availableCount = reorderItems?.filter((i) => i.available).length ?? 0;
  const unavailableCount = reorderItems
    ? reorderItems.length - availableCount
    : 0;

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

        {/* Rider tracking map */}
        {order.rider_trip_id &&
          !isCancelled &&
          !isDelivered &&
          (() => {
            const deliveryLoc = parseDeliveryLocation(order.delivery_location);
            return deliveryLoc ? (
              <RiderTrackingSection
                tripId={order.rider_trip_id}
                deliveryLocation={deliveryLoc}
                orderStatus={order.status}
              />
            ) : null;
          })()}

        {/* Items — grouped by farmer */}
        <section className="mt-6">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("items")}
          </h2>
          {(() => {
            // Group items by farmer
            const farmerGroups = new Map<string, typeof order.items>();
            for (const item of order.items) {
              const fid = item.farmer?.id ?? item.farmer_id;
              const group = farmerGroups.get(fid) ?? [];
              group.push(item);
              farmerGroups.set(fid, group);
            }
            // Sort groups by pickup_sequence
            const sortedGroups = [...farmerGroups.entries()].sort(
              (a, b) => (a[1][0].pickup_sequence ?? 0) - (b[1][0].pickup_sequence ?? 0),
            );
            const isMultiFarmer = sortedGroups.length > 1;

            return (
              <div className="mt-3 space-y-4">
                {isMultiFarmer && (
                  <p className="text-xs text-gray-500 italic">
                    {t("multiFarmerOrder", { count: sortedGroups.length })}
                  </p>
                )}
                {sortedGroups.map(([farmerId, items], groupIdx) => {
                  const pickupStatus = items[0].pickup_status;
                  return (
                    <div key={farmerId}>
                      {isMultiFarmer && (
                        <div className="mb-2 flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-xs font-bold text-primary">
                              {groupIdx + 1}
                            </span>
                            <span className="text-xs font-semibold text-gray-600">
                              {t("fromFarmer", { farmer: items[0].farmer?.name ?? "" })}
                            </span>
                          </div>
                          {pickupStatus && (
                            <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium ${
                              pickupStatus === OrderItemStatus.PickedUp
                                ? "bg-green-100 text-green-700"
                                : pickupStatus === OrderItemStatus.Unavailable
                                ? "bg-red-100 text-red-700"
                                : "bg-amber-100 text-amber-700"
                            }`}>
                              {pickupStatus === OrderItemStatus.PickedUp ? (
                                <><CheckCircle className="h-3 w-3" /> {t("pickupStatusPickedUp")}</>
                              ) : pickupStatus === OrderItemStatus.Unavailable ? (
                                <><XCircle className="h-3 w-3" /> {t("pickupStatusUnavailable")}</>
                              ) : (
                                <><Package className="h-3 w-3" /> {t("pickupStatusPending")}</>
                              )}
                            </span>
                          )}
                        </div>
                      )}
                      <div className="space-y-2">
                        {items.map((item) => {
                          const itemName =
                            locale === "ne"
                              ? item.listing?.name_ne
                              : item.listing?.name_en;
                          return (
                            <div
                              key={item.id}
                              className={`flex items-center gap-3 rounded-lg bg-white p-3 ${
                                pickupStatus === OrderItemStatus.Unavailable ? "opacity-50" : ""
                              }`}
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
                                  {!isMultiFarmer && t("fromFarmer", { farmer: item.farmer?.name ?? "" })}
                                  {!isMultiFarmer && " · "}
                                  {item.quantity_kg} kg
                                </p>
                              </div>
                              <div className="text-right">
                                <p className="text-sm font-bold">
                                  NPR {Number(item.subtotal).toFixed(2)}
                                </p>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </div>
            );
          })()}
        </section>

        {/* Farmer payouts (when available) */}
        {order.farmerPayouts && order.farmerPayouts.length > 1 && (
          <section className="mt-6 rounded-lg bg-white p-4">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
              {t("farmerPayouts")}
            </h2>
            <div className="mt-3 space-y-2">
              {order.farmerPayouts.map((payout) => {
                const farmerName = order.items.find(
                  (i) => (i.farmer?.id ?? i.farmer_id) === payout.farmer_id,
                )?.farmer?.name ?? "Unknown";
                return (
                  <div key={payout.id} className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">{farmerName}</span>
                    <div className="flex items-center gap-2">
                      <span className="font-medium">
                        NPR {Number(payout.amount).toFixed(2)}
                      </span>
                      <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${
                        payout.status === "settled"
                          ? "bg-green-100 text-green-700"
                          : payout.status === "refunded"
                          ? "bg-red-100 text-red-700"
                          : "bg-amber-100 text-amber-700"
                      }`}>
                        {payout.status === "settled"
                          ? t("payoutSettled")
                          : payout.status === "refunded"
                          ? t("payoutRefunded")
                          : t("payoutPending")}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
        )}

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

        {/* Payment message from eSewa redirect */}
        {paymentMessage && (
          <div className={`mt-6 rounded-lg p-4 text-center ${
            searchParams.get("payment") === "success"
              ? "bg-green-50"
              : "bg-amber-50"
          }`}>
            {searchParams.get("payment") === "success" ? (
              <Shield className="mx-auto h-6 w-6 text-green-600" />
            ) : (
              <AlertCircle className="mx-auto h-6 w-6 text-amber-600" />
            )}
            <p className={`mt-1 text-sm font-medium ${
              searchParams.get("payment") === "success"
                ? "text-green-700"
                : "text-amber-700"
            }`}>
              {paymentMessage}
            </p>
          </div>
        )}

        {/* Digital payment escrow status */}
        {["esewa", "khalti", "connectips"].includes(order.payment_method) && order.payment_status === "escrowed" && (
          <section className="mt-6 rounded-lg bg-blue-50 p-4">
            <div className="flex items-center gap-2">
              <Shield className="h-5 w-5 text-blue-600 shrink-0" />
              <div>
                <p className="font-semibold text-blue-700 text-sm">{t("paymentEscrowed")}</p>
                <p className="text-xs text-blue-600">{t("paymentEscrowedHint")}</p>
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
            <div className="flex justify-between text-sm font-medium">
              <span className="text-gray-500">{t("deliveryFee")}</span>
              <span>NPR {Number(order.delivery_fee).toFixed(2)}</span>
            </div>
            {Number(order.delivery_fee) > 0 && (
              <div className="ml-4 space-y-1 border-l-2 border-gray-100 pl-3">
                <div className="flex justify-between text-xs text-gray-400">
                  <span>{t("baseFee")}</span>
                  <span>NPR {Number(order.delivery_fee_base).toFixed(2)}</span>
                </div>
                {order.delivery_distance_km != null && (
                  <div className="flex justify-between text-xs text-gray-400">
                    <span>{t("distanceFee", { km: Number(order.delivery_distance_km).toFixed(1) })}</span>
                    <span>NPR {Number(order.delivery_fee_distance).toFixed(2)}</span>
                  </div>
                )}
                <div className="flex justify-between text-xs text-gray-400">
                  <span>{t("weightFee", { kg: order.items.reduce((s, i) => s + Number(i.quantity_kg), 0).toFixed(1) })}</span>
                  <span>NPR {Number(order.delivery_fee_weight).toFixed(2)}</span>
                </div>
              </div>
            )}
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
              <span className="capitalize">
                {order.payment_method === "esewa" ? "eSewa"
                  : order.payment_method === "khalti" ? "Khalti"
                  : order.payment_method === "connectips" ? "connectIPS"
                  : order.payment_method}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">{t("paymentStatus")}</span>
              <span className={`capitalize font-medium ${
                order.payment_status === "escrowed" ? "text-blue-600" :
                order.payment_status === "settled" ? "text-green-600" :
                order.payment_status === "refunded" ? "text-amber-600" :
                "text-gray-700"
              }`}>
                {t(`paymentStatusValues.${order.payment_status}`)}
              </span>
            </div>
          </div>
        </section>

        {/* Receipt for delivered orders */}
        {isDelivered && (
          <section className="mt-6 rounded-lg border-2 border-green-200 bg-green-50 p-4">
            <div className="flex items-center gap-2">
              <FileText className="h-5 w-5 text-green-600" />
              <h2 className="text-sm font-semibold uppercase tracking-wider text-green-700">
                {t("receipt")}
              </h2>
            </div>
            <div className="mt-3 space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-600">{t("receiptOrderId")}</span>
                <span className="font-mono text-xs text-gray-500">
                  {order.id.slice(0, 8).toUpperCase()}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">{t("receiptDate")}</span>
                <span>{dateStr}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">{t("receiptItems")}</span>
                <span>{order.items.length}</span>
              </div>
              {order.items.map((item) => {
                const name =
                  locale === "ne"
                    ? item.listing?.name_ne
                    : item.listing?.name_en;
                return (
                  <div key={item.id} className="flex justify-between pl-4 text-xs text-gray-500">
                    <span>{name} ({item.quantity_kg} kg)</span>
                    <span>NPR {Number(item.subtotal).toFixed(2)}</span>
                  </div>
                );
              })}
              <div className="border-t border-green-200 pt-1">
                <div className="flex justify-between">
                  <span className="text-gray-600">{t("receiptProduce")}</span>
                  <span>NPR {Number(order.total_price).toFixed(2)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">{t("receiptDelivery")}</span>
                  <span>NPR {Number(order.delivery_fee).toFixed(2)}</span>
                </div>
                <div className="flex justify-between font-bold text-green-700">
                  <span>{t("receiptTotal")}</span>
                  <span>
                    NPR{" "}
                    {(
                      Number(order.total_price) + Number(order.delivery_fee)
                    ).toFixed(2)}
                  </span>
                </div>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">{t("receiptPayment")}</span>
                <span className="capitalize">{order.payment_method}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">{t("receiptPaymentStatus")}</span>
                <span className="capitalize">{order.payment_status}</span>
              </div>
            </div>
          </section>
        )}

        {/* Actions */}
        <section className="mt-6 space-y-3">
          {/* Retry payment for unpaid digital payment orders */}
          {order.payment_method === "esewa" &&
            order.payment_status === "pending" &&
            order.status !== OrderStatus.Cancelled && (
            <Button
              variant="primary"
              className="w-full h-14 text-base"
              onClick={handleRetryEsewaPayment}
              disabled={actionLoading}
            >
              {actionLoading ? (
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              ) : (
                <span className="mr-2 text-lg font-bold">e</span>
              )}
              {t("retryEsewaPayment")}
            </Button>
          )}

          {order.payment_method === "khalti" &&
            order.payment_status === "pending" &&
            order.status !== OrderStatus.Cancelled && (
            <Button
              variant="primary"
              className="w-full h-14 text-base"
              onClick={handleRetryKhaltiPayment}
              disabled={actionLoading}
            >
              {actionLoading ? (
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              ) : (
                <span className="mr-2 text-lg font-bold text-purple-600">K</span>
              )}
              {t("retryKhaltiPayment")}
            </Button>
          )}

          {order.payment_method === "connectips" &&
            order.payment_status === "pending" &&
            order.status !== OrderStatus.Cancelled && (
            <Button
              variant="primary"
              className="w-full h-14 text-base"
              onClick={handleRetryConnectIPSPayment}
              disabled={actionLoading}
            >
              {actionLoading ? (
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              ) : (
                <span className="mr-2 text-sm font-bold text-blue-600">IPS</span>
              )}
              {t("retryConnectIPSPayment")}
            </Button>
          )}

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
              {["esewa", "khalti", "connectips"].includes(order.payment_method) && order.payment_status === "settled" && (
                <p className="mt-1 text-sm text-green-600">{t("paymentSettled")}</p>
              )}
            </div>
          )}

          {/* Reorder section for terminal orders */}
          {isTerminal && (
            <div className="mt-4">
              {!reorderItems && (
                <Button
                  variant="secondary"
                  className="w-full h-14 text-base"
                  onClick={handleCheckReorder}
                  disabled={reorderLoading}
                >
                  {reorderLoading ? (
                    <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                  ) : (
                    <RefreshCw className="mr-2 h-5 w-5" />
                  )}
                  {reorderLoading ? t("reorderChecking") : t("reorder")}
                </Button>
              )}

              {reorderError && (
                <div className="mt-3 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {reorderError}
                </div>
              )}

              {reorderItems && (
                <div className="mt-3 rounded-lg bg-white p-4 space-y-3">
                  <h3 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
                    {t("reorderAvailability")}
                  </h3>

                  <div className="space-y-2">
                    {reorderItems.map((item) => {
                      const name =
                        locale === "ne" ? item.nameNe : item.nameEn;
                      const priceChanged =
                        item.available &&
                        item.currentPricePerKg !== null &&
                        item.currentPricePerKg !== item.originalPricePerKg;
                      return (
                        <div
                          key={item.listingId}
                          className={`flex items-center gap-3 rounded-md p-2 ${
                            item.available ? "bg-green-50" : "bg-gray-100"
                          }`}
                        >
                          <div className="relative h-10 w-10 shrink-0 overflow-hidden rounded bg-gray-100">
                            {item.photo ? (
                              <Image
                                src={item.photo}
                                alt={name}
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
                            <p className="truncate text-sm font-medium">
                              {name}
                            </p>
                            <p className="text-xs text-gray-500">
                              {item.originalQtyKg} kg
                              {priceChanged && (
                                <span className="ml-1 text-amber-600">
                                  (NPR {item.originalPricePerKg} → {item.currentPricePerKg})
                                </span>
                              )}
                            </p>
                          </div>
                          <span
                            className={`text-xs font-medium ${
                              item.available
                                ? "text-green-600"
                                : "text-gray-400"
                            }`}
                          >
                            {item.available
                              ? t("reorderAvailable")
                              : t("reorderUnavailable")}
                          </span>
                        </div>
                      );
                    })}
                  </div>

                  {unavailableCount > 0 && (
                    <div className="flex items-start gap-2 rounded-md bg-amber-50 p-3 text-xs text-amber-700">
                      <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                      <span>
                        {t("reorderPartial", { count: unavailableCount })}
                      </span>
                    </div>
                  )}

                  {availableCount > 0 && (
                    <Button
                      variant="primary"
                      className="w-full h-14 text-base"
                      onClick={handleAddToCart}
                    >
                      <RefreshCw className="mr-2 h-5 w-5" />
                      {t("reorderAddToCart", { count: availableCount })}
                    </Button>
                  )}

                  {availableCount === 0 && (
                    <p className="text-center text-sm text-gray-500">
                      {t("reorderNoneAvailable")}
                    </p>
                  )}
                </div>
              )}
            </div>
          )}
        </section>
      </div>

      {/* Hidden form for eSewa redirect */}
      {esewaForm && (
        <form
          ref={esewaFormRef}
          method="POST"
          action={esewaForm.url}
          className="hidden"
        >
          {Object.entries(esewaForm.fields).map(([key, value]) => (
            <input key={key} type="hidden" name={key} value={value} />
          ))}
        </form>
      )}

      {/* Hidden form for connectIPS redirect */}
      {connectipsForm && (
        <form
          ref={connectipsFormRef}
          method="POST"
          action={connectipsForm.url}
          className="hidden"
        >
          {Object.entries(connectipsForm.fields).map(([key, value]) => (
            <input key={key} type="hidden" name={key} value={value} />
          ))}
        </form>
      )}
    </main>
  );
}
