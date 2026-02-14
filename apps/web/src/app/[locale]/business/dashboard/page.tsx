"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  Building2,
  Plus,
  Package,
  Clock,
  CheckCircle,
  Loader2,
} from "lucide-react";
import { getBusinessProfile, listBulkOrders } from "@/lib/actions/business";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import type { Locale } from "@/lib/i18n";
import type { BusinessProfile, BulkOrderWithDetails } from "@/lib/types/business";

const STATUS_COLORS: Record<string, "primary" | "accent" | "success" | "danger" | "warning"> = {
  draft: "primary",
  submitted: "accent",
  quoted: "warning",
  accepted: "success",
  in_progress: "primary",
  fulfilled: "success",
  cancelled: "danger",
};

export default function BusinessDashboardPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("business");

  const [profile, setProfile] = useState<BusinessProfile | null>(null);
  const [orders, setOrders] = useState<BulkOrderWithDetails[]>([]);
  const [loading, setLoading] = useState(true);

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

      setProfile(profileResult.data);
      setOrders(ordersResult.data ?? []);
      setLoading(false);
    }
    load();
  }, [locale, router]);

  if (loading) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  const activeOrders = orders.filter(
    (o) => !["fulfilled", "cancelled"].includes(o.status),
  );
  const completedOrders = orders.filter(
    (o) => ["fulfilled", "cancelled"].includes(o.status),
  );

  const totalSpent = orders
    .filter((o) => o.status === "fulfilled")
    .reduce((sum, o) => sum + Number(o.total_amount), 0);

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6">
        {/* Header */}
        <div className="mb-8 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
              <Building2 className="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-foreground">
                {profile?.business_name}
              </h1>
              <p className="text-sm text-gray-500">
                {t(`register.types.${profile?.business_type}`)}
                {profile?.verified_at && (
                  <span className="ml-2 inline-flex items-center gap-1 text-emerald-600">
                    <CheckCircle className="h-3.5 w-3.5" />
                    {t("dashboard.verified")}
                  </span>
                )}
              </p>
            </div>
          </div>
          <Button
            variant="primary"
            onClick={() => router.push(`/${locale}/business/orders?action=new`)}
          >
            <Plus className="mr-2 h-5 w-5" />
            {t("dashboard.newOrder")}
          </Button>
        </div>

        {/* Stats */}
        <div className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="rounded-lg bg-white p-6">
            <div className="flex items-center gap-3">
              <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
                <Package className="h-6 w-6 text-blue-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">{t("dashboard.activeOrders")}</p>
                <p className="text-2xl font-bold text-foreground">
                  {activeOrders.length}
                </p>
              </div>
            </div>
          </div>

          <div className="rounded-lg bg-white p-6">
            <div className="flex items-center gap-3">
              <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-emerald-100">
                <CheckCircle className="h-6 w-6 text-emerald-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">{t("dashboard.completedOrders")}</p>
                <p className="text-2xl font-bold text-foreground">
                  {completedOrders.length}
                </p>
              </div>
            </div>
          </div>

          <div className="rounded-lg bg-white p-6">
            <div className="flex items-center gap-3">
              <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-amber-100">
                <Clock className="h-6 w-6 text-amber-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">{t("dashboard.totalSpent")}</p>
                <p className="text-2xl font-bold text-foreground">
                  NPR {totalSpent.toLocaleString()}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Active Orders */}
        <section>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-foreground">
              {t("dashboard.recentOrders")}
            </h2>
            <button
              onClick={() => router.push(`/${locale}/business/orders`)}
              className="text-sm font-medium text-primary hover:underline"
            >
              {t("dashboard.viewAll")}
            </button>
          </div>

          {orders.length === 0 ? (
            <div className="rounded-lg bg-white p-12 text-center">
              <Package className="mx-auto h-12 w-12 text-gray-300" />
              <p className="mt-4 text-gray-500">{t("dashboard.noOrders")}</p>
              <Button
                variant="primary"
                className="mt-4"
                onClick={() => router.push(`/${locale}/business/orders?action=new`)}
              >
                <Plus className="mr-2 h-5 w-5" />
                {t("dashboard.placeFirst")}
              </Button>
            </div>
          ) : (
            <div className="space-y-3">
              {orders.slice(0, 5).map((order) => (
                <OrderRow
                  key={order.id}
                  order={order}
                  locale={locale}
                  t={t}
                  onClick={() => router.push(`/${locale}/business/orders/${order.id}`)}
                />
              ))}
            </div>
          )}
        </section>
      </div>
    </main>
  );
}

function OrderRow({
  order,
  locale,
  t,
  onClick,
}: {
  order: BulkOrderWithDetails;
  locale: Locale;
  t: ReturnType<typeof useTranslations>;
  onClick: () => void;
}) {
  const dateStr = new Date(order.created_at).toLocaleDateString(
    locale === "ne" ? "ne-NP" : "en-US",
    { month: "short", day: "numeric", year: "numeric" },
  );

  const farmerCount = new Set(order.items.map((i) => i.farmer_id)).size;
  const totalKg = order.items.reduce((sum, i) => sum + Number(i.quantity_kg), 0);

  return (
    <div
      onClick={onClick}
      className="flex items-center justify-between rounded-lg bg-white p-4 transition-all duration-200 cursor-pointer hover:scale-[1.01]"
    >
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <Badge color={STATUS_COLORS[order.status] ?? "primary"}>
            {t(`status.${order.status}`)}
          </Badge>
          <span className="text-xs text-gray-500">{dateStr}</span>
        </div>
        <p className="mt-1 text-sm text-gray-600">
          {t("dashboard.orderSummary", {
            items: order.items.length,
            farmers: farmerCount,
            kg: totalKg.toFixed(1),
          })}
        </p>
      </div>
      <div className="text-right">
        <p className="font-bold text-foreground">
          NPR {Number(order.total_amount).toLocaleString()}
        </p>
        <p className="text-xs text-gray-500">
          {t(`frequency.${order.delivery_frequency}`)}
        </p>
      </div>
    </div>
  );
}
