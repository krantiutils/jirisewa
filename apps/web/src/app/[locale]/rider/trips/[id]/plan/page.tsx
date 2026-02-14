"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { TripStatus } from "@jirisewa/shared";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { getTrip } from "@/lib/actions/trips";
import {
  listTripStops,
  buildStopsFromOrders,
  optimizeTripRoute,
} from "@/lib/actions/trip-stops";
import { listOrdersByTrip } from "@/lib/actions/orders";
import type { Trip } from "@/lib/types/trip";
import type { TripStop } from "@/lib/types/trip-stop";
import type { OrderWithDetails } from "@/lib/types/order";

const MultiStopRouteMap = dynamic(
  () => import("@/components/map/MultiStopRouteMap"),
  { ssr: false },
);

export default function TripPlanPage() {
  const t = useTranslations("rider");
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string;
  const tripId = params.id as string;

  const [trip, setTrip] = useState<Trip | null>(null);
  const [stops, setStops] = useState<TripStop[]>([]);
  const [orders, setOrders] = useState<OrderWithDetails[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [optimizing, setOptimizing] = useState(false);

  const reload = useCallback(async () => {
    const [tripResult, stopsResult, ordersResult] = await Promise.all([
      getTrip(tripId),
      listTripStops(tripId),
      listOrdersByTrip(tripId),
    ]);

    if (tripResult.error) {
      setError(tripResult.error);
    } else if (tripResult.data) {
      setTrip(tripResult.data);
    }

    if (stopsResult.data) setStops(stopsResult.data);
    if (ordersResult.data) setOrders(ordersResult.data);
  }, [tripId]);

  useEffect(() => {
    async function loadAll() {
      setLoading(true);
      await reload();
      setLoading(false);
    }
    loadAll();
  }, [reload]);

  const handleOptimize = useCallback(async () => {
    setOptimizing(true);
    setError(null);

    // Build stops from orders if none exist yet
    if (stops.length === 0 && orders.length > 0) {
      const buildResult = await buildStopsFromOrders(tripId);
      if (buildResult.error) {
        setError(buildResult.error);
        setOptimizing(false);
        return;
      }
    }

    // Run optimization
    const optResult = await optimizeTripRoute(tripId);
    if (optResult.error) {
      setError(optResult.error);
    }

    await reload();
    setOptimizing(false);
  }, [tripId, stops.length, orders.length, reload]);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-muted">
        <p className="text-gray-500">{t("loading")}</p>
      </div>
    );
  }

  if (!trip) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-muted">
        <p className="text-gray-500">{error ?? t("tripNotFound")}</p>
        <Button
          variant="outline"
          onClick={() => router.push(`/${locale}/rider/dashboard`)}
        >
          {t("backToDashboard")}
        </Button>
      </div>
    );
  }

  const totalEarnings = orders.reduce(
    (sum, o) => sum + Number(o.delivery_fee ?? 0),
    0,
  );

  return (
    <div className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        <button
          onClick={() =>
            router.push(`/${locale}/rider/trips/${tripId}`)
          }
          className="mb-4 text-sm text-primary hover:underline"
        >
          &larr; {t("tripPlan.backToTrip")}
        </button>

        <h1 className="mb-6 text-2xl font-bold text-foreground">
          {t("tripPlan.title")}
        </h1>

        {error && (
          <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Map with all stops */}
        <Card className="mb-6 p-0 overflow-hidden">
          <div className="h-80">
            <MultiStopRouteMap
              origin={trip.origin}
              destination={trip.destination}
              originName={trip.originName}
              destinationName={trip.destinationName}
              stops={stops}
              routeCoordinates={trip.routeCoordinates ?? undefined}
              className="h-full"
            />
          </div>
        </Card>

        {/* Route summary */}
        <Card className="mb-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold">
              {t("tripPlan.routeSummary")}
            </h2>
            <Button
              onClick={handleOptimize}
              className="h-9 bg-amber-500 hover:bg-amber-600 text-sm"
              disabled={optimizing || orders.length === 0}
            >
              {optimizing
                ? t("tripPlan.optimizing")
                : t("tripPlan.optimizeRoute")}
            </Button>
          </div>

          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-gray-500">{t("tripPlan.totalStops")}</dt>
              <dd className="font-medium">{stops.length}</dd>
            </div>
            {trip.totalDistanceKm != null && (
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripPlan.totalDistance")}</dt>
                <dd className="font-medium">{trip.totalDistanceKm} km</dd>
              </div>
            )}
            {trip.estimatedDurationMinutes != null && (
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripPlan.estDuration")}</dt>
                <dd className="font-medium">
                  {trip.estimatedDurationMinutes} {t("tripPlan.minutes")}
                </dd>
              </div>
            )}
            <div className="flex justify-between">
              <dt className="text-gray-500">{t("tripPlan.totalOrders")}</dt>
              <dd className="font-medium">{orders.length}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">{t("tripPlan.totalEarnings")}</dt>
              <dd className="font-bold text-amber-600">
                NPR {totalEarnings.toFixed(0)}
              </dd>
            </div>
          </dl>
        </Card>

        {/* Stop sequence list */}
        <Card className="mb-6">
          <h2 className="mb-4 text-lg font-semibold">
            {t("tripPlan.stopSequence")}
          </h2>

          {stops.length === 0 ? (
            <div className="text-center py-6">
              <p className="text-sm text-gray-500 mb-3">
                {orders.length > 0
                  ? t("tripPlan.noStopsYet")
                  : t("tripPlan.noOrdersYet")}
              </p>
              {orders.length > 0 && (
                <Button
                  onClick={handleOptimize}
                  className="bg-amber-500 hover:bg-amber-600"
                  disabled={optimizing}
                >
                  {t("tripPlan.buildRoute")}
                </Button>
              )}
            </div>
          ) : (
            <div className="space-y-2">
              {/* Origin */}
              <div className="flex items-center gap-3 rounded-md border border-blue-200 bg-blue-50 p-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-blue-500 text-xs font-bold text-white">
                  S
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-foreground">
                    {t("tripPlan.startPoint")}
                  </p>
                  <p className="truncate text-xs text-gray-500">
                    {trip.originName}
                  </p>
                </div>
              </div>

              {/* Stops */}
              {stops.map((stop, i) => {
                const isPickup = stop.stopType === "pickup";
                return (
                  <div
                    key={stop.id}
                    className={`flex items-center gap-3 rounded-md border p-3 ${
                      isPickup
                        ? "border-emerald-200 bg-emerald-50"
                        : "border-amber-200 bg-amber-50"
                    }`}
                  >
                    <span
                      className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white ${
                        isPickup ? "bg-emerald-500" : "bg-amber-500"
                      }`}
                    >
                      {i + 1}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium text-foreground">
                        {isPickup
                          ? t("tripPlan.pickupStop")
                          : t("tripPlan.deliveryStop")}
                      </p>
                      {stop.address && (
                        <p className="truncate text-xs text-gray-500">
                          {stop.address}
                        </p>
                      )}
                      {stop.estimatedArrival && (
                        <p className="text-xs text-gray-400">
                          {t("tripPlan.eta")}{" "}
                          {stop.estimatedArrival.toLocaleTimeString(
                            locale === "ne" ? "ne-NP" : "en-US",
                            { hour: "2-digit", minute: "2-digit" },
                          )}
                        </p>
                      )}
                    </div>
                    <span className="shrink-0 text-xs text-gray-400">
                      {stop.orderItemIds.length}{" "}
                      {stop.orderItemIds.length === 1
                        ? t("tripPlan.item")
                        : t("tripPlan.items")}
                    </span>
                  </div>
                );
              })}

              {/* Destination */}
              <div className="flex items-center gap-3 rounded-md border border-blue-200 bg-blue-50 p-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-blue-500 text-xs font-bold text-white">
                  E
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-foreground">
                    {t("tripPlan.endPoint")}
                  </p>
                  <p className="truncate text-xs text-gray-500">
                    {trip.destinationName}
                  </p>
                </div>
              </div>
            </div>
          )}
        </Card>

        {/* Actions */}
        <div className="flex gap-3">
          <Button
            variant="outline"
            onClick={() =>
              router.push(`/${locale}/rider/trips/${tripId}`)
            }
            className="flex-1"
          >
            {t("tripPlan.backToTrip")}
          </Button>
          {trip.status === TripStatus.Scheduled && stops.length > 0 && (
            <Button
              onClick={() =>
                router.push(`/${locale}/rider/trips/${tripId}`)
              }
              className="flex-1"
            >
              {t("tripPlan.ready")}
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
