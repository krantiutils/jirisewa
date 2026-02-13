"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
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

// Fix Leaflet default marker icon path issue in bundlers
const defaultIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

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
  const [position, setPosition] = useState<LatLng | null>(value ?? null);
  const [address, setAddress] = useState("");
  const [isGeocoding, setIsGeocoding] = useState(false);

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
      setPosition(newPos);
      setIsGeocoding(true);

      const result = await reverseGeocode(latlng.lat, latlng.lng);
      const resolvedAddress = result?.displayName ?? "";
      setAddress(resolvedAddress);
      setIsGeocoding(false);
      onChange(newPos, resolvedAddress);
    },
    [onChange],
  );

  useEffect(() => {
    if (value) {
      setPosition(value);
    }
  }, [value]);

  return (
    <div className={className}>
      <MapContainer
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
            icon={defaultIcon}
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
