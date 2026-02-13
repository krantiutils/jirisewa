"use client";

import { useState, useCallback, useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import { SlidersHorizontal, SearchX, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui";
import { ProduceCard } from "./ProduceCard";
import { FilterSidebar, type FilterState } from "./FilterSidebar";
import type { ProduceCategory, ProduceListingWithDetails } from "@/lib/supabase/types";

interface MarketplaceContentProps {
  initialListings: ProduceListingWithDetails[];
  initialTotal: number;
  categories: ProduceCategory[];
  initialCategoryId?: string;
}

const INITIAL_FILTERS: FilterState = {
  category_id: "",
  min_price: "",
  max_price: "",
  radius_km: "",
  sort_by: "price_asc",
  search: "",
};

const DEBOUNCE_MS = 300;

export function MarketplaceContent({
  initialListings,
  initialTotal,
  categories,
  initialCategoryId,
}: MarketplaceContentProps) {
  const t = useTranslations("marketplace");

  const [listings, setListings] = useState(initialListings);
  const [total, setTotal] = useState(initialTotal);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [mobileFilterOpen, setMobileFilterOpen] = useState(false);
  const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [filters, setFilters] = useState<FilterState>({
    ...INITIAL_FILTERS,
    category_id: initialCategoryId ?? "",
  });

  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const isInitialMount = useRef(true);

  const fetchListings = useCallback(
    async (currentFilters: FilterState, currentPage: number, append: boolean) => {
      // Abort any in-flight request
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      setLoading(true);
      setError(null);

      const params = new URLSearchParams();
      if (currentFilters.category_id) params.set("category_id", currentFilters.category_id);
      if (currentFilters.min_price) params.set("min_price", currentFilters.min_price);
      if (currentFilters.max_price) params.set("max_price", currentFilters.max_price);
      if (currentFilters.radius_km) params.set("radius_km", currentFilters.radius_km);
      if (currentFilters.sort_by) params.set("sort_by", currentFilters.sort_by);
      if (currentFilters.search) params.set("search", currentFilters.search);
      if (location) {
        params.set("lat", String(location.lat));
        params.set("lng", String(location.lng));
      }
      params.set("page", String(currentPage));

      try {
        const res = await fetch(`/api/produce?${params.toString()}`, {
          signal: controller.signal,
        });
        if (!res.ok) throw new Error("Failed to fetch");
        const data = await res.json();

        if (append) {
          setListings((prev) => [...prev, ...data.listings]);
        } else {
          setListings(data.listings);
        }
        setTotal(data.total);
      } catch (err) {
        if (err instanceof DOMException && err.name === "AbortError") return;
        setError("Failed to load produce. Please try again.");
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false);
        }
      }
    },
    [location],
  );

  // Re-fetch when filters or location change (debounced for search)
  useEffect(() => {
    if (isInitialMount.current) {
      isInitialMount.current = false;
      return;
    }

    if (debounceRef.current) clearTimeout(debounceRef.current);

    debounceRef.current = setTimeout(() => {
      setPage(1);
      fetchListings(filters, 1, false);
    }, DEBOUNCE_MS);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      abortRef.current?.abort();
    };
  }, [filters, location, fetchListings]);

  const handleFilterChange = useCallback((key: keyof FilterState, value: string) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
  }, []);

  const handleClearFilters = useCallback(() => {
    setFilters(INITIAL_FILTERS);
  }, []);

  const handleLocationChange = useCallback((lat: number, lng: number) => {
    setLocation({ lat, lng });
  }, []);

  const handleLoadMore = useCallback(() => {
    const nextPage = page + 1;
    setPage(nextPage);
    fetchListings(filters, nextPage, true);
  }, [page, filters, fetchListings]);

  const hasMore = listings.length < total;

  return (
    <div className="flex gap-8">
      <FilterSidebar
        categories={categories}
        filters={filters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
        location={location}
        onLocationChange={handleLocationChange}
        mobileOpen={mobileFilterOpen}
        onMobileClose={() => setMobileFilterOpen(false)}
      />

      <div className="min-w-0 flex-1">
        {/* Mobile filter toggle + result count */}
        <div className="mb-4 flex items-center justify-between">
          <p className="text-sm text-gray-500">
            {t("showing", { count: total })}
          </p>
          <Button
            variant="secondary"
            onClick={() => setMobileFilterOpen(true)}
            className="h-10 px-3 lg:hidden"
          >
            <SlidersHorizontal className="mr-2 h-4 w-4" />
            {t("filters")}
          </Button>
        </div>

        {/* Error banner */}
        {error && (
          <div className="mb-4 flex items-center gap-2 rounded-md bg-red-50 px-4 py-3 text-sm text-red-700">
            <AlertCircle className="h-4 w-4 shrink-0" />
            {error}
          </div>
        )}

        {/* Produce grid */}
        {listings.length > 0 ? (
          <>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {listings.map((listing) => (
                <ProduceCard key={listing.id} listing={listing} />
              ))}
            </div>

            {/* Load more */}
            {hasMore && (
              <div className="mt-8 flex justify-center">
                <Button
                  variant="outline"
                  onClick={handleLoadMore}
                  disabled={loading}
                  className="h-12 px-8"
                >
                  {loading ? "..." : t("loadMore")}
                </Button>
              </div>
            )}
          </>
        ) : !loading ? (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <SearchX className="mb-4 h-16 w-16 text-gray-300" />
            <h3 className="text-xl font-bold text-foreground">{t("noResults")}</h3>
            <p className="mt-2 text-sm text-gray-500">{t("noResultsHint")}</p>
          </div>
        ) : null}
      </div>
    </div>
  );
}
