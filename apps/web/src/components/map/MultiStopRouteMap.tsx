"use client";

import { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Polyline, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { MAP_TILE_URL, MAP_ATTRIBUTION, NEPAL_BOUNDS } from "@jirisewa/shared";
import { defaultMarkerIcon, numberedStopIcon } from "@/lib/leaflet-icons";
import type { TripStop } from "@/lib/types/trip-stop";
import type { LatLng } from "@/lib/map";

interface MultiStopRouteMapProps {
  origin: LatLng;
  destination: LatLng;
  originName?: string;
  destinationName?: string;
  stops: TripStop[];
  routeCoordinates?: [number, number][]; // [lat, lng] pairs
  currentStopIndex?: number;
  className?: string;
}

export default function MultiStopRouteMap({
  origin,
  destination,
  originName,
  destinationName,
  stops,
  routeCoordinates,
  currentStopIndex,
  className,
}: MultiStopRouteMapProps) {
  const nepalBounds = useMemo(
    () =>
      L.latLngBounds(
        [NEPAL_BOUNDS.southWest.lat, NEPAL_BOUNDS.southWest.lng],
        [NEPAL_BOUNDS.northEast.lat, NEPAL_BOUNDS.northEast.lng],
      ),
    [],
  );

  const fitBounds = useMemo(() => {
    const points: [number, number][] = [
      [origin.lat, origin.lng],
      [destination.lat, destination.lng],
      ...stops.map((s) => [s.location.lat, s.location.lng] as [number, number]),
    ];
    return L.latLngBounds(points).pad(0.15);
  }, [origin, destination, stops]);

  return (
    <div data-testid="multi-stop-route-map" className={className}>
      <MapContainer
        data-testid="multi-stop-route-map-canvas"
        bounds={fitBounds}
        maxBounds={nepalBounds}
        maxBoundsViscosity={1.0}
        minZoom={7}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} />

        {/* Origin marker */}
        <Marker position={[origin.lat, origin.lng]} icon={defaultMarkerIcon}>
          {originName && (
            <Popup>
              <span className="font-sans text-sm font-semibold">
                {originName}
              </span>
            </Popup>
          )}
        </Marker>

        {/* Destination marker */}
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

        {/* Numbered stop markers */}
        {stops.map((stop, i) => {
          const isCurrent = currentStopIndex === i;
          const icon = numberedStopIcon(i + 1, stop.stopType, stop.completed);

          return (
            <Marker
              key={stop.id}
              position={[stop.location.lat, stop.location.lng]}
              icon={icon}
              zIndexOffset={isCurrent ? 1000 : 0}
            >
              <Popup>
                <div className="font-sans text-sm">
                  <p className="font-semibold">
                    Stop {i + 1}:{" "}
                    {stop.stopType === "pickup" ? "Pickup" : "Delivery"}
                  </p>
                  {stop.address && (
                    <p className="text-xs text-gray-500">{stop.address}</p>
                  )}
                  {stop.completed && (
                    <p className="text-xs font-medium text-green-600">
                      Completed
                    </p>
                  )}
                </div>
              </Popup>
            </Marker>
          );
        })}

        {/* Route polyline */}
        {routeCoordinates && routeCoordinates.length > 0 && (
          <Polyline
            positions={routeCoordinates}
            pathOptions={{
              color: "#F59E0B",
              weight: 4,
              opacity: 0.8,
            }}
          />
        )}
      </MapContainer>
    </div>
  );
}
