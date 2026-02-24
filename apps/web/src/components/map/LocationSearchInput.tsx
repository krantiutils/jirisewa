"use client";

import { useCallback, useRef, useState, useEffect } from "react";
import { forwardGeocode } from "@/lib/map";
import type { GeocodingResult } from "@/lib/map";
import { MapPin } from "lucide-react";

interface LocationSearchInputProps {
  value?: string;
  placeholder?: string;
  onChange: (location: { lat: number; lng: number; name: string }) => void;
}

export function LocationSearchInput({
  value,
  placeholder = "Search location...",
  onChange,
}: LocationSearchInputProps) {
  const [query, setQuery] = useState(value ?? "");
  const [results, setResults] = useState<GeocodingResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [showResults, setShowResults] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Sync external value changes
  useEffect(() => {
    if (value !== undefined) setQuery(value);
  }, [value]);

  const handleChange = useCallback((val: string) => {
    setQuery(val);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!val.trim()) {
      setResults([]);
      setShowResults(false);
      return;
    }
    debounceRef.current = setTimeout(async () => {
      setSearching(true);
      const res = await forwardGeocode(val);
      setResults(res);
      setShowResults(res.length > 0);
      setSearching(false);
    }, 400);
  }, []);

  const handleSelect = useCallback(
    (result: GeocodingResult) => {
      const shortName = result.displayName.split(",").slice(0, 2).join(",").trim();
      setQuery(shortName);
      setShowResults(false);
      onChange({ lat: result.lat, lng: result.lng, name: shortName });
    },
    [onChange],
  );

  // Close dropdown on click outside
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setShowResults(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  return (
    <div className="relative" ref={containerRef}>
      <div className="relative">
        <MapPin className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          value={query}
          onChange={(e) => handleChange(e.target.value)}
          onFocus={() => results.length > 0 && setShowResults(true)}
          placeholder={placeholder}
          className="w-full rounded-lg border-2 border-gray-200 py-2.5 pl-10 pr-4 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
        />
        {searching && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2">
            <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        )}
      </div>

      {showResults && results.length > 0 && (
        <ul className="absolute z-50 mt-1 max-h-48 w-full overflow-y-auto rounded-lg border border-gray-200 bg-white shadow-lg">
          {results.map((r, i) => (
            <li key={i}>
              <button
                type="button"
                onClick={() => handleSelect(r)}
                className="w-full px-4 py-2.5 text-left text-sm text-gray-700 hover:bg-gray-50 transition-colors"
              >
                {r.displayName}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
