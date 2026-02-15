"use client";

import { useEffect, useMemo, useState } from "react";
import { MapContainer, TileLayer, Marker, Polyline, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import {
  MAP_TILE_URL,
  MAP_ATTRIBUTION,
  NEPAL_BOUNDS,
} from "@jirisewa/shared";
import { fetchRoute } from "@/lib/map";
import type { LatLng } from "@/lib/map";
import { defaultMarkerIcon } from "@/lib/leaflet-icons";

interface TripRouteMapProps {
  origin: LatLng;
  destination: LatLng;
  originName?: string;
  destinationName?: string;
  /** Pre-computed route coordinates as [lat, lng] pairs. If provided, OSRM fetch is skipped. */
  routeCoordinates?: [number, number][];
  className?: string;
  onRouteLoaded?: (distanceMeters: number, durationSeconds: number) => void;
}

export default function TripRouteMap({
  origin,
  destination,
  originName,
  destinationName,
  routeCoordinates: precomputedRoute,
  className,
  onRouteLoaded,
}: TripRouteMapProps) {
  const [fetchedRoute, setFetchedRoute] = useState<[number, number][]>([]);
  const [loading, setLoading] = useState(!precomputedRoute);

  const routePositions = precomputedRoute ?? fetchedRoute;

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
        [origin.lat, origin.lng],
        [destination.lat, destination.lng],
      ).pad(0.2),
    [origin, destination],
  );

  useEffect(() => {
    if (precomputedRoute) {
      return;
    }

    let cancelled = false;

    async function loadRoute() {
      setLoading(true);
      const result = await fetchRoute(origin, destination);

      if (cancelled) return;

      if (result) {
        // OSRM returns [lng, lat], convert to [lat, lng] for Leaflet
        const positions: [number, number][] = result.coordinates.map(
          ([lng, lat]) => [lat, lng],
        );
        setFetchedRoute(positions);
        onRouteLoaded?.(result.distanceMeters, result.durationSeconds);
      } else {
        // Fallback: straight line between origin and destination
        setFetchedRoute([
          [origin.lat, origin.lng],
          [destination.lat, destination.lng],
        ]);
      }

      setLoading(false);
    }

    loadRoute();

    return () => {
      cancelled = true;
    };
  }, [origin, destination, precomputedRoute, onRouteLoaded]);

  return (
    <div data-testid="trip-route-map" className={className}>
      <MapContainer
        data-testid="trip-route-map-canvas"
        bounds={fitBounds}
        maxBounds={bounds}
        maxBoundsViscosity={1.0}
        minZoom={7}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} />
        <Marker position={[origin.lat, origin.lng]} icon={defaultMarkerIcon}>
          {originName && (
            <Popup>
              <span className="font-sans text-sm font-semibold">
                {originName}
              </span>
            </Popup>
          )}
        </Marker>
        <Marker
          position={[destination.lat, destination.lng]}
          icon={defaultMarkerIcon}
        >
          {destinationName && (
            <Popup>
              <span className="font-sans text-sm font-semibold">
                {destinationName}
              </span>
            </Popup>
          )}
        </Marker>
        {!loading && routePositions.length > 0 && (
          <Polyline
            positions={routePositions}
            pathOptions={{
              color: "#3B82F6",
              weight: 4,
              opacity: 0.8,
            }}
          />
        )}
      </MapContainer>
      {loading && (
        <div className="mt-2 text-sm text-gray-500">Loading route...</div>
      )}
    </div>
  );
}
