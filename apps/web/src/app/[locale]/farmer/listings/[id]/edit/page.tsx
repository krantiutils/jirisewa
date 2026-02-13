import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";
import { getCategories, getFarmerListing } from "../../../actions";
import { ListingForm } from "../../../_components/ListingForm";

export default async function EditListingPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale, id } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("farmer");

  const [categoriesResult, listingResult] = await Promise.all([
    getCategories(),
    getFarmerListing(id),
  ]);

  if (!listingResult.success) {
    notFound();
  }

  if (!categoriesResult.success) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center p-8">
        <p className="text-red-600">{categoriesResult.error}</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
      <h1 className="mb-8 text-2xl font-bold text-foreground">
        {t("editListing.title")}
      </h1>
      <ListingForm
        categories={categoriesResult.data}
        listing={listingResult.data}
      />
    </div>
  );
}
