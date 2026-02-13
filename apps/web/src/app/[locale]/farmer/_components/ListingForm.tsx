"use client";

import { useState } from "react";
import { useRouter } from "@/i18n/navigation";
import { useLocale, useTranslations } from "next-intl";
import { Button, Input } from "@/components/ui";
import { PhotoUpload } from "./PhotoUpload";
import { createListing, updateListing } from "../actions";
import type { ListingFormData } from "../actions";
import type { Tables } from "@/lib/supabase/types";
import type { ListingWithCategory } from "../actions";
import type { Locale } from "@/lib/i18n";

type Category = Tables<"produce_categories">;

interface ListingFormProps {
  categories: Category[];
  listing?: ListingWithCategory | null;
}

export function ListingForm({ categories, listing }: ListingFormProps) {
  const router = useRouter();
  const locale = useLocale() as Locale;
  const t = useTranslations("farmer");

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [categoryId, setCategoryId] = useState(listing?.category_id ?? "");
  const [nameEn, setNameEn] = useState(listing?.name_en ?? "");
  const [nameNe, setNameNe] = useState(listing?.name_ne ?? "");
  const [description, setDescription] = useState(listing?.description ?? "");
  const [pricePerKg, setPricePerKg] = useState(
    listing?.price_per_kg?.toString() ?? "",
  );
  const [availableQtyKg, setAvailableQtyKg] = useState(
    listing?.available_qty_kg?.toString() ?? "",
  );
  const [freshnessDate, setFreshnessDate] = useState(
    listing?.freshness_date ?? "",
  );
  const [photos, setPhotos] = useState<string[]>(listing?.photos ?? []);

  // When category changes, auto-populate names from category if fields are empty
  function handleCategoryChange(id: string) {
    setCategoryId(id);
    const cat = categories.find((c) => c.id === id);
    if (cat) {
      if (!nameEn) setNameEn(cat.name_en);
      if (!nameNe) setNameNe(cat.name_ne);
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!categoryId) {
      setError(t("form.errors.categoryRequired"));
      return;
    }
    if (!nameEn || !nameNe) {
      setError(t("form.errors.nameRequired"));
      return;
    }
    const price = parseFloat(pricePerKg);
    if (isNaN(price) || price <= 0) {
      setError(t("form.errors.priceInvalid"));
      return;
    }
    const qty = parseFloat(availableQtyKg);
    if (isNaN(qty) || qty <= 0) {
      setError(t("form.errors.qtyInvalid"));
      return;
    }

    setSubmitting(true);

    const formData: ListingFormData = {
      category_id: categoryId,
      name_en: nameEn.trim(),
      name_ne: nameNe.trim(),
      description: description.trim(),
      price_per_kg: price,
      available_qty_kg: qty,
      freshness_date: freshnessDate,
      photos,
    };

    const result = listing
      ? await updateListing(listing.id, formData)
      : await createListing(formData);

    setSubmitting(false);

    if (!result.success) {
      setError(result.error);
      return;
    }

    router.push("/farmer/dashboard");
  }

  const categoryName = (cat: Category) =>
    locale === "ne" ? cat.name_ne : cat.name_en;

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Category */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.category")}
        </label>
        <select
          value={categoryId}
          onChange={(e) => handleCategoryChange(e.target.value)}
          className="w-full rounded-md border-2 border-transparent bg-gray-100 px-4 h-14 text-foreground transition-all duration-200 focus:border-primary focus:bg-white focus:outline-none"
          required
        >
          <option value="">{t("form.selectCategory")}</option>
          {categories.map((cat) => (
            <option key={cat.id} value={cat.id}>
              {cat.icon} {categoryName(cat)}
            </option>
          ))}
        </select>
      </div>

      {/* Name (English) */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.nameEn")}
        </label>
        <Input
          value={nameEn}
          onChange={(e) => setNameEn(e.target.value)}
          placeholder={t("form.nameEnPlaceholder")}
          required
        />
      </div>

      {/* Name (Nepali) */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.nameNe")}
        </label>
        <Input
          value={nameNe}
          onChange={(e) => setNameNe(e.target.value)}
          placeholder={t("form.nameNePlaceholder")}
          required
        />
      </div>

      {/* Description */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.description")}
        </label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder={t("form.descriptionPlaceholder")}
          rows={3}
          className="w-full rounded-md border-2 border-transparent bg-gray-100 px-4 py-3 text-foreground transition-all duration-200 focus:border-primary focus:bg-white focus:outline-none"
        />
      </div>

      {/* Price per kg */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.pricePerKg")}
        </label>
        <div className="relative">
          <span className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-500">
            NPR
          </span>
          <Input
            type="number"
            step="0.01"
            min="0"
            value={pricePerKg}
            onChange={(e) => setPricePerKg(e.target.value)}
            className="pl-14"
            placeholder="0.00"
            required
          />
        </div>
      </div>

      {/* Available quantity */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.availableQty")}
        </label>
        <div className="relative">
          <Input
            type="number"
            step="0.1"
            min="0"
            value={availableQtyKg}
            onChange={(e) => setAvailableQtyKg(e.target.value)}
            placeholder="0.0"
            required
          />
          <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500">
            kg
          </span>
        </div>
      </div>

      {/* Freshness date */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.freshnessDate")}
        </label>
        <Input
          type="date"
          value={freshnessDate}
          onChange={(e) => setFreshnessDate(e.target.value)}
        />
      </div>

      {/* Photos */}
      <div>
        <label className="mb-2 block text-sm font-medium text-foreground">
          {t("form.photos")}
        </label>
        <PhotoUpload photos={photos} onChange={setPhotos} />
      </div>

      {/* Error message */}
      {error && (
        <div className="rounded-md bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Submit */}
      <div className="flex gap-3">
        <Button type="submit" disabled={submitting} className="flex-1">
          {submitting
            ? t("form.saving")
            : listing
              ? t("form.update")
              : t("form.create")}
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={() => router.push("/farmer/dashboard")}
        >
          {t("form.cancel")}
        </Button>
      </div>
    </form>
  );
}
