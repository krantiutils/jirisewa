"use client";

import { useLocale, useTranslations } from "next-intl";
import { SlidersHorizontal, X } from "lucide-react";
import { Button, Input } from "@/components/ui";
import { LocationPicker } from "./LocationPicker";
import type { ProduceCategory } from "@/lib/supabase/types";
import type { Locale } from "@/lib/i18n";

export interface FilterState {
  category_id: string;
  min_price: string;
  max_price: string;
  radius_km: string;
  sort_by: string;
  search: string;
}

interface FilterSidebarProps {
  categories: ProduceCategory[];
  filters: FilterState;
  onFilterChange: (key: keyof FilterState, value: string) => void;
  onClearFilters: () => void;
  location: { lat: number; lng: number } | null;
  onLocationChange: (lat: number, lng: number) => void;
  mobileOpen: boolean;
  onMobileClose: () => void;
}

const DISTANCE_OPTIONS = ["5", "10", "25", "50", "100"] as const;

export function FilterSidebar({
  categories,
  filters,
  onFilterChange,
  onClearFilters,
  location,
  onLocationChange,
  mobileOpen,
  onMobileClose,
}: FilterSidebarProps) {
  const locale = useLocale() as Locale;
  const t = useTranslations("marketplace");

  const hasActiveFilters =
    filters.category_id ||
    filters.min_price ||
    filters.max_price ||
    filters.radius_km ||
    filters.search;

  const content = (
    <div className="space-y-6">
      {/* Header (mobile) */}
      <div className="flex items-center justify-between lg:hidden">
        <h2 className="flex items-center gap-2 text-lg font-bold">
          <SlidersHorizontal className="h-5 w-5" />
          {t("filters")}
        </h2>
        <button onClick={onMobileClose} className="p-2">
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Search */}
      <div>
        <Input
          type="search"
          placeholder={t("searchPlaceholder")}
          value={filters.search}
          onChange={(e) => onFilterChange("search", e.target.value)}
          className="h-12"
        />
      </div>

      {/* Location */}
      <div>
        <LocationPicker
          onLocationChange={onLocationChange}
          currentLocation={location}
        />
      </div>

      {/* Category */}
      <div>
        <label className="mb-2 block text-sm font-semibold uppercase tracking-wider text-gray-500">
          {t("category")}
        </label>
        <select
          value={filters.category_id}
          onChange={(e) => onFilterChange("category_id", e.target.value)}
          className="w-full rounded-md border-2 border-transparent bg-gray-100 px-4 py-3 text-sm transition-all focus:border-primary focus:bg-white focus:outline-none"
        >
          <option value="">{t("allCategories")}</option>
          {categories.map((cat) => (
            <option key={cat.id} value={cat.id}>
              {locale === "ne" ? cat.name_ne : cat.name_en}
            </option>
          ))}
        </select>
      </div>

      {/* Price Range */}
      <div>
        <label className="mb-2 block text-sm font-semibold uppercase tracking-wider text-gray-500">
          {t("priceRange")}
        </label>
        <div className="flex gap-2">
          <Input
            type="number"
            placeholder={t("minPrice")}
            value={filters.min_price}
            onChange={(e) => onFilterChange("min_price", e.target.value)}
            className="h-12"
            min={0}
          />
          <Input
            type="number"
            placeholder={t("maxPrice")}
            value={filters.max_price}
            onChange={(e) => onFilterChange("max_price", e.target.value)}
            className="h-12"
            min={0}
          />
        </div>
      </div>

      {/* Distance */}
      {location && (
        <div>
          <label className="mb-2 block text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("distance")}
          </label>
          <select
            value={filters.radius_km}
            onChange={(e) => onFilterChange("radius_km", e.target.value)}
            className="w-full rounded-md border-2 border-transparent bg-gray-100 px-4 py-3 text-sm transition-all focus:border-primary focus:bg-white focus:outline-none"
          >
            <option value="">{t("distanceAny")}</option>
            {DISTANCE_OPTIONS.map((km) => (
              <option key={km} value={km}>
                {t(`distanceOptions.${km}`)}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Sort */}
      <div>
        <label className="mb-2 block text-sm font-semibold uppercase tracking-wider text-gray-500">
          {t("sortBy")}
        </label>
        <select
          value={filters.sort_by}
          onChange={(e) => onFilterChange("sort_by", e.target.value)}
          className="w-full rounded-md border-2 border-transparent bg-gray-100 px-4 py-3 text-sm transition-all focus:border-primary focus:bg-white focus:outline-none"
        >
          <option value="price_asc">{t("sortOptions.price_asc")}</option>
          <option value="price_desc">{t("sortOptions.price_desc")}</option>
          <option value="freshness">{t("sortOptions.freshness")}</option>
          <option value="rating">{t("sortOptions.rating")}</option>
          {location && (
            <option value="distance">{t("sortOptions.distance")}</option>
          )}
        </select>
      </div>

      {/* Clear Filters */}
      {hasActiveFilters && (
        <Button variant="secondary" onClick={onClearFilters} className="w-full h-12">
          {t("clearFilters")}
        </Button>
      )}
    </div>
  );

  return (
    <>
      {/* Desktop sidebar */}
      <aside className="hidden lg:block lg:w-72 lg:shrink-0">
        <div className="sticky top-4">{content}</div>
      </aside>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="absolute inset-0 bg-black/30" onClick={onMobileClose} />
          <div className="absolute bottom-0 left-0 right-0 max-h-[85vh] overflow-y-auto rounded-t-2xl bg-white p-6">
            {content}
          </div>
        </div>
      )}
    </>
  );
}
