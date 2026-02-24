"use client";

import { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
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
import MarkerClusterGroup from "react-leaflet-cluster";
import { useTranslations } from "next-intl";
import { deliveryMarkerIcon } from "@/lib/leaflet-icons";
import { OrderStatusBadge } from "./OrderStatusBadge";
import type { OrderStatus } from "@/lib/types/order";

export interface OrderMapItem {
  id: string;
  deliveryAddress: string;
  lat: number;
  lng: number;
  status: string;
  itemCount: number;
  totalPrice: number;
}

interface OrdersMapViewProps {
  orders: OrderMapItem[];
  onSelect: (orderId: string) => void;
}

export default function OrdersMapView({ orders, onSelect }: OrdersMapViewProps) {
  const t = useTranslations("orders");

  const bounds = useMemo(
    () =>
      L.latLngBounds(
        [NEPAL_BOUNDS.southWest.lat, NEPAL_BOUNDS.southWest.lng],
        [NEPAL_BOUNDS.northEast.lat, NEPAL_BOUNDS.northEast.lng],
      ),
    [],
  );

  const mapCenter = useMemo(() => {
    if (orders.length === 0) return [MAP_DEFAULT_CENTER.lat, MAP_DEFAULT_CENTER.lng] as [number, number];
    const avgLat = orders.reduce((sum, o) => sum + o.lat, 0) / orders.length;
    const avgLng = orders.reduce((sum, o) => sum + o.lng, 0) / orders.length;
    return [avgLat, avgLng] as [number, number];
  }, [orders]);

  return (
    <div className="h-[calc(100vh-320px)] min-h-[350px] rounded-lg overflow-hidden border-2 border-gray-200">
      <MapContainer
        center={mapCenter}
        zoom={orders.length > 0 ? 11 : 8}
        maxBounds={bounds}
        maxBoundsViscosity={0.7}
        minZoom={7}
        maxZoom={19}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} maxZoom={19} />

        <MarkerClusterGroup chunkedLoading>
          {orders.map((order) => (
            <Marker
              key={order.id}
              position={[order.lat, order.lng]}
              icon={deliveryMarkerIcon}
            >
              <Popup maxWidth={250} minWidth={180}>
                <div className="space-y-1.5 text-sm">
                  <p className="font-semibold text-gray-900 truncate">
                    {order.deliveryAddress}
                  </p>
                  <div className="flex items-center justify-between">
                    <OrderStatusBadge status={order.status as OrderStatus} />
                    <span className="font-bold">NPR {order.totalPrice.toFixed(0)}</span>
                  </div>
                  <p className="text-xs text-gray-500">
                    {t("totalItems", { count: order.itemCount })}
                  </p>
                  <button
                    onClick={() => onSelect(order.id)}
                    className="mt-1 w-full rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-600 transition-colors"
                  >
                    {t("viewOrder")}
                  </button>
                </div>
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>
      </MapContainer>
    </div>
  );
}
