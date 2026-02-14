import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import {
  ArrowLeft,
  TrendingUp,
  TrendingDown,
  BarChart3,
  Star,
  CheckCircle,
  Scale,
} from "lucide-react";
import { getFarmerAnalytics } from "../analytics-actions";
import { RevenueChart } from "../_components/RevenueChart";
import { SalesByCategoryChart } from "../_components/SalesByCategoryChart";
import { PriceBenchmarkChart } from "../_components/PriceBenchmarkChart";
import { RatingDistributionChart } from "../_components/RatingDistributionChart";
import { FulfillmentGauge } from "../_components/FulfillmentGauge";
import { PeriodSelector } from "../_components/PeriodSelector";

export default async function FarmerAnalyticsPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ days?: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const resolvedSearchParams = await searchParams;
  const days = Math.min(
    Math.max(Number(resolvedSearchParams.days) || 30, 7),
    90,
  );

  const t = await getTranslations("farmer.analytics");
  const result = await getFarmerAnalytics(days);

  if (!result.success) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center p-8">
        <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
        <p className="mt-2 text-gray-500">{t("loginRequired")}</p>
      </div>
    );
  }

  const {
    salesByCategory,
    revenueTrend,
    topProducts,
    priceBenchmarks,
    fulfillment,
    ratingDistribution,
    ratingAvg,
    ratingCount,
  } = result.data;

  const totalRevenue = revenueTrend.reduce(
    (sum, d) => sum + Number(d.revenue),
    0,
  );
  const totalOrders = revenueTrend.reduce(
    (sum, d) => sum + Number(d.order_count),
    0,
  );

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6">
      {/* Header */}
      <div className="mb-6 flex items-center gap-3">
        <Link
          href="/farmer/dashboard"
          className="inline-flex h-10 w-10 items-center justify-center rounded-full hover:bg-gray-100 transition-colors"
        >
          <ArrowLeft className="h-5 w-5 text-gray-600" />
        </Link>
        <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
      </div>

      {/* Period Selector */}
      <div className="mb-6 flex justify-end">
        <PeriodSelector
          current={days}
          labels={{
            d7: t("period.7days"),
            d30: t("period.30days"),
            d90: t("period.90days"),
          }}
        />
      </div>

      {/* Summary Cards */}
      <div className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-lg bg-white p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-emerald-100">
              <TrendingUp className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">{t("totalRevenue")}</p>
              <p className="text-2xl font-bold text-foreground">
                NPR {totalRevenue.toLocaleString()}
              </p>
            </div>
          </div>
        </div>

        <div className="rounded-lg bg-white p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
              <BarChart3 className="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">{t("totalOrders")}</p>
              <p className="text-2xl font-bold text-foreground">
                {totalOrders}
              </p>
            </div>
          </div>
        </div>

        <div className="rounded-lg bg-white p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-amber-100">
              <Star className="h-6 w-6 text-amber-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">{t("avgRating")}</p>
              <p className="text-2xl font-bold text-foreground">
                {ratingAvg.toFixed(1)}{" "}
                <span className="text-sm font-normal text-gray-400">
                  ({ratingCount})
                </span>
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Revenue Trend Chart */}
      <section className="mb-8 rounded-lg bg-white p-6">
        <h2 className="mb-4 text-lg font-semibold text-foreground">
          {t("revenueTrend")}
        </h2>
        {revenueTrend.length > 0 ? (
          <RevenueChart
            data={revenueTrend}
            revenueLabel={t("revenue")}
            ordersLabel={t("orders")}
          />
        ) : (
          <p className="py-12 text-center text-gray-400">{t("noData")}</p>
        )}
      </section>

      {/* Two-column layout */}
      <div className="mb-8 grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Sales by Category */}
        <section className="rounded-lg bg-white p-6">
          <h2 className="mb-4 text-lg font-semibold text-foreground">
            {t("salesByCategory")}
          </h2>
          {salesByCategory.length > 0 ? (
            <SalesByCategoryChart
              data={salesByCategory}
              revenueLabel={t("revenue")}
            />
          ) : (
            <p className="py-12 text-center text-gray-400">{t("noData")}</p>
          )}
        </section>

        {/* Fulfillment Rate */}
        <section className="rounded-lg bg-white p-6">
          <div className="mb-4 flex items-center gap-2">
            <CheckCircle className="h-5 w-5 text-emerald-600" />
            <h2 className="text-lg font-semibold text-foreground">
              {t("fulfillmentRate")}
            </h2>
          </div>
          <FulfillmentGauge
            data={fulfillment}
            deliveredLabel={t("delivered")}
            cancelledLabel={t("cancelled")}
            totalLabel={t("total")}
            rateLabel={t("rate")}
          />
        </section>
      </div>

      {/* Top Products Table */}
      <section className="mb-8 rounded-lg bg-white p-6">
        <h2 className="mb-4 text-lg font-semibold text-foreground">
          {t("topProducts")}
        </h2>
        {topProducts.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 text-left text-gray-500">
                  <th className="pb-3 font-medium">{t("product")}</th>
                  <th className="pb-3 font-medium text-right">{t("qtySold")}</th>
                  <th className="pb-3 font-medium text-right">{t("revenue")}</th>
                  <th className="pb-3 font-medium text-right">{t("orders")}</th>
                </tr>
              </thead>
              <tbody>
                {topProducts.map((product, idx) => (
                  <tr
                    key={product.listing_id}
                    className="border-b border-gray-50"
                  >
                    <td className="py-3">
                      <div className="flex items-center gap-2">
                        <span className="text-gray-400 text-xs">{idx + 1}</span>
                        <div>
                          <p className="font-medium text-foreground">
                            {product.name_en}
                          </p>
                          <p className="text-xs text-gray-400">
                            {product.category_name_en}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="py-3 text-right text-foreground">
                      {Number(product.total_qty_kg).toFixed(1)} kg
                    </td>
                    <td className="py-3 text-right font-medium text-emerald-600">
                      NPR {Number(product.total_revenue).toLocaleString()}
                    </td>
                    <td className="py-3 text-right text-foreground">
                      {product.order_count}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="py-12 text-center text-gray-400">{t("noData")}</p>
        )}
      </section>

      {/* Two-column: Price Benchmarks + Rating Distribution */}
      <div className="mb-8 grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Price Benchmarks */}
        <section className="rounded-lg bg-white p-6">
          <div className="mb-4 flex items-center gap-2">
            <Scale className="h-5 w-5 text-blue-600" />
            <h2 className="text-lg font-semibold text-foreground">
              {t("priceBenchmarks")}
            </h2>
          </div>
          {priceBenchmarks.length > 0 ? (
            <>
              <PriceBenchmarkChart
                data={priceBenchmarks}
                myPriceLabel={t("myPrice")}
                marketPriceLabel={t("marketPrice")}
              />
              {/* Price insights */}
              <div className="mt-4 space-y-2">
                {priceBenchmarks.map((b) => {
                  const myPrice = Number(b.my_avg_price);
                  const marketPrice = Number(b.market_avg_price);
                  if (marketPrice === 0) return null;
                  const diff = ((myPrice - marketPrice) / marketPrice) * 100;
                  const absDiff = Math.abs(diff);

                  if (absDiff < 5) return null;

                  return (
                    <div
                      key={b.category_id}
                      className="flex items-start gap-2 rounded-md bg-gray-50 p-3 text-sm"
                    >
                      {diff > 0 ? (
                        <TrendingUp className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />
                      ) : (
                        <TrendingDown className="mt-0.5 h-4 w-4 shrink-0 text-emerald-500" />
                      )}
                      <span className="text-gray-600">
                        {t("priceInsight", {
                          category: b.category_name_en,
                          percent: absDiff.toFixed(0),
                          direction: diff > 0 ? t("above") : t("below"),
                        })}
                      </span>
                    </div>
                  );
                })}
              </div>
            </>
          ) : (
            <p className="py-12 text-center text-gray-400">{t("noData")}</p>
          )}
        </section>

        {/* Rating Distribution */}
        <section className="rounded-lg bg-white p-6">
          <div className="mb-4 flex items-center gap-2">
            <Star className="h-5 w-5 text-amber-500" />
            <h2 className="text-lg font-semibold text-foreground">
              {t("ratingBreakdown")}
            </h2>
          </div>
          <RatingDistributionChart
            data={ratingDistribution}
            avgRating={ratingAvg}
            totalRatings={ratingCount}
            avgLabel={t("avgLabel")}
            totalLabel={t("reviews")}
          />
        </section>
      </div>
    </div>
  );
}
