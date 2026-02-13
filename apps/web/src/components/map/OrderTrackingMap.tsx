"use client";

import { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Popup, Polyline } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import {
  MAP_TILE_URL,
  MAP_ATTRIBUTION,
  MAP_DEFAULT_CENTER,
  MAP_DEFAULT_ZOOM,
  NEPAL_BOUNDS,
} from "@jirisewa/shared";
import type { LatLng } from "@/lib/map";

const markerIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

interface OrderTrackingMapProps {
  pickupLocation: LatLng;
  deliveryLocation: LatLng;
  pickupLabel?: string;
  deliveryLabel?: string;
  /** Route coordinates as [lat, lng] pairs, if available */
  routeCoordinates?: [number, number][];
  className?: string;
}

/**
 * Order tracking map — Phase 1 placeholder.
 * Shows pickup and delivery markers with optional route polyline.
 * Real-time rider tracking will be added in Phase 2 via Supabase Realtime.
 */
export default function OrderTrackingMap({
  pickupLocation,
  deliveryLocation,
  pickupLabel,
  deliveryLabel,
  routeCoordinates,
  className,
}: OrderTrackingMapProps) {
  const bounds = useMemo(
    () =>
      L.latLngBounds(
        [NEPAL_BOUNDS.southWest.lat, NEPAL_BOUNDS.southWest.lng],
        [NEPAL_BOUNDS.northEast.lat, NEPAL_BOUNDS.northEast.lng],
      ),
    [],
  );

  const fitBounds = useMemo(
    () =>
      L.latLngBounds(
        [pickupLocation.lat, pickupLocation.lng],
        [deliveryLocation.lat, deliveryLocation.lng],
      ).pad(0.2),
    [pickupLocation, deliveryLocation],
  );

  return (
    <div className={className}>
      <MapContainer
        bounds={fitBounds}
        maxBounds={bounds}
        maxBoundsViscosity={1.0}
        minZoom={7}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} />
        <Marker
          position={[pickupLocation.lat, pickupLocation.lng]}
          icon={markerIcon}
        >
          <Popup>
            <span className="font-sans text-sm font-semibold">
              {pickupLabel ?? "Pickup"}
            </span>
          </Popup>
        </Marker>
        <Marker
          position={[deliveryLocation.lat, deliveryLocation.lng]}
          icon={markerIcon}
        >
          <Popup>
            <span className="font-sans text-sm font-semibold">
              {deliveryLabel ?? "Delivery"}
            </span>
          </Popup>
        </Marker>
        {routeCoordinates && routeCoordinates.length > 0 && (
          <Polyline
            positions={routeCoordinates}
            pathOptions={{
              color: "#F59E0B",
              weight: 4,
              opacity: 0.8,
              dashArray: "10, 10",
            }}
          />
        )}
      </MapContainer>
      <div className="mt-2 rounded-md bg-gray-100 p-3 text-center text-sm text-gray-600">
        Real-time rider tracking coming in Phase 2
      </div>
    </div>
  );
}
