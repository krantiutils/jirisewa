"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
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
import "react-leaflet-cluster/dist/assets/MarkerCluster.css";
import "react-leaflet-cluster/dist/assets/MarkerCluster.Default.css";
import {
  MAP_TILE_URL,
  MAP_ATTRIBUTION,
  MAP_DEFAULT_CENTER,
  NEPAL_BOUNDS,
} from "@jirisewa/shared";
import { useTranslations } from "next-intl";
import { deliveryMarkerIcon, riderMarkerIcon, pickupMarkerIcon } from "@/lib/leaflet-icons";
import { Button } from "@/components/ui/Button";
import MarkerClusterGroup from "react-leaflet-cluster";
import { fetchRoute } from "@/lib/map";
import type { AvailableOrder } from "@/lib/actions/available-orders";

export interface FixedRoute {
  originLat: number;
  originLng: number;
  originName: string;
  destLat: number;
  destLng: number;
  destName: string;
}

interface AvailableOrdersMapProps {
  orders: AvailableOrder[];
  onAccept: (orderId: string) => void;
  accepting: string | null;
  fixedRoute?: FixedRoute | null;
}

function RiderLocationMarker() {
  const map = useMap();
  const [pos, setPos] = useState<L.LatLng | null>(null);

  useEffect(() => {
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (p) => {
        const latlng = L.latLng(p.coords.latitude, p.coords.longitude);
        setPos(latlng);
        map.setView(latlng, 12);
      },
      (err) => {
        console.log("Geolocation unavailable:", err.message);
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }, [map]);

  if (!pos) return null;
  return (
    <Marker position={pos} icon={riderMarkerIcon}>
      <Popup>Your location</Popup>
    </Marker>
  );
}

/** Fetches and draws the rider's fixed route on the map */
function FixedRouteLine({ route }: { route: FixedRoute }) {
  const map = useMap();
  const [routeCoords, setRouteCoords] = useState<[number, number][] | null>(null);

  useEffect(() => {
    const origin = { lat: route.originLat, lng: route.originLng };
    const dest = { lat: route.destLat, lng: route.destLng };

    // Fit map to show the fixed route
    const bounds = L.latLngBounds(
      [origin.lat, origin.lng],
      [dest.lat, dest.lng],
    );
    map.fitBounds(bounds, { padding: [50, 50] });

    // Fetch actual road route
    fetchRoute(origin, dest).then((result) => {
      if (result) {
        setRouteCoords(
          result.coordinates.map(([lng, lat]) => [lat, lng] as [number, number]),
        );
      } else {
        // Fallback: straight line
        setRouteCoords([
          [origin.lat, origin.lng],
          [dest.lat, dest.lng],
        ]);
      }
    });
  }, [route, map]);

  if (!routeCoords) return null;

  return (
    <>
      <Polyline
        positions={routeCoords}
        pathOptions={{ color: "#f59e0b", weight: 4, opacity: 0.7, dashArray: "10 6" }}
      />
      <Marker position={[route.originLat, route.originLng]} icon={riderMarkerIcon}>
        <Popup>{route.originName}</Popup>
      </Marker>
      <Marker position={[route.destLat, route.destLng]} icon={riderMarkerIcon}>
        <Popup>{route.destName}</Popup>
      </Marker>
    </>
  );
}

export function AvailableOrdersMap({
  orders,
  onAccept,
  accepting,
  fixedRoute,
}: AvailableOrdersMapProps) {
  const t = useTranslations("rider");

  const bounds = useMemo(
    () =>
      L.latLngBounds(
        [NEPAL_BOUNDS.southWest.lat, NEPAL_BOUNDS.southWest.lng],
        [NEPAL_BOUNDS.northEast.lat, NEPAL_BOUNDS.northEast.lng],
      ),
    [],
  );

  return (
    <div className="h-[calc(100vh-220px)] min-h-[400px] rounded-lg overflow-hidden border-2 border-gray-200">
      <MapContainer
        center={[MAP_DEFAULT_CENTER.lat, MAP_DEFAULT_CENTER.lng]}
        zoom={10}
        maxBounds={bounds}
        maxBoundsViscosity={0.7}
        minZoom={7}
        maxZoom={19}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} maxZoom={19} />
        {!fixedRoute && <RiderLocationMarker />}
        {fixedRoute && <FixedRouteLine route={fixedRoute} />}

        <MarkerClusterGroup chunkedLoading>
          {orders.map((order) => (
            <Marker
              key={order.id}
              position={[order.deliveryLat, order.deliveryLng]}
              icon={deliveryMarkerIcon}
            >
              <Popup maxWidth={280} minWidth={220}>
                <div className="space-y-2 text-sm">
                  <p className="font-semibold text-gray-900 truncate">
                    {order.deliveryAddress}
                  </p>

                  {/* Items summary */}
                  <div className="text-gray-600">
                    {order.items.slice(0, 3).map((item, i) => (
                      <p key={i} className="truncate">
                        {item.nameEn} — {item.quantityKg} kg
                        <span className="text-gray-400"> ({item.farmerName})</span>
                      </p>
                    ))}
                    {order.items.length > 3 && (
                      <p className="text-gray-400">+{order.items.length - 3} more</p>
                    )}
                  </div>

                  {/* Weight + Earnings */}
                  <div className="flex justify-between border-t border-gray-100 pt-2">
                    <span className="text-gray-500">
                      {t("dashboard.orderWeight")}: {order.totalWeightKg} kg
                    </span>
                    <span className="font-semibold text-emerald-600">
                      NPR {order.deliveryFee.toFixed(0)}
                    </span>
                  </div>

                  <Button
                    className="w-full mt-1"
                    onClick={() => onAccept(order.id)}
                    disabled={accepting !== null}
                  >
                    {accepting === order.id
                      ? t("dashboard.accepting")
                      : t("dashboard.acceptOrder")}
                  </Button>
                </div>
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>

        {/* Pickup location markers (green) */}
        <MarkerClusterGroup chunkedLoading>
          {orders.flatMap((order) =>
            order.pickupLocations
              .filter((p) => p.lat !== 0 && p.lng !== 0)
              .map((pickup, i) => (
                <Marker
                  key={`pickup-${order.id}-${i}`}
                  position={[pickup.lat, pickup.lng]}
                  icon={pickupMarkerIcon}
                >
                  <Popup>
                    <p className="text-sm font-semibold">{pickup.farmerName}</p>
                    <p className="text-xs text-gray-500">Pickup location</p>
                  </Popup>
                </Marker>
              )),
          )}
        </MarkerClusterGroup>
      </MapContainer>
    </div>
  );
}
