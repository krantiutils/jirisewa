import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { getPlatformStats } from "@/lib/admin/queries";
import {
  Users,
  ShoppingCart,
  Wallet,
  Package,
  AlertTriangle,
  UserCheck,
  Sprout,
  Truck,
} from "lucide-react";
import Link from "next/link";

export default async function AdminDashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("admin");
  const stats = await getPlatformStats(locale);

  const statCards = [
    {
      label: t("stats.totalUsers"),
      value: stats.totalUsers,
      icon: Users,
      iconBg: "bg-blue-100",
      iconColor: "text-blue-600",
    },
    {
      label: t("stats.totalOrders"),
      value: stats.totalOrders,
      icon: ShoppingCart,
      iconBg: "bg-emerald-100",
      iconColor: "text-emerald-600",
    },
    {
      label: t("stats.revenue"),
      value: `NPR ${stats.totalRevenue.toLocaleString()}`,
      icon: Wallet,
      iconBg: "bg-amber-100",
      iconColor: "text-amber-600",
    },
    {
      label: t("stats.activeListings"),
      value: stats.activeListings,
      icon: Package,
      iconBg: "bg-purple-100",
      iconColor: "text-purple-600",
    },
  ];

  const roleCards = [
    {
      label: t("stats.farmers"),
      value: stats.totalFarmers,
      icon: Sprout,
      iconBg: "bg-green-100",
      iconColor: "text-green-600",
    },
    {
      label: t("stats.consumers"),
      value: stats.totalConsumers,
      icon: Users,
      iconBg: "bg-blue-100",
      iconColor: "text-blue-600",
    },
    {
      label: t("stats.riders"),
      value: stats.totalRiders,
      icon: Truck,
      iconBg: "bg-orange-100",
      iconColor: "text-orange-600",
    },
  ];

  return (
    <div className="mx-auto max-w-5xl">
      <h1 className="mb-6 text-2xl font-bold text-foreground">
        {t("dashboard.title")}
      </h1>

      {/* Primary stats */}
      <div className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {statCards.map((card) => (
          <div key={card.label} className="rounded-lg bg-white p-5">
            <div className="flex items-center gap-3">
              <div
                className={`inline-flex h-11 w-11 items-center justify-center rounded-full ${card.iconBg}`}
              >
                <card.icon className={`h-5 w-5 ${card.iconColor}`} />
              </div>
              <div>
                <p className="text-xs text-gray-500">{card.label}</p>
                <p className="text-xl font-bold text-foreground">
                  {card.value}
                </p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Role breakdown */}
      <div className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
        {roleCards.map((card) => (
          <div key={card.label} className="rounded-lg bg-white p-5">
            <div className="flex items-center gap-3">
              <div
                className={`inline-flex h-11 w-11 items-center justify-center rounded-full ${card.iconBg}`}
              >
                <card.icon className={`h-5 w-5 ${card.iconColor}`} />
              </div>
              <div>
                <p className="text-xs text-gray-500">{card.label}</p>
                <p className="text-xl font-bold text-foreground">
                  {card.value}
                </p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Quick action links */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {stats.pendingDisputes > 0 && (
          <Link
            href={`/${locale}/admin/disputes`}
            className="flex items-center gap-4 rounded-lg bg-red-50 p-5 transition-all duration-200 hover:scale-[1.02]"
          >
            <div className="inline-flex h-11 w-11 items-center justify-center rounded-full bg-red-100">
              <AlertTriangle className="h-5 w-5 text-red-600" />
            </div>
            <div>
              <p className="font-semibold text-red-700">
                {stats.pendingDisputes} {t("dashboard.pendingDisputes")}
              </p>
              <p className="text-sm text-red-500">
                {t("dashboard.disputesAction")}
              </p>
            </div>
          </Link>
        )}
        {stats.unverifiedFarmers > 0 && (
          <Link
            href={`/${locale}/admin/farmers`}
            className="flex items-center gap-4 rounded-lg bg-amber-50 p-5 transition-all duration-200 hover:scale-[1.02]"
          >
            <div className="inline-flex h-11 w-11 items-center justify-center rounded-full bg-amber-100">
              <UserCheck className="h-5 w-5 text-amber-600" />
            </div>
            <div>
              <p className="font-semibold text-amber-700">
                {stats.unverifiedFarmers} {t("dashboard.unverifiedFarmers")}
              </p>
              <p className="text-sm text-amber-500">
                {t("dashboard.verifyAction")}
              </p>
            </div>
          </Link>
        )}
      </div>
    </div>
  );
}
