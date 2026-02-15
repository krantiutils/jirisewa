"use client";

import { useCallback, useMemo, useState } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  useMapEvents,
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
import { reverseGeocode } from "@/lib/map";
import type { LatLng } from "@/lib/map";
import { defaultMarkerIcon } from "@/lib/leaflet-icons";

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

export default function LocationPicker({
  value,
  onChange,
  className,
}: LocationPickerProps) {
  const [selectedPosition, setSelectedPosition] = useState<LatLng | null>(null);
  const [address, setAddress] = useState("");
  const [isGeocoding, setIsGeocoding] = useState(false);

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

  return (
    <div data-testid="location-picker-map" className={className}>
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
