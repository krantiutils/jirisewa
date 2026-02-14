"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { Package } from "lucide-react";
import { OrderStatus } from "@jirisewa/shared";
import { listOrders } from "@/lib/actions/orders";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import type { OrderWithDetails } from "@/lib/types/order";
import type { Locale } from "@/lib/i18n";

type TabKey = "active" | "completed";

const ACTIVE_STATUSES = new Set([
  OrderStatus.Pending,
  OrderStatus.Matched,
  OrderStatus.PickedUp,
  OrderStatus.InTransit,
]);

export default function OrdersPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("orders");

  const [activeTab, setActiveTab] = useState<TabKey>("active");
  const [allOrders, setAllOrders] = useState<OrderWithDetails[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      setLoading(true);
      setError(null);

      const result = await listOrders();

      if (result.error) {
        setError(result.error);
        setAllOrders([]);
      } else if (result.data) {
        setAllOrders(result.data);
      }

      setLoading(false);
    }

    load();
  }, []);

  const orders = useMemo(() => {
    if (activeTab === "active") {
      return allOrders.filter((o) =>
        ACTIVE_STATUSES.has(o.status as OrderStatus),
      );
    }
    return allOrders.filter(
      (o) => !ACTIVE_STATUSES.has(o.status as OrderStatus),
    );
  }, [allOrders, activeTab]);

  const tabs: { key: TabKey; label: string }[] = [
    { key: "active", label: t("tabs.active") },
    { key: "completed", label: t("tabs.completed") },
  ];

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>

        {/* Tabs */}
        <div className="mt-6 flex gap-1 rounded-lg bg-white p-1">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex-1 rounded-md px-4 py-2.5 text-sm font-medium transition-colors ${
                activeTab === tab.key
                  ? "bg-primary text-white"
                  : "text-gray-600 hover:bg-gray-100"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {error && (
          <div className="mt-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {loading ? (
          <div className="py-12 text-center text-gray-500">
            {t("loading")}
          </div>
        ) : orders.length === 0 ? (
          <div className="py-12 text-center">
            <Package className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-3 text-gray-500">{t("noOrders")}</p>
            {activeTab === "active" && (
              <Button
                variant="outline"
                className="mt-4"
                onClick={() => router.push(`/${locale}/marketplace`)}
              >
                {t("browseMarketplace")}
              </Button>
            )}
          </div>
        ) : (
          <div className="mt-4 space-y-3">
            {orders.map((order) => (
              <OrderCard
                key={order.id}
                order={order}
                locale={locale}
                onClick={() => router.push(`/${locale}/orders/${order.id}`)}
              />
            ))}
          </div>
        )}
      </div>
    </main>
  );
}

function OrderCard({
  order,
  locale,
  onClick,
}: {
  order: OrderWithDetails;
  locale: Locale;
  onClick: () => void;
}) {
  const t = useTranslations("orders");
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

  return (
    <Card onClick={onClick} className="border-2 border-border cursor-pointer">
      <div className="flex gap-3">
        {/* First item thumbnail */}
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
                {itemCount > 1 &&
                  ` +${itemCount - 1} ${t("moreItems")}`}
              </p>
              <p className="text-xs text-gray-500">{dateStr}</p>
            </div>
            <OrderStatusBadge status={order.status as import("@/lib/types/order").OrderStatus} />
          </div>
          <div className="mt-2 flex items-center justify-between text-sm">
            <span className="text-gray-500">
              {t("totalItems", { count: itemCount })}
            </span>
            <span className="font-bold">NPR {Number(order.total_price).toFixed(2)}</span>
          </div>
        </div>
      </div>
    </Card>
  );
}
