import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";
import { use } from "react";
import {
  fetchProduceListings,
  fetchCategories,
} from "@/lib/queries/produce";
import { MarketplaceContent } from "@/components/marketplace";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string; category: string }>;
}) {
  const { locale, category } = await params;
  const t = await getTranslations({ locale, namespace: "marketplace" });
  const categories = await fetchCategories();
  const cat = categories.find((c) => c.id === category);

  if (!cat) return { title: t("title") };

  const categoryName = locale === "ne" ? cat.name_ne : cat.name_en;
  return {
    title: `${categoryName} — ${t("title")}`,
    description: t("subtitle"),
  };
}

export default function CategoryPage({
  params,
}: {
  params: Promise<{ locale: string; category: string }>;
}) {
  const { locale, category } = use(params);
  setRequestLocale(locale);

  return <CategoryLoader categoryId={category} />;
}

async function CategoryLoader({ categoryId }: { categoryId: string }) {
  const [{ listings, total }, categories] = await Promise.all([
    fetchProduceListings({ category_id: categoryId, sort_by: "price_asc" }),
    fetchCategories(),
  ]);

  // If category doesn't exist, 404
  const categoryExists = categories.some((c) => c.id === categoryId);
  if (!categoryExists) {
    notFound();
  }

  return (
    <main className="bg-muted min-h-screen">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <MarketplaceContent
          initialListings={listings}
          initialTotal={total}
          categories={categories}
          initialCategoryId={categoryId}
        />
      </div>
    </main>
  );
}
