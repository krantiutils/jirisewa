import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { Badge } from "@/components/ui";
import { Plus, Package, ShoppingCart, Wallet } from "lucide-react";
import { getFarmerDashboardData } from "../actions";
import { ListingCard } from "../_components/ListingCard";

export default async function FarmerDashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("farmer");
  const result = await getFarmerDashboardData();

  if (!result.success) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center p-8">
        <h1 className="text-2xl font-bold text-foreground">
          {t("dashboard.title")}
        </h1>
        <p className="mt-2 text-gray-500">{t("dashboard.loginRequired")}</p>
      </div>
    );
  }

  const {
    listings,
    activeListings,
    pendingOrderCount,
    totalEarnings,
  } = result.data;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6">
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">
          {t("dashboard.title")}
        </h1>
        <Link
          href="/farmer/listings/new"
          className="inline-flex items-center gap-2 rounded-md bg-primary px-6 h-14 font-semibold text-white transition-all duration-200 hover:bg-blue-600 hover:scale-105"
        >
          <Plus className="h-5 w-5" />
          {t("dashboard.addListing")}
        </Link>
      </div>

      {/* Stats */}
      <div className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-lg bg-white p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
              <Package className="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">{t("dashboard.activeListings")}</p>
              <p className="text-2xl font-bold text-foreground">
                {activeListings.length}
              </p>
            </div>
          </div>
        </div>

        <div className="rounded-lg bg-white p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-amber-100">
              <ShoppingCart className="h-6 w-6 text-amber-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">{t("dashboard.pendingOrders")}</p>
              <p className="text-2xl font-bold text-foreground">
                {pendingOrderCount}
              </p>
            </div>
          </div>
        </div>

        <div className="rounded-lg bg-white p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-emerald-100">
              <Wallet className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">{t("dashboard.earnings")}</p>
              <p className="text-2xl font-bold text-foreground">
                NPR {totalEarnings.toLocaleString()}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Listings */}
      <div>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-foreground">
            {t("dashboard.myListings")}
          </h2>
          {listings.length > 0 && (
            <Badge color="primary">{listings.length}</Badge>
          )}
        </div>

        {listings.length === 0 ? (
          <div className="rounded-lg bg-white p-12 text-center">
            <Package className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-4 text-gray-500">{t("dashboard.noListings")}</p>
            <Link
              href="/farmer/listings/new"
              className="mt-4 inline-flex items-center gap-2 rounded-md bg-primary px-6 h-12 font-semibold text-white transition-all duration-200 hover:bg-blue-600 hover:scale-105"
            >
              <Plus className="h-5 w-5" />
              {t("dashboard.addFirstListing")}
            </Link>
          </div>
        ) : (
          <div className="space-y-3">
            {listings.map((listing) => (
              <ListingCard key={listing.id} listing={listing} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
