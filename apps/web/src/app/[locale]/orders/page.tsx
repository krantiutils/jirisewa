"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { Package, Search, Filter, X } from "lucide-react";
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

const COMPLETED_STATUSES: OrderStatus[] = [
  OrderStatus.Delivered,
  OrderStatus.Cancelled,
  OrderStatus.Disputed,
];

export default function OrdersPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("orders");

  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authChecked, setAuthChecked] = useState(false);
  const [activeTab, setActiveTab] = useState<TabKey>("active");
  const [allOrders, setAllOrders] = useState<OrderWithDetails[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filters
  const [showFilters, setShowFilters] = useState(false);
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [farmerSearch, setFarmerSearch] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");

  // Check auth first
  useEffect(() => {
    async function checkAuth() {
      try {
        const res = await fetch("/api/auth/session");
        if (!res.ok || !(await res.json()).user) {
          router.replace(`/${locale}/auth/login`);
          return;
        }
        setIsAuthenticated(true);
      } catch {
        router.replace(`/${locale}/auth/login`);
        return;
      } finally {
        setAuthChecked(true);
      }
    }
    checkAuth();
  }, [locale, router]);

  useEffect(() => {
    if (!authChecked || !isAuthenticated) return;

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

  const hasActiveFilters = statusFilter || farmerSearch || dateFrom || dateTo;

  const clearFilters = () => {
    setStatusFilter("");
    setFarmerSearch("");
    setDateFrom("");
    setDateTo("");
  };

  const orders = useMemo(() => {
    let filtered = allOrders;

    // Tab filter
    if (activeTab === "active") {
      filtered = filtered.filter((o) =>
        ACTIVE_STATUSES.has(o.status as OrderStatus),
      );
    } else {
      filtered = filtered.filter(
        (o) => !ACTIVE_STATUSES.has(o.status as OrderStatus),
      );
    }

    // Status filter
    if (statusFilter) {
      filtered = filtered.filter((o) => o.status === statusFilter);
    }

    // Farmer search
    if (farmerSearch.trim()) {
      const search = farmerSearch.trim().toLowerCase();
      filtered = filtered.filter((o) =>
        o.items.some(
          (item) => item.farmer?.name?.toLowerCase().includes(search),
        ),
      );
    }

    // Date range
    if (dateFrom) {
      const from = new Date(dateFrom);
      from.setHours(0, 0, 0, 0);
      filtered = filtered.filter(
        (o) => new Date(o.created_at) >= from,
      );
    }
    if (dateTo) {
      const to = new Date(dateTo);
      to.setHours(23, 59, 59, 999);
      filtered = filtered.filter(
        (o) => new Date(o.created_at) <= to,
      );
    }

    return filtered;
  }, [allOrders, activeTab, statusFilter, farmerSearch, dateFrom, dateTo]);

  const tabs: { key: TabKey; label: string }[] = [
    { key: "active", label: t("tabs.active") },
    { key: "completed", label: t("tabs.completed") },
  ];

  // Status options for current tab
  const statusOptions =
    activeTab === "active"
      ? [OrderStatus.Pending, OrderStatus.Matched, OrderStatus.PickedUp, OrderStatus.InTransit]
      : COMPLETED_STATUSES;

  // Don't render until auth is checked
  if (!authChecked) {
    return null;
  }

  // Show loading state while checking auth
  if (!isAuthenticated) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-500">Please log in to view your orders...</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`flex items-center gap-1.5 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
              showFilters || hasActiveFilters
                ? "bg-primary text-white"
                : "bg-white text-gray-600 hover:bg-gray-100"
            }`}
          >
            <Filter className="h-4 w-4" />
            {t("filters")}
          </button>
        </div>

        {/* Filters panel */}
        {showFilters && (
          <div className="mt-4 rounded-lg bg-white p-4 space-y-3">
            {/* Farmer search */}
            <div>
              <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                {t("filterFarmer")}
              </label>
              <div className="relative mt-1">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  value={farmerSearch}
                  onChange={(e) => setFarmerSearch(e.target.value)}
                  placeholder={t("filterFarmerPlaceholder")}
                  className="w-full rounded-md bg-gray-100 py-2.5 pl-9 pr-3 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                />
              </div>
            </div>

            {/* Status filter */}
            <div>
              <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                {t("filterStatus")}
              </label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
              >
                <option value="">{t("filterStatusAll")}</option>
                {statusOptions.map((s) => (
                  <option key={s} value={s}>
                    {t(`status.${s}`)}
                  </option>
                ))}
              </select>
            </div>

            {/* Date range */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                  {t("filterDateFrom")}
                </label>
                <input
                  type="date"
                  value={dateFrom}
                  onChange={(e) => setDateFrom(e.target.value)}
                  className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                />
              </div>
              <div>
                <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                  {t("filterDateTo")}
                </label>
                <input
                  type="date"
                  value={dateTo}
                  onChange={(e) => setDateTo(e.target.value)}
                  className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                />
              </div>
            </div>

            {hasActiveFilters && (
              <button
                onClick={clearFilters}
                className="flex items-center gap-1 text-sm font-medium text-red-600 hover:text-red-700 transition-colors"
              >
                <X className="h-3.5 w-3.5" />
                {t("clearFilters")}
              </button>
            )}
          </div>
        )}

        {/* Tabs */}
        <div className="mt-6 flex gap-1 rounded-lg bg-white p-1">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => {
                setActiveTab(tab.key);
                setStatusFilter("");
              }}
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
            <p className="mt-3 text-gray-500">
              {hasActiveFilters ? t("noFilterResults") : t("noOrders")}
            </p>
            {hasActiveFilters ? (
              <button
                onClick={clearFilters}
                className="mt-3 text-sm font-medium text-primary hover:underline"
              >
                {t("clearFilters")}
              </button>
            ) : (
              activeTab === "active" && (
                <Button
                  variant="outline"
                  className="mt-4"
                  onClick={() => router.push(`/${locale}/marketplace`)}
                >
                  {t("browseMarketplace")}
                </Button>
              )
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
