"use client";

import { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { MAP_TILE_URL, MAP_ATTRIBUTION, NEPAL_BOUNDS } from "@jirisewa/shared";
import type { OrderPing } from "@/lib/types/ping";

interface PingBeaconMapProps {
  pings: OrderPing[];
}

const pickupIcon = L.divIcon({
  className: "ping-beacon-icon",
  html: '<span style="display:block;width:14px;height:14px;border-radius:9999px;background:#10B981;border:2px solid #ffffff;box-shadow:0 0 0 2px rgba(16,185,129,0.4)"></span>',
  iconSize: [14, 14],
  iconAnchor: [7, 7],
});

const deliveryIcon = L.divIcon({
  className: "ping-beacon-icon",
  html: '<span style="display:block;width:14px;height:14px;border-radius:9999px;background:#EF4444;border:2px solid #ffffff;box-shadow:0 0 0 2px rgba(239,68,68,0.35)"></span>',
  iconSize: [14, 14],
  iconAnchor: [7, 7],
});

export default function PingBeaconMap({ pings }: PingBeaconMapProps) {
  const nepalBounds = useMemo(
    () =>
      L.latLngBounds(
        [NEPAL_BOUNDS.southWest.lat, NEPAL_BOUNDS.southWest.lng],
        [NEPAL_BOUNDS.northEast.lat, NEPAL_BOUNDS.northEast.lng],
      ),
    [],
  );

  const pickupPoints = useMemo(
    () =>
      pings.flatMap((ping) =>
        ping.pickupLocations.map((loc, i) => ({
          id: `${ping.id}-pickup-${i}`,
          lat: loc.lat,
          lng: loc.lng,
          label: loc.farmerName,
          earning: ping.estimatedEarnings,
        })),
      ),
    [pings],
  );

  const deliveryPoints = useMemo(
    () =>
      pings.map((ping) => ({
        id: `${ping.id}-delivery`,
        lat: ping.deliveryLocation.lat,
        lng: ping.deliveryLocation.lng,
        label: ping.deliveryLocation.address ?? "Delivery",
      })),
    [pings],
  );

  const fitBounds = useMemo(() => {
    const points: [number, number][] = [
      ...pickupPoints.map((p) => [p.lat, p.lng] as [number, number]),
      ...deliveryPoints.map((p) => [p.lat, p.lng] as [number, number]),
    ];
    if (points.length < 2) return undefined;
    return L.latLngBounds(points).pad(0.18);
  }, [pickupPoints, deliveryPoints]);

  if (pickupPoints.length === 0 && deliveryPoints.length === 0) return null;

  return (
    <div className="mb-4 overflow-hidden rounded-lg border-2 border-emerald-200">
      <div className="h-52">
        <MapContainer
          bounds={fitBounds}
          center={fitBounds ? undefined : [27.7172, 85.324]}
          zoom={fitBounds ? undefined : 10}
          maxBounds={nepalBounds}
          maxBoundsViscosity={1.0}
          minZoom={7}
          style={{ height: "100%", width: "100%" }}
        >
          <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} />

          {pickupPoints.map((point) => (
            <Marker
              key={point.id}
              position={[point.lat, point.lng]}
              icon={pickupIcon}
            >
              <Popup>
                <span className="font-sans text-sm font-semibold">
                  Farmer: {point.label}
                </span>
                <br />
                <span className="font-sans text-xs text-gray-500">
                  Potential earning: NPR {point.earning.toFixed(0)}
                </span>
              </Popup>
            </Marker>
          ))}

          {deliveryPoints.map((point) => (
            <Marker
              key={point.id}
              position={[point.lat, point.lng]}
              icon={deliveryIcon}
            >
              <Popup>
                <span className="font-sans text-sm font-semibold">
                  Delivery: {point.label}
                </span>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
      <div className="flex items-center gap-4 bg-emerald-50 px-3 py-2 text-xs text-emerald-900">
        <span className="inline-flex items-center gap-1">
          <span className="h-2.5 w-2.5 rounded-full bg-emerald-500" />
          Farmer beacon
        </span>
        <span className="inline-flex items-center gap-1">
          <span className="h-2.5 w-2.5 rounded-full bg-red-500" />
          Delivery point
        </span>
      </div>
    </div>
  );
}
