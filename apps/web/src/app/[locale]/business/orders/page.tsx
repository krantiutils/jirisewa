"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import {
  Package,
  Plus,
  Search,
  Loader2,
  ShoppingCart,
  Calendar,
  X,
} from "lucide-react";
import {
  listBulkOrders,
  getBusinessProfile,
  createBulkOrder,
} from "@/lib/actions/business";
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

type NewOrderItem = {
  listingId: string;
  farmerId: string;
  farmerName: string;
  nameEn: string;
  nameNe: string;
  photo: string | null;
  pricePerKg: number;
  quantityKg: number;
};

function BusinessOrdersPageInner() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const searchParams = useSearchParams();
  const t = useTranslations("business");

  const [orders, setOrders] = useState<BulkOrderWithDetails[]>([]);
  const [loading, setLoading] = useState(true);

  // New order form state
  const showNewForm = searchParams.get("action") === "new";
  const [newItems, setNewItems] = useState<NewOrderItem[]>([]);
  const [deliveryAddress, setDeliveryAddress] = useState("");
  const [deliveryFrequency, setDeliveryFrequency] = useState<"once" | "weekly" | "biweekly" | "monthly">("once");
  const [notes, setNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Produce search for adding items
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<NewOrderItem[]>([]);
  const [searching, setSearching] = useState(false);

  useEffect(() => {
    async function load() {
      const [profileResult, ordersResult] = await Promise.all([
        getBusinessProfile(),
        listBulkOrders(),
      ]);

      if (!profileResult.data) {
        router.push(`/${locale}/business/register`);
        return;
      }

      setOrders(ordersResult.data ?? []);
      setLoading(false);
    }
    load();
  }, [locale, router]);

  const searchProduce = useCallback(async (query: string) => {
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    try {
      const res = await fetch(
        `/api/produce?search=${encodeURIComponent(query)}&limit=10`,
      );
      if (res.ok) {
        const data = await res.json();
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        setSearchResults((data ?? []).map((item: any) => ({
          listingId: item.id,
          farmerId: item.farmer_id,
          farmerName: item.farmer_name ?? "Unknown",
          nameEn: item.name_en,
          nameNe: item.name_ne,
          photo: item.photos?.[0] ?? null,
          pricePerKg: item.price_per_kg,
          quantityKg: 10, // default bulk quantity
        })));
      }
    } catch (err) {
      console.error("searchProduce error:", err);
    }
    setSearching(false);
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery.trim()) {
        searchProduce(searchQuery.trim());
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [searchQuery, searchProduce]);

  const addItem = (item: NewOrderItem) => {
    const existing = newItems.find((i) => i.listingId === item.listingId);
    if (existing) return;
    setNewItems([...newItems, item]);
    setSearchQuery("");
    setSearchResults([]);
  };

  const removeItem = (listingId: string) => {
    setNewItems(newItems.filter((i) => i.listingId !== listingId));
  };

  const updateItemQuantity = (listingId: string, qty: number) => {
    setNewItems(
      newItems.map((i) => (i.listingId === listingId ? { ...i, quantityKg: qty } : i)),
    );
  };

  const handleSubmitOrder = async () => {
    if (newItems.length === 0) {
      setError(t("orders.noItems"));
      return;
    }
    if (!deliveryAddress.trim()) {
      setError(t("orders.noAddress"));
      return;
    }

    setSubmitting(true);
    setError(null);

    const result = await createBulkOrder({
      delivery_address: deliveryAddress,
      delivery_frequency: deliveryFrequency,
      notes: notes || undefined,
      items: newItems.map((item) => ({
        listingId: item.listingId,
        farmerId: item.farmerId,
        quantityKg: item.quantityKg,
        pricePerKg: item.pricePerKg,
      })),
    });

    if (result.error) {
      setError(result.error);
      setSubmitting(false);
      return;
    }

    router.push(`/${locale}/business/orders/${result.data!.orderId}`);
  };

  if (loading) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  const totalNewOrder = newItems.reduce(
    (sum, item) => sum + item.quantityKg * item.pricePerKg,
    0,
  );

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-foreground">
            {t("orders.title")}
          </h1>
          {!showNewForm && (
            <Button
              variant="primary"
              onClick={() => router.push(`/${locale}/business/orders?action=new`)}
            >
              <Plus className="mr-2 h-5 w-5" />
              {t("orders.newOrder")}
            </Button>
          )}
        </div>

        {/* New order form */}
        {showNewForm && (
          <div className="mt-6 rounded-lg bg-white p-6">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-foreground">
                {t("orders.createNew")}
              </h2>
              <button
                onClick={() => router.push(`/${locale}/business/orders`)}
                className="text-sm text-gray-500 hover:text-gray-700"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {error && (
              <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
                {error}
              </div>
            )}

            {/* Search produce */}
            <div className="mb-4">
              <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                {t("orders.searchProduce")}
              </label>
              <div className="relative mt-1">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder={t("orders.searchPlaceholder")}
                  className="w-full rounded-md bg-gray-100 py-2.5 pl-9 pr-3 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                />
                {searching && (
                  <Loader2 className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-gray-400" />
                )}
              </div>

              {/* Search results dropdown */}
              {searchResults.length > 0 && (
                <div className="mt-1 rounded-md border border-gray-200 bg-white max-h-48 overflow-y-auto">
                  {searchResults.map((item) => {
                    const name = locale === "ne" ? item.nameNe : item.nameEn;
                    return (
                      <button
                        key={item.listingId}
                        type="button"
                        onClick={() => addItem(item)}
                        className="flex w-full items-center gap-3 px-3 py-2 text-left hover:bg-gray-50 transition-colors"
                      >
                        <div className="relative h-8 w-8 shrink-0 overflow-hidden rounded bg-gray-100">
                          {item.photo ? (
                            <Image
                              src={item.photo}
                              alt={name}
                              fill
                              sizes="32px"
                              className="object-cover"
                              unoptimized
                            />
                          ) : (
                            <div className="flex h-full w-full items-center justify-center text-xs text-gray-300">
                              🌿
                            </div>
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="truncate text-sm font-medium">{name}</p>
                          <p className="text-xs text-gray-500">
                            {item.farmerName} · NPR {item.pricePerKg}/kg
                          </p>
                        </div>
                        <Plus className="h-4 w-4 text-primary shrink-0" />
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Selected items */}
            {newItems.length > 0 && (
              <div className="mb-4">
                <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                  {t("orders.selectedItems")} ({newItems.length})
                </label>
                <div className="mt-2 space-y-2">
                  {newItems.map((item) => {
                    const name = locale === "ne" ? item.nameNe : item.nameEn;
                    return (
                      <div
                        key={item.listingId}
                        className="flex items-center gap-3 rounded-md bg-gray-50 p-3"
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
                          <p className="truncate text-sm font-semibold">{name}</p>
                          <p className="text-xs text-gray-500">
                            {item.farmerName} · NPR {item.pricePerKg}/kg
                          </p>
                        </div>
                        <div className="flex items-center gap-2">
                          <input
                            type="number"
                            min={1}
                            value={item.quantityKg}
                            onChange={(e) =>
                              updateItemQuantity(
                                item.listingId,
                                Math.max(1, Number(e.target.value)),
                              )
                            }
                            className="w-20 rounded-md bg-white px-2 py-1 text-sm text-center border-2 border-gray-200 focus:border-primary focus:outline-none"
                          />
                          <span className="text-xs text-gray-500">kg</span>
                        </div>
                        <button
                          onClick={() => removeItem(item.listingId)}
                          className="text-red-500 hover:text-red-700"
                        >
                          <X className="h-4 w-4" />
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Delivery details */}
            <div className="mb-4">
              <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                {t("orders.deliveryAddress")}
              </label>
              <input
                type="text"
                value={deliveryAddress}
                onChange={(e) => setDeliveryAddress(e.target.value)}
                placeholder={t("orders.deliveryAddressPlaceholder")}
                className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
              />
            </div>

            {/* Delivery Frequency */}
            <div className="mb-4">
              <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                <Calendar className="mr-1 inline h-3.5 w-3.5" />
                {t("orders.deliveryFrequency")}
              </label>
              <div className="mt-2 grid grid-cols-4 gap-2">
                {(["once", "weekly", "biweekly", "monthly"] as const).map((freq) => (
                  <button
                    key={freq}
                    type="button"
                    onClick={() => setDeliveryFrequency(freq)}
                    className={`rounded-md px-3 py-2 text-sm font-medium transition-all ${
                      deliveryFrequency === freq
                        ? "bg-primary text-white"
                        : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                    }`}
                  >
                    {t(`frequency.${freq}`)}
                  </button>
                ))}
              </div>
            </div>

            {/* Notes */}
            <div className="mb-4">
              <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                {t("orders.notes")}
              </label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder={t("orders.notesPlaceholder")}
                rows={3}
                className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all resize-none"
              />
            </div>

            {/* Order total + submit */}
            {newItems.length > 0 && (
              <div className="border-t pt-4">
                <div className="flex justify-between text-lg font-bold mb-4">
                  <span>{t("orders.estimatedTotal")}</span>
                  <span>NPR {totalNewOrder.toLocaleString()}</span>
                </div>
                <p className="text-xs text-gray-500 mb-4">
                  {t("orders.quotingNote")}
                </p>
                <Button
                  variant="primary"
                  className="w-full h-14 text-base"
                  onClick={handleSubmitOrder}
                  disabled={submitting || newItems.length === 0 || !deliveryAddress.trim()}
                >
                  {submitting ? (
                    <>
                      <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                      {t("orders.submitting")}
                    </>
                  ) : (
                    <>
                      <ShoppingCart className="mr-2 h-5 w-5" />
                      {t("orders.submitOrder")}
                    </>
                  )}
                </Button>
              </div>
            )}
          </div>
        )}

        {/* Order list */}
        {!showNewForm && (
          <div className="mt-6 space-y-3">
            {orders.length === 0 ? (
              <div className="rounded-lg bg-white p-12 text-center">
                <Package className="mx-auto h-12 w-12 text-gray-300" />
                <p className="mt-4 text-gray-500">{t("orders.noOrders")}</p>
              </div>
            ) : (
              orders.map((order) => {
                const dateStr = new Date(order.created_at).toLocaleDateString(
                  locale === "ne" ? "ne-NP" : "en-US",
                  { month: "short", day: "numeric", year: "numeric" },
                );
                const farmerCount = new Set(order.items.map((i) => i.farmer_id)).size;

                return (
                  <div
                    key={order.id}
                    onClick={() => router.push(`/${locale}/business/orders/${order.id}`)}
                    className="flex items-center justify-between rounded-lg bg-white p-4 transition-all duration-200 cursor-pointer hover:scale-[1.01]"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <Badge color={STATUS_COLORS[order.status] ?? "primary"}>
                          {t(`status.${order.status}`)}
                        </Badge>
                        <Badge color="primary">
                          {t(`frequency.${order.delivery_frequency}`)}
                        </Badge>
                        <span className="text-xs text-gray-500">{dateStr}</span>
                      </div>
                      <p className="mt-1 text-sm text-gray-600">
                        {order.items.length} {t("orders.items")} · {farmerCount}{" "}
                        {t("orders.farmers")}
                      </p>
                    </div>
                    <p className="font-bold text-foreground">
                      NPR {Number(order.total_amount).toLocaleString()}
                    </p>
                  </div>
                );
              })
            )}
          </div>
        )}
      </div>
    </main>
  );
}

export default function BusinessOrdersPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen bg-muted flex items-center justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </main>
      }
    >
      <BusinessOrdersPageInner />
    </Suspense>
  );
}
