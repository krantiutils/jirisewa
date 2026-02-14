"use client";

import { useMemo } from "react";
import { Loader2, Navigation, Clock, AlertTriangle } from "lucide-react";
import { useRiderTracking } from "@/hooks/useRiderTracking";
import { OrderTrackingMap } from "@/components/map";
import type { LatLng } from "@/lib/map";

interface RiderTrackingSectionProps {
  tripId: string;
  deliveryLocation: LatLng;
  /** Pickup is approximated from the trip origin */
  orderStatus: string;
}

function formatEta(seconds: number): string {
  if (seconds < 60) return "< 1 min";
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins} min`;
  const hours = Math.floor(mins / 60);
  const remainMins = mins % 60;
  return remainMins > 0 ? `${hours}h ${remainMins}m` : `${hours}h`;
}

function formatDistance(meters: number): string {
  if (meters < 1000) return `${Math.round(meters)} m`;
  return `${(meters / 1000).toFixed(1)} km`;
}

/**
 * Live rider tracking section for the order detail page.
 * Shows a map with real-time rider position and ETA info bar.
 */
export default function RiderTrackingSection({
  tripId,
  deliveryLocation,
  orderStatus,
}: RiderTrackingSectionProps) {
  const {
    riderLocation,
    tripRoute,
    etaSeconds,
    remainingDistanceMeters,
    isStale,
    loading,
    error,
  } = useRiderTracking(tripId, deliveryLocation.lat, deliveryLocation.lng);

  const pickupLocation: LatLng = useMemo(() => {
    if (tripRoute) {
      return { lat: tripRoute.originLat, lng: tripRoute.originLng };
    }
    // Fallback: use delivery location (map will still show)
    return deliveryLocation;
  }, [tripRoute, deliveryLocation]);

  const routeCoordinates = tripRoute?.routeCoordinates ?? undefined;

  const riderLatLng: LatLng | null = riderLocation
    ? { lat: riderLocation.lat, lng: riderLocation.lng }
    : null;

  if (loading) {
    return (
      <section className="mt-6">
        <div className="flex items-center justify-center rounded-lg bg-white p-8">
          <Loader2 className="h-6 w-6 animate-spin text-primary" />
          <span className="ml-2 text-sm text-gray-500">
            Loading tracking...
          </span>
        </div>
      </section>
    );
  }

  if (error) {
    return (
      <section className="mt-6">
        <div className="rounded-lg bg-red-50 p-4 text-center text-sm text-red-600">
          {error}
        </div>
      </section>
    );
  }

  const isActiveTracking =
    orderStatus === "picked_up" || orderStatus === "in_transit";

  return (
    <section className="mt-6">
      {/* ETA info bar */}
      {isActiveTracking && (etaSeconds !== null || riderLocation) && (
        <div className="mb-3 flex items-center justify-between rounded-lg bg-blue-50 px-4 py-3">
          <div className="flex items-center gap-4">
            {etaSeconds !== null && (
              <div className="flex items-center gap-1.5">
                <Clock className="h-4 w-4 text-blue-600" />
                <span className="text-sm font-semibold text-blue-900">
                  ETA: {formatEta(etaSeconds)}
                </span>
              </div>
            )}
            {remainingDistanceMeters !== null && (
              <div className="flex items-center gap-1.5">
                <Navigation className="h-4 w-4 text-blue-600" />
                <span className="text-sm text-blue-800">
                  {formatDistance(remainingDistanceMeters)} away
                </span>
              </div>
            )}
          </div>
          {isStale && (
            <div className="flex items-center gap-1 text-amber-600">
              <AlertTriangle className="h-4 w-4" />
              <span className="text-xs">Signal lost</span>
            </div>
          )}
        </div>
      )}

      {/* Tracking map */}
      <OrderTrackingMap
        pickupLocation={pickupLocation}
        deliveryLocation={deliveryLocation}
        pickupLabel={tripRoute?.originName ?? "Pickup"}
        deliveryLabel="Delivery"
        routeCoordinates={routeCoordinates}
        riderLocation={riderLatLng}
        isRiderStale={isStale}
        isTracking={isActiveTracking}
        className="h-72 overflow-hidden rounded-lg sm:h-80"
      />

      {/* Status text below map */}
      {!isActiveTracking && orderStatus === "matched" && (
        <p className="mt-2 text-center text-sm text-gray-500">
          Rider matched — waiting for pickup
        </p>
      )}
    </section>
  );
}
