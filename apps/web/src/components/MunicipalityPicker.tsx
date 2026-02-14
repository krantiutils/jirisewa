"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { MapPin, Search, Loader2, X } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { Input } from "@/components/ui";
import { searchMunicipalitiesAction } from "@/lib/actions/municipalities";
import type { MunicipalitySearchResult } from "@/lib/supabase/types";
import type { Locale } from "@/lib/i18n";

const NEPAL_PROVINCES: Record<number, { en: string; ne: string }> = {
  1: { en: "Koshi", ne: "कोशी" },
  2: { en: "Madhesh", ne: "मधेश" },
  3: { en: "Bagmati", ne: "बागमती" },
  4: { en: "Gandaki", ne: "गण्डकी" },
  5: { en: "Lumbini", ne: "लुम्बिनी" },
  6: { en: "Karnali", ne: "कर्णाली" },
  7: { en: "Sudurpashchim", ne: "सुदूरपश्चिम" },
};

interface MunicipalityPickerProps {
  value?: MunicipalitySearchResult | null;
  onChange: (municipality: MunicipalitySearchResult | null) => void;
  placeholder?: string;
  className?: string;
  label?: string;
}

export function MunicipalityPicker({
  value,
  onChange,
  placeholder,
  className,
  label,
}: MunicipalityPickerProps) {
  const locale = useLocale() as Locale;
  const t = useTranslations("municipality");
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<MunicipalitySearchResult[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [provinceFilter, setProvinceFilter] = useState<number | undefined>();
  const containerRef = useRef<HTMLDivElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  const displayName = useCallback(
    (m: MunicipalitySearchResult) =>
      locale === "ne" ? m.name_ne : m.name_en,
    [locale],
  );

  const displayDistrict = useCallback(
    (m: MunicipalitySearchResult) => {
      const prov = NEPAL_PROVINCES[m.province];
      const provName = prov ? (locale === "ne" ? prov.ne : prov.en) : `Province ${m.province}`;
      return `${m.district}, ${provName}`;
    },
    [locale],
  );

  const performSearch = useCallback(
    async (searchQuery: string, province?: number) => {
      setIsLoading(true);
      const result = await searchMunicipalitiesAction(searchQuery, province);
      if (result.data) {
        setResults(result.data);
      }
      setIsLoading(false);
    },
    [],
  );

  useEffect(() => {
    if (!isOpen) return;

    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    debounceRef.current = setTimeout(() => {
      performSearch(query, provinceFilter);
    }, 200);

    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, [query, provinceFilter, isOpen, performSearch]);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (
        containerRef.current &&
        !containerRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleSelect = useCallback(
    (municipality: MunicipalitySearchResult) => {
      onChange(municipality);
      setQuery("");
      setIsOpen(false);
    },
    [onChange],
  );

  const handleClear = useCallback(() => {
    onChange(null);
    setQuery("");
  }, [onChange]);

  if (value) {
    return (
      <div className={className}>
        {label && (
          <label className="mb-2 block text-sm font-semibold uppercase tracking-wider text-gray-500">
            {label}
          </label>
        )}
        <div className="flex items-center gap-2 rounded-md bg-emerald-50 px-3 py-2.5">
          <MapPin className="h-4 w-4 shrink-0 text-emerald-600" />
          <div className="min-w-0 flex-1">
            <div className="font-medium text-emerald-700 truncate">
              {displayName(value)}
            </div>
            <div className="text-xs text-emerald-600 truncate">
              {displayDistrict(value)}
            </div>
          </div>
          <button
            onClick={handleClear}
            className="shrink-0 rounded p-1 text-emerald-600 hover:bg-emerald-100"
            aria-label={t("clear")}
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div ref={containerRef} className={`relative ${className ?? ""}`}>
      {label && (
        <label className="mb-2 block text-sm font-semibold uppercase tracking-wider text-gray-500">
          {label}
        </label>
      )}
      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
        <Input
          type="text"
          placeholder={placeholder ?? t("searchPlaceholder")}
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setIsOpen(true);
          }}
          onFocus={() => {
            setIsOpen(true);
            if (results.length === 0) {
              performSearch(query, provinceFilter);
            }
          }}
          className="h-12 pl-10"
        />
        {isLoading && (
          <Loader2 className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-gray-400" />
        )}
      </div>

      {isOpen && (
        <div className="absolute z-50 mt-1 max-h-72 w-full overflow-y-auto rounded-lg border border-gray-200 bg-white shadow-lg">
          {/* Province filter chips */}
          <div className="flex flex-wrap gap-1 border-b border-gray-100 p-2">
            <button
              onClick={() => setProvinceFilter(undefined)}
              className={`rounded-full px-2.5 py-1 text-xs font-medium transition-colors ${
                provinceFilter === undefined
                  ? "bg-emerald-100 text-emerald-700"
                  : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              {t("allProvinces")}
            </button>
            {Object.entries(NEPAL_PROVINCES).map(([num, names]) => (
              <button
                key={num}
                onClick={() =>
                  setProvinceFilter(
                    provinceFilter === Number(num) ? undefined : Number(num),
                  )
                }
                className={`rounded-full px-2.5 py-1 text-xs font-medium transition-colors ${
                  provinceFilter === Number(num)
                    ? "bg-emerald-100 text-emerald-700"
                    : "bg-gray-100 text-gray-600 hover:bg-gray-200"
                }`}
              >
                {locale === "ne" ? names.ne : names.en}
              </button>
            ))}
          </div>

          {results.length === 0 && !isLoading && (
            <div className="px-4 py-6 text-center text-sm text-gray-500">
              {query ? t("noResults") : t("typeToSearch")}
            </div>
          )}

          {results.map((m) => (
            <button
              key={m.id}
              onClick={() => handleSelect(m)}
              className="flex w-full items-start gap-3 px-4 py-2.5 text-left hover:bg-gray-50 transition-colors"
            >
              <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-gray-400" />
              <div className="min-w-0">
                <div className="font-medium text-gray-900 truncate">
                  {displayName(m)}
                </div>
                <div className="text-xs text-gray-500 truncate">
                  {displayDistrict(m)}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
