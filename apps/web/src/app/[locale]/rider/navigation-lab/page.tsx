"use client";

import dynamic from "next/dynamic";
import { StopType } from "@jirisewa/shared";
import type { OrderPing } from "@/lib/types/ping";
import type { TripStop } from "@/lib/types/trip-stop";

const PingBeaconMap = dynamic(
  () => import("@/components/rider/PingBeaconMap"),
  { ssr: false },
);

const TripRouteMap = dynamic(
  () => import("@/components/map/TripRouteMap"),
  { ssr: false },
);

const MultiStopRouteMap = dynamic(
  () => import("@/components/map/MultiStopRouteMap"),
  { ssr: false },
);

const OrderTrackingMap = dynamic(
  () => import("@/components/map/OrderTrackingMap"),
  { ssr: false },
);

const SAMPLE_PINGS: OrderPing[] = [
  {
    id: "lab-ping-1",
    orderId: "lab-order-1",
    riderId: "lab-rider-1",
    tripId: "lab-trip-1",
    pickupLocations: [
      { lat: 27.7295, lng: 85.3304, farmerName: "Kapan Farm Co-op" },
      { lat: 27.7182, lng: 85.3156, farmerName: "Baluwatar Greens" },
    ],
    deliveryLocation: {
      lat: 27.7022,
      lng: 85.3117,
      address: "Putalisadak Delivery Zone",
    },
    totalWeightKg: 38,
    estimatedEarnings: 425,
    detourDistanceM: 1600,
    status: "pending",
    expiresAt: new Date("2026-02-15T10:15:00.000Z"),
    createdAt: new Date("2026-02-15T10:00:00.000Z"),
  },
];

const SAMPLE_STOPS: TripStop[] = [
  {
    id: "lab-stop-1",
    tripId: "lab-trip-1",
    stopType: StopType.Pickup,
    location: { lat: 27.7295, lng: 85.3304 },
    address: "Kapan Farm Co-op",
    addressNe: null,
    sequenceOrder: 1,
    estimatedArrival: null,
    actualArrival: null,
    orderItemIds: ["oi-lab-1"],
    completed: true,
  },
  {
    id: "lab-stop-2",
    tripId: "lab-trip-1",
    stopType: StopType.Pickup,
    location: { lat: 27.7182, lng: 85.3156 },
    address: "Baluwatar Greens",
    addressNe: null,
    sequenceOrder: 2,
    estimatedArrival: null,
    actualArrival: null,
    orderItemIds: ["oi-lab-2"],
    completed: false,
  },
  {
    id: "lab-stop-3",
    tripId: "lab-trip-1",
    stopType: StopType.Delivery,
    location: { lat: 27.7022, lng: 85.3117 },
    address: "Putalisadak Delivery Zone",
    addressNe: null,
    sequenceOrder: 3,
    estimatedArrival: null,
    actualArrival: null,
    orderItemIds: ["oi-lab-1", "oi-lab-2"],
    completed: false,
  },
];

const SAMPLE_ROUTE: [number, number][] = [
  [27.7362, 85.3308],
  [27.7295, 85.3304],
  [27.7231, 85.3232],
  [27.7182, 85.3156],
  [27.7113, 85.3135],
  [27.7022, 85.3117],
  [27.6933, 85.3088],
];

export default function RiderNavigationLabPage() {
  return (
    <main className="min-h-screen bg-muted" data-testid="rider-navigation-lab">
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <h1 className="text-2xl font-bold text-foreground">
          Rider Navigation Lab
        </h1>
        <p className="mt-2 text-sm text-gray-600">
          Deterministic preview of beacon, route optimization, and live tracking
          maps for validation.
        </p>

        <section className="mt-6 rounded-lg border-2 border-border bg-white p-4">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-gray-500">
            Beacon Opportunities
          </h2>
          <PingBeaconMap pings={SAMPLE_PINGS} />
        </section>

        <section className="mt-6 grid gap-6 lg:grid-cols-2">
          <div className="rounded-lg border-2 border-border bg-white p-4">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-gray-500">
              Base Route
            </h2>
            <div className="mt-3 h-72 overflow-hidden rounded-md border-2 border-border">
              <TripRouteMap
                origin={{ lat: 27.7362, lng: 85.3308 }}
                destination={{ lat: 27.6933, lng: 85.3088 }}
                originName="Maharajgunj Origin"
                destinationName="Kalimati Destination"
                routeCoordinates={SAMPLE_ROUTE}
                className="h-full"
              />
            </div>
          </div>

          <div className="rounded-lg border-2 border-border bg-white p-4">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-gray-500">
              Optimized Multi-Stop Route
            </h2>
            <div className="mt-3 h-72 overflow-hidden rounded-md border-2 border-border">
              <MultiStopRouteMap
                origin={{ lat: 27.7362, lng: 85.3308 }}
                destination={{ lat: 27.6933, lng: 85.3088 }}
                originName="Maharajgunj Origin"
                destinationName="Kalimati Destination"
                stops={SAMPLE_STOPS}
                routeCoordinates={SAMPLE_ROUTE}
                currentStopIndex={1}
                className="h-full"
              />
            </div>
          </div>
        </section>

        <section className="mt-6 rounded-lg border-2 border-border bg-white p-4">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-gray-500">
            Live Order Tracking
          </h2>
          <div className="mt-3 h-80 overflow-hidden rounded-md border-2 border-border">
            <OrderTrackingMap
              pickupLocation={{ lat: 27.7182, lng: 85.3156 }}
              deliveryLocation={{ lat: 27.7022, lng: 85.3117 }}
              pickupLabel="Farmer pickup"
              deliveryLabel="Consumer drop"
              routeCoordinates={SAMPLE_ROUTE}
              riderLocation={{ lat: 27.7113, lng: 85.3135 }}
              isTracking
              className="h-full"
            />
          </div>
        </section>
      </div>
    </main>
  );
}
