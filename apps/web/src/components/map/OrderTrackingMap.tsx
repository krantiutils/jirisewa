"use client";

import { useEffect, useMemo } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  Polyline,
  useMap,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import {
  MAP_TILE_URL,
  MAP_ATTRIBUTION,
  NEPAL_BOUNDS,
} from "@jirisewa/shared";
import type { LatLng } from "@/lib/map";
import {
  riderMarkerIcon,
  pickupMarkerIcon,
  deliveryMarkerIcon,
  defaultMarkerIcon,
} from "@/lib/leaflet-icons";

interface OrderTrackingMapProps {
  pickupLocation: LatLng;
  deliveryLocation: LatLng;
  pickupLabel?: string;
  deliveryLabel?: string;
  /** Route coordinates as [lat, lng] pairs, if available */
  routeCoordinates?: [number, number][];
  /** Live rider position (null when not tracking) */
  riderLocation?: LatLng | null;
  /** Whether rider data is stale (no update in 30s) */
  isRiderStale?: boolean;
  /** Whether the order is actively being tracked */
  isTracking?: boolean;
  className?: string;
}

/**
 * Fit map bounds whenever rider position changes.
 * Ensures the rider marker stays visible on the map.
 */
function MapBoundsUpdater({
  riderLocation,
  deliveryLocation,
}: {
  riderLocation: LatLng | null;
  deliveryLocation: LatLng;
}) {
  const map = useMap();

  useEffect(() => {
    if (!riderLocation) return;

    const bounds = L.latLngBounds(
      [riderLocation.lat, riderLocation.lng],
      [deliveryLocation.lat, deliveryLocation.lng],
    ).pad(0.15);

    // Only adjust if the rider is outside current view
    const currentBounds = map.getBounds();
    if (
      !currentBounds.contains([riderLocation.lat, riderLocation.lng])
    ) {
      map.fitBounds(bounds, { animate: true, duration: 0.5 });
    }
  }, [riderLocation, deliveryLocation, map]);

  return null;
}

/**
 * Order tracking map with live rider position.
 *
 * Shows:
 * - Pickup marker (green) with status (confirmed pickup)
 * - Delivery destination marker (red pin)
 * - Route polyline (amber dashed when no tracking, blue solid when tracking)
 * - Live rider position (blue circle with motorcycle icon)
 */
export default function OrderTrackingMap({
  pickupLocation,
  deliveryLocation,
  pickupLabel,
  deliveryLabel,
  routeCoordinates,
  riderLocation,
  isRiderStale,
  isTracking,
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
      ).pad(0.15),
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

        {/* Route polyline */}
        {routeCoordinates && routeCoordinates.length > 0 && (
          <Polyline
            positions={routeCoordinates}
            pathOptions={{
              color: isTracking ? "#3B82F6" : "#F59E0B",
              weight: isTracking ? 5 : 4,
              opacity: 0.8,
              dashArray: isTracking ? undefined : "10, 10",
            }}
          />
        )}

        {/* Pickup marker */}
        <Marker
          position={[pickupLocation.lat, pickupLocation.lng]}
          icon={isTracking ? pickupMarkerIcon : defaultMarkerIcon}
        >
          <Popup>
            <span className="font-sans text-sm font-semibold">
              {pickupLabel ?? "Pickup"}
            </span>
          </Popup>
        </Marker>

        {/* Delivery marker */}
        <Marker
          position={[deliveryLocation.lat, deliveryLocation.lng]}
          icon={isTracking ? deliveryMarkerIcon : defaultMarkerIcon}
        >
          <Popup>
            <span className="font-sans text-sm font-semibold">
              {deliveryLabel ?? "Delivery"}
            </span>
          </Popup>
        </Marker>

        {/* Live rider marker */}
        {riderLocation && (
          <Marker
            position={[riderLocation.lat, riderLocation.lng]}
            icon={riderMarkerIcon}
            zIndexOffset={1000}
          >
            <Popup>
              <span className="font-sans text-sm font-semibold">
                Rider
                {isRiderStale && (
                  <span className="ml-1 text-xs text-amber-600">
                    (last seen &gt;30s ago)
                  </span>
                )}
              </span>
            </Popup>
          </Marker>
        )}

        {/* Keep rider in view */}
        {isTracking && (
          <MapBoundsUpdater
            riderLocation={riderLocation ?? null}
            deliveryLocation={deliveryLocation}
          />
        )}
      </MapContainer>
    </div>
  );
}
