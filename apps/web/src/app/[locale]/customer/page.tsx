import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { use } from "react";
import { fetchProduceListings } from "@/lib/queries/produce";
import { MarketplaceContent } from "@/components/marketplace";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function CustomerPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  // Check if user is authenticated
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    redirect(`/${locale}/auth/login`);
  }

  // Fetch products
  let listings: any[] = [];
  let total = 0;
  try {
    const result = await fetchProduceListings({
      sort_by: "freshness",
    });
    listings = result.listings;
    total = result.total;
  } catch (error) {
    console.error("CustomerPage error:", error);
  }

  return (
    <main className="bg-muted min-h-screen">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-foreground">
            Shop Fresh Produce
          </h1>
          <p className="mt-1 text-sm text-gray-600">
            Products from local farmers
          </p>
        </div>
        <MarketplaceContent
          initialListings={listings}
          initialTotal={total}
          categories={[]}
        />
      </div>
    </main>
  );
}
