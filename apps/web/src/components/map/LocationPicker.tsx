"use client";

import { useCallback, useMemo, useState, useRef, useEffect } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  useMapEvents,
  useMap,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import {
  MAP_TILE_URL,
  MAP_ATTRIBUTION,
  MAP_DEFAULT_CENTER,
  MAP_DEFAULT_ZOOM,
  NEPAL_BOUNDS,
} from "@jirisewa/shared";
import { reverseGeocode, forwardGeocode } from "@/lib/map";
import type { LatLng, GeocodingResult } from "@/lib/map";
import { defaultMarkerIcon } from "@/lib/leaflet-icons";
import { Search } from "lucide-react";

interface LocationPickerProps {
  value?: LatLng | null;
  onChange: (location: LatLng, address: string) => void;
  className?: string;
}

function ClickHandler({
  onLocationSelect,
}: {
  onLocationSelect: (latlng: L.LatLng) => void;
}) {
  useMapEvents({
    click(e) {
      onLocationSelect(e.latlng);
    },
  });
  return null;
}

function MapPanner({ target }: { target: LatLng | null }) {
  const map = useMap();
  useEffect(() => {
    if (target) {
      map.setView([target.lat, target.lng], 14);
    }
  }, [map, target]);
  return null;
}

export default function LocationPicker({
  value,
  onChange,
  className,
}: LocationPickerProps) {
  const [selectedPosition, setSelectedPosition] = useState<LatLng | null>(null);
  const [address, setAddress] = useState("");
  const [isGeocoding, setIsGeocoding] = useState(false);

  // Search state
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<GeocodingResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [showResults, setShowResults] = useState(false);
  const [panTarget, setPanTarget] = useState<LatLng | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(null);
  const searchRef = useRef<HTMLDivElement>(null);

  // Show either user-selected position or the controlled value
  const position = selectedPosition ?? value ?? null;

  const center = useMemo(
    () => value ?? MAP_DEFAULT_CENTER,
    [value],
  );

  const bounds = useMemo(
    () =>
      L.latLngBounds(
        [NEPAL_BOUNDS.southWest.lat, NEPAL_BOUNDS.southWest.lng],
        [NEPAL_BOUNDS.northEast.lat, NEPAL_BOUNDS.northEast.lng],
      ),
    [],
  );

  const handleLocationSelect = useCallback(
    async (latlng: L.LatLng) => {
      const newPos = { lat: latlng.lat, lng: latlng.lng };
      setSelectedPosition(newPos);
      setIsGeocoding(true);

      const result = await reverseGeocode(latlng.lat, latlng.lng);
      const resolvedAddress = result?.displayName ?? "";
      setAddress(resolvedAddress);
      setIsGeocoding(false);
      onChange(newPos, resolvedAddress);
    },
    [onChange],
  );

  // Debounced search
  const handleSearchChange = useCallback((value: string) => {
    setQuery(value);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!value.trim()) {
      setResults([]);
      setShowResults(false);
      return;
    }
    debounceRef.current = setTimeout(async () => {
      setSearching(true);
      const res = await forwardGeocode(value);
      setResults(res);
      setShowResults(res.length > 0);
      setSearching(false);
    }, 400);
  }, []);

  const handleSelectResult = useCallback(
    (result: GeocodingResult) => {
      const pos = { lat: result.lat, lng: result.lng };
      setSelectedPosition(pos);
      setAddress(result.displayName);
      setPanTarget(pos);
      setQuery(result.displayName.split(",")[0]);
      setShowResults(false);
      onChange(pos, result.displayName);
    },
    [onChange],
  );

  // Close dropdown on click outside
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setShowResults(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  return (
    <div data-testid="location-picker-map" className={className}>
      {/* Search input */}
      <div className="relative mb-2" ref={searchRef}>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={query}
            onChange={(e) => handleSearchChange(e.target.value)}
            onFocus={() => results.length > 0 && setShowResults(true)}
            placeholder="Search location..."
            className="w-full rounded-lg border-2 border-gray-200 py-2.5 pl-10 pr-4 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
          />
          {searching && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          )}
        </div>

        {showResults && results.length > 0 && (
          <ul className="absolute z-[1000] mt-1 max-h-48 w-full overflow-y-auto rounded-lg border border-gray-200 bg-white shadow-lg">
            {results.map((r, i) => (
              <li key={i}>
                <button
                  type="button"
                  onClick={() => handleSelectResult(r)}
                  className="w-full px-4 py-2.5 text-left text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  {r.displayName}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      <MapContainer
        data-testid="location-picker-map-canvas"
        center={[center.lat, center.lng]}
        zoom={MAP_DEFAULT_ZOOM}
        maxBounds={bounds}
        maxBoundsViscosity={1.0}
        minZoom={7}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} />
        <ClickHandler onLocationSelect={handleLocationSelect} />
        <MapPanner target={panTarget} />
        {position && (
          <Marker
            position={[position.lat, position.lng]}
            icon={defaultMarkerIcon}
          />
        )}
      </MapContainer>
      {address && (
        <div className="mt-2 text-sm text-gray-600 truncate">
          {isGeocoding ? "Resolving address..." : address}
        </div>
      )}
    </div>
  );
}
