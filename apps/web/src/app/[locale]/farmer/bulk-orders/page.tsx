"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import {
  Package,
  Loader2,
  Building2,
  ArrowLeft,
  CheckCircle,
  XCircle,
} from "lucide-react";
import {
  listFarmerBulkOrders,
  quoteBulkOrderItem,
  rejectBulkOrderItem,
} from "@/lib/actions/business";
import { Badge } from "@/components/ui/Badge";
import type { Locale } from "@/lib/i18n";
import type { BulkOrderWithDetails, BulkOrderItemWithDetails } from "@/lib/types/business";

const STATUS_COLORS: Record<string, "primary" | "accent" | "success" | "danger" | "warning"> = {
  submitted: "accent",
  quoted: "warning",
  accepted: "success",
  in_progress: "primary",
  fulfilled: "success",
};

export default function FarmerBulkOrdersPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("business");

  const [orders, setOrders] = useState<BulkOrderWithDetails[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedOrder, setExpandedOrder] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      const result = await listFarmerBulkOrders();
      setOrders(result.data ?? []);
      setLoading(false);
    }
    load();
  }, []);

  const handleQuote = async (itemId: string, price: number, notes: string) => {
    const result = await quoteBulkOrderItem(itemId, price, notes || undefined);
    if (!result.error) {
      // Reload
      const reload = await listFarmerBulkOrders();
      setOrders(reload.data ?? []);
    }
  };

  const handleReject = async (itemId: string, notes: string) => {
    const result = await rejectBulkOrderItem(itemId, notes || undefined);
    if (!result.error) {
      const reload = await listFarmerBulkOrders();
      setOrders(reload.data ?? []);
    }
  };

  if (loading) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
        <button
          onClick={() => router.push(`/${locale}/farmer/dashboard`)}
          className="mb-4 flex items-center gap-1 text-sm text-gray-500 hover:text-primary transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("farmerBulk.backToDashboard")}
        </button>

        <div className="flex items-center gap-3 mb-6">
          <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-emerald-100">
            <Building2 className="h-6 w-6 text-emerald-600" />
          </div>
          <h1 className="text-2xl font-bold text-foreground">
            {t("farmerBulk.title")}
          </h1>
        </div>

        {orders.length === 0 ? (
          <div className="rounded-lg bg-white p-12 text-center">
            <Package className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-4 text-gray-500">{t("farmerBulk.noOrders")}</p>
          </div>
        ) : (
          <div className="space-y-4">
            {orders.map((order) => {
              const isExpanded = expandedOrder === order.id;
              const businessName = order.business?.business_name ?? t("farmerBulk.unknownBusiness");
              const dateStr = new Date(order.created_at).toLocaleDateString(
                locale === "ne" ? "ne-NP" : "en-US",
                { month: "short", day: "numeric", year: "numeric" },
              );

              // Only show items for the current farmer
              const DEMO_FARMER_ID = "00000000-0000-0000-0000-000000000002";
              const myItems = order.items.filter(
                (i) => i.farmer_id === DEMO_FARMER_ID,
              );

              return (
                <div key={order.id} className="rounded-lg bg-white overflow-hidden">
                  <button
                    onClick={() =>
                      setExpandedOrder(isExpanded ? null : order.id)
                    }
                    className="w-full flex items-center justify-between p-4 text-left hover:bg-gray-50 transition-colors"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <Badge color={STATUS_COLORS[order.status] ?? "primary"}>
                          {t(`status.${order.status}`)}
                        </Badge>
                        <span className="text-xs text-gray-500">{dateStr}</span>
                      </div>
                      <p className="mt-1 text-sm font-semibold text-foreground">
                        {businessName}
                      </p>
                      <p className="text-xs text-gray-500">
                        {myItems.length} {t("farmerBulk.itemsForYou")} ·{" "}
                        {t(`frequency.${order.delivery_frequency}`)}
                      </p>
                    </div>
                  </button>

                  {isExpanded && (
                    <div className="border-t p-4 space-y-3">
                      {order.delivery_address && (
                        <p className="text-xs text-gray-500">
                          {t("orders.deliveryAddress")}: {order.delivery_address}
                        </p>
                      )}
                      {order.notes && (
                        <p className="text-xs italic text-gray-500">
                          {t("orders.notes")}: {order.notes}
                        </p>
                      )}
                      {myItems.map((item) => (
                        <FarmerBulkItemCard
                          key={item.id}
                          item={item}
                          locale={locale}
                          t={t}
                          onQuote={handleQuote}
                          onReject={handleReject}
                        />
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </main>
  );
}

function FarmerBulkItemCard({
  item,
  locale,
  t,
  onQuote,
  onReject,
}: {
  item: BulkOrderItemWithDetails;
  locale: Locale;
  t: ReturnType<typeof useTranslations>;
  onQuote: (itemId: string, price: number, notes: string) => Promise<void>;
  onReject: (itemId: string, notes: string) => Promise<void>;
}) {
  const [quotePrice, setQuotePrice] = useState(String(item.price_per_kg));
  const [farmerNotes, setFarmerNotes] = useState("");
  const [actionLoading, setActionLoading] = useState(false);

  const name = locale === "ne" ? item.listing?.name_ne : item.listing?.name_en;
  const isPending = item.status === "pending";

  const handleQuote = async () => {
    const price = parseFloat(quotePrice);
    if (isNaN(price) || price <= 0) return;
    setActionLoading(true);
    await onQuote(item.id, price, farmerNotes);
    setActionLoading(false);
  };

  const handleReject = async () => {
    setActionLoading(true);
    await onReject(item.id, farmerNotes);
    setActionLoading(false);
  };

  return (
    <div className="rounded-md bg-gray-50 p-3">
      <div className="flex items-center gap-3">
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
            {item.quantity_kg} kg · {t("farmerBulk.requestedPrice")}: NPR{" "}
            {item.price_per_kg}/kg
          </p>
        </div>
        {!isPending && (
          <Badge
            color={
              item.status === "quoted"
                ? "warning"
                : item.status === "accepted"
                  ? "success"
                  : item.status === "rejected"
                    ? "danger"
                    : "primary"
            }
          >
            {t(`itemStatus.${item.status}`)}
          </Badge>
        )}
      </div>

      {isPending && (
        <div className="mt-3 space-y-2">
          <div className="flex items-center gap-2">
            <label className="text-xs font-medium text-gray-500">
              {t("farmerBulk.yourPrice")}
            </label>
            <input
              type="number"
              min={1}
              step={0.01}
              value={quotePrice}
              onChange={(e) => setQuotePrice(e.target.value)}
              className="w-24 rounded-md bg-white px-2 py-1 text-sm text-center border-2 border-gray-200 focus:border-primary focus:outline-none"
            />
            <span className="text-xs text-gray-500">/kg</span>
          </div>
          <input
            type="text"
            value={farmerNotes}
            onChange={(e) => setFarmerNotes(e.target.value)}
            placeholder={t("farmerBulk.notesPlaceholder")}
            className="w-full rounded-md bg-white px-3 py-2 text-sm border-2 border-gray-200 focus:border-primary focus:outline-none"
          />
          <div className="flex gap-2">
            <button
              onClick={handleQuote}
              disabled={actionLoading}
              className="flex items-center gap-1 rounded-md bg-emerald-500 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-600 transition-colors disabled:opacity-50"
            >
              {actionLoading ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <CheckCircle className="h-4 w-4" />
              )}
              {t("farmerBulk.sendQuote")}
            </button>
            <button
              onClick={handleReject}
              disabled={actionLoading}
              className="flex items-center gap-1 rounded-md bg-red-500 px-4 py-2 text-sm font-medium text-white hover:bg-red-600 transition-colors disabled:opacity-50"
            >
              <XCircle className="h-4 w-4" />
              {t("farmerBulk.decline")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
