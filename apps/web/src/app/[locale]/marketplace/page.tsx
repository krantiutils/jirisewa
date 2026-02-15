import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { use } from "react";
import { fetchProduceListings, fetchCategories } from "@/lib/queries/produce";
import { MarketplaceContent } from "@/components/marketplace";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "marketplace" });

  return {
    title: t("title"),
    description: t("subtitle"),
  };
}

export default function MarketplacePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  setRequestLocale(locale);

  return <MarketplaceLoader />;
}

async function MarketplaceLoader() {
  let listings = [];
  let total = 0;
  let categories = [];

  try {
    const [listingResult, categoryResult] = await Promise.all([
      fetchProduceListings({ sort_by: "price_asc" }),
      fetchCategories(),
    ]);
    listings = listingResult.listings;
    total = listingResult.total;
    categories = categoryResult;
  } catch (error) {
    console.error("MarketplaceLoader fallback due to fetch error:", error);
  }

  return (
    <main className="bg-muted min-h-screen">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <MarketplaceContent
          initialListings={listings}
          initialTotal={total}
          categories={categories}
        />
      </div>
    </main>
  );
}
