"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { Package, ArrowLeft, Loader2, CheckCircle, XCircle } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { getFarmerOrders } from "@/lib/actions/farmer-orders";
import { confirmFarmerPickup, markItemsUnavailable } from "@/lib/actions/orders";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import type { FarmerOrder } from "@/lib/actions/farmer-orders";
import type { OrderStatus } from "@/lib/types/order";
import type { Locale } from "@/lib/i18n";

type TabKey = "active" | "completed";

const ACTIVE_STATUSES = new Set(["pending", "matched", "picked_up", "in_transit"]);

export default function FarmerOrdersPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("farmerOrders");
  const tOrders = useTranslations("orders");
  const { user, loading: authLoading } = useAuth();

  const [orders, setOrders] = useState<FarmerOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabKey>("active");
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    if (!authLoading && !user) {
      router.replace(`/${locale}/auth/login`);
    }
  }, [authLoading, user, router, locale]);

  const loadOrders = useCallback(async () => {
    const result = await getFarmerOrders();
    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      setOrders(result.data);
    }
  }, []);

  useEffect(() => {
    if (!user) return;

    async function load() {
      setLoading(true);
      await loadOrders();
      setLoading(false);
    }

    load();
  }, [user, loadOrders]);

  const handlePickupAction = useCallback(
    async (action: "confirm" | "unavailable", orderId: string, farmerId: string) => {
      setActionLoading(true);
      setError(null);
      const result =
        action === "confirm"
          ? await confirmFarmerPickup(orderId, farmerId)
          : await markItemsUnavailable(orderId, farmerId);
      if (result.error) {
        setError(result.error);
      } else {
        await loadOrders();
      }
      setActionLoading(false);
    },
    [loadOrders],
  );

  const filteredOrders = useMemo(() => {
    if (activeTab === "active") {
      return orders.filter((o) => ACTIVE_STATUSES.has(o.status));
    }
    return orders.filter((o) => !ACTIVE_STATUSES.has(o.status));
  }, [orders, activeTab]);

  if (authLoading || !user) return null;

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
        <button
          onClick={() => router.push(`/${locale}/farmer/dashboard`)}
          className="mb-4 flex items-center gap-1 text-sm text-gray-500 hover:text-primary transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("backToDashboard")}
        </button>

        <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>

        {/* Tabs */}
        <div className="mt-6 flex gap-1 rounded-lg bg-white p-1">
          {(["active", "completed"] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 rounded-md px-4 py-2.5 text-sm font-medium transition-colors ${
                activeTab === tab
                  ? "bg-primary text-white"
                  : "text-gray-600 hover:bg-gray-100"
              }`}
            >
              {t(`tabs.${tab}`)}
            </button>
          ))}
        </div>

        {error && (
          <div className="mt-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {loading ? (
          <div className="py-12 flex justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
          </div>
        ) : filteredOrders.length === 0 ? (
          <div className="py-12 text-center">
            <Package className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-3 text-gray-500">{t("noOrders")}</p>
          </div>
        ) : (
          <div className="mt-4 space-y-3">
            {filteredOrders.map((order) => (
              <FarmerOrderCard
                key={order.id}
                order={order}
                locale={locale}
                t={t}
                tOrders={tOrders}
                userId={user.id}
                actionLoading={actionLoading}
                onPickupAction={handlePickupAction}
                onClick={() => router.push(`/${locale}/orders/${order.order_id}`)}
              />
            ))}
          </div>
        )}
      </div>
    </main>
  );
}

function FarmerOrderCard({
  order,
  locale,
  t,
  tOrders,
  userId,
  actionLoading,
  onPickupAction,
  onClick,
}: {
  order: FarmerOrder;
  locale: Locale;
  t: ReturnType<typeof useTranslations>;
  tOrders: ReturnType<typeof useTranslations>;
  userId: string;
  actionLoading: boolean;
  onPickupAction: (action: "confirm" | "unavailable", orderId: string, farmerId: string) => void;
  onClick: () => void;
}) {
  const firstItem = order.items[0];
  const itemCount = order.items.length;
  const firstItemName =
    locale === "ne"
      ? firstItem?.listing?.name_ne
      : firstItem?.listing?.name_en;

  const dateStr = new Date(order.created_at).toLocaleDateString(
    locale === "ne" ? "ne-NP" : "en-US",
    { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" },
  );

  const hasPendingPickup =
    order.status === "matched" &&
    order.items.some((i) => i.pickup_status === "pending_pickup");

  return (
    <Card onClick={onClick} className="border-2 border-border cursor-pointer">
      <div className="flex gap-3">
        <div className="relative h-16 w-16 shrink-0 overflow-hidden rounded-md bg-gray-100">
          {firstItem?.listing?.photos?.[0] ? (
            <Image
              src={firstItem.listing.photos[0]}
              alt={firstItemName ?? ""}
              fill
              sizes="64px"
              className="object-cover"
              unoptimized
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-xl text-gray-300">
              📦
            </div>
          )}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between">
            <div className="min-w-0">
              <p className="truncate font-semibold text-foreground">
                {firstItemName}
                {itemCount > 1 && ` +${itemCount - 1} ${tOrders("moreItems")}`}
              </p>
              <p className="text-xs text-gray-500">{dateStr}</p>
            </div>
            <OrderStatusBadge status={order.status as OrderStatus} />
          </div>
          <div className="mt-1 flex items-center justify-between text-sm">
            <span className="text-gray-500">
              {t("customer")}: {order.consumer_name}
            </span>
            <span className="font-bold">
              NPR {order.farmerSubtotal.toFixed(2)}
            </span>
          </div>
          {order.rider_name && (
            <p className="text-xs text-gray-400">
              {t("rider")}: {order.rider_name}
            </p>
          )}

          {hasPendingPickup && (
            <div className="mt-2 flex gap-2">
              <Button
                variant="primary"
                className="h-8 flex-1 text-xs"
                onClick={(e) => {
                  e.stopPropagation();
                  onPickupAction("confirm", order.order_id, userId);
                }}
                disabled={actionLoading}
              >
                <CheckCircle className="mr-1 h-3.5 w-3.5" />
                {actionLoading ? t("confirming") : t("confirmPickup")}
              </Button>
              <Button
                variant="outline"
                className="h-8 text-xs border-red-300 text-red-600 hover:bg-red-50"
                onClick={(e) => {
                  e.stopPropagation();
                  onPickupAction("unavailable", order.order_id, userId);
                }}
                disabled={actionLoading}
              >
                <XCircle className="mr-1 h-3.5 w-3.5" />
                {t("markUnavailable")}
              </Button>
            </div>
          )}
        </div>
      </div>
    </Card>
  );
}
