"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { TripStatus, OrderItemStatus } from "@jirisewa/shared";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { TripStatusBadge } from "@/components/rider/TripStatusBadge";
import { PingNotificationPanel } from "@/components/rider/PingNotificationPanel";
import {
  getTrip,
  startTrip,
  completeTrip,
  cancelTrip,
} from "@/lib/actions/trips";
import {
  listOrdersByTrip,
  confirmPickup,
  confirmFarmerPickup,
  markItemsUnavailable,
  startDelivery,
} from "@/lib/actions/orders";
import {
  listTripStops,
  completeTripStop,
  buildStopsFromOrders,
  optimizeTripRoute,
} from "@/lib/actions/trip-stops";
import { usePingSubscription } from "@/lib/hooks/usePingSubscription";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import type { Trip } from "@/lib/types/trip";
import type { TripStop } from "@/lib/types/trip-stop";
import type {
  OrderWithDetails,
  OrderStatus,
  OrderItemWithDetails,
} from "@/lib/types/order";

const TripRouteMap = dynamic(
  () => import("@/components/map/TripRouteMap"),
  { ssr: false },
);

const MultiStopRouteMap = dynamic(
  () => import("@/components/map/MultiStopRouteMap"),
  { ssr: false },
);

export default function TripDetailPage() {
  const t = useTranslations("rider");
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string;
  const tripId = params.id as string;

  const [trip, setTrip] = useState<Trip | null>(null);
  const [matchedOrders, setMatchedOrders] = useState<OrderWithDetails[]>([]);
  const [stops, setStops] = useState<TripStop[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [optimizing, setOptimizing] = useState(false);
  const { pings, removePing } = usePingSubscription();

  const currentStopIndex = stops.findIndex((s) => !s.completed);

  const loadOrders = useCallback(async () => {
    const result = await listOrdersByTrip(tripId);
    if (result.data) {
      setMatchedOrders(result.data);
    }
  }, [tripId]);

  const loadStops = useCallback(async () => {
    const result = await listTripStops(tripId);
    if (result.data) {
      setStops(result.data);
    }
  }, [tripId]);

  useEffect(() => {
    async function load() {
      setLoading(true);
      const result = await getTrip(tripId);

      if (result.error) {
        setError(result.error);
      } else if (result.data) {
        setTrip(result.data);
      }

      await Promise.all([loadOrders(), loadStops()]);
      setLoading(false);
    }

    load();
  }, [tripId, loadOrders, loadStops]);

  const handleStart = useCallback(async () => {
    setActionLoading(true);
    setError(null);
    const result = await startTrip(tripId);

    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      setTrip(result.data);
    }

    setActionLoading(false);
  }, [tripId]);

  const handleComplete = useCallback(async () => {
    setActionLoading(true);
    setError(null);
    const result = await completeTrip(tripId);

    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      setTrip(result.data);
    }

    setActionLoading(false);
  }, [tripId]);

  const handleCancel = useCallback(async () => {
    setActionLoading(true);
    setError(null);
    const result = await cancelTrip(tripId);

    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      setTrip(result.data);
    }

    setActionLoading(false);
  }, [tripId]);

  const handleBuildAndOptimize = useCallback(async () => {
    setOptimizing(true);
    setError(null);

    // Build stops from matched orders
    const buildResult = await buildStopsFromOrders(tripId);
    if (buildResult.error) {
      setError(buildResult.error);
      setOptimizing(false);
      return;
    }

    // Optimize the route
    const optResult = await optimizeTripRoute(tripId);
    if (optResult.error) {
      setError(optResult.error);
    }

    // Reload trip + stops
    const tripResult = await getTrip(tripId);
    if (tripResult.data) setTrip(tripResult.data);
    await loadStops();

    setOptimizing(false);
  }, [tripId, loadStops]);

  const handleCompleteStop = useCallback(
    async (stopId: string) => {
      setActionLoading(true);
      setError(null);
      const result = await completeTripStop(stopId);

      if (result.error) {
        setError(result.error);
      } else {
        await loadStops();
      }

      setActionLoading(false);
    },
    [loadStops],
  );

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

  const departureDate = trip.departureAt.toLocaleDateString(
    locale === "ne" ? "ne-NP" : "en-US",
    { year: "numeric", month: "long", day: "numeric" },
  );

  const departureTime = trip.departureAt.toLocaleTimeString(
    locale === "ne" ? "ne-NP" : "en-US",
    { hour: "2-digit", minute: "2-digit" },
  );

  const hasStops = stops.length > 0;

  return (
    <div className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        <button
          onClick={() => router.push(`/${locale}/rider/dashboard`)}
          className="mb-4 text-sm text-primary hover:underline"
        >
          &larr; {t("backToDashboard")}
        </button>

        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-foreground">
            {t("tripDetail.title")}
          </h1>
          <TripStatusBadge status={trip.status} />
        </div>

        {error && (
          <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Route Map — use multi-stop map when stops exist */}
        <Card className="mb-6 p-0 overflow-hidden">
          <div className="h-64">
            {hasStops ? (
              <MultiStopRouteMap
                origin={trip.origin}
                destination={trip.destination}
                originName={trip.originName}
                destinationName={trip.destinationName}
                stops={stops}
                routeCoordinates={trip.routeCoordinates ?? undefined}
                currentStopIndex={currentStopIndex >= 0 ? currentStopIndex : undefined}
                className="h-full"
              />
            ) : (
              <TripRouteMap
                origin={trip.origin}
                destination={trip.destination}
                originName={trip.originName}
                destinationName={trip.destinationName}
                routeCoordinates={trip.routeCoordinates ?? undefined}
                className="h-full"
              />
            )}
          </div>
        </Card>

        {/* Ping notifications — shown when trip is in_transit */}
        {trip.status === TripStatus.InTransit && pings.length > 0 && (
          <PingNotificationPanel
            pings={pings}
            onPingRemoved={removePing}
            onAccepted={async () => {
              const tripResult = await getTrip(tripId);
              if (tripResult.data) setTrip(tripResult.data);
              await Promise.all([loadOrders(), loadStops()]);
            }}
          />
        )}

        {/* Trip Info */}
        <Card className="mb-6">
          <h2 className="mb-4 text-lg font-semibold">
            {t("tripDetail.info")}
          </h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-gray-500">{t("tripForm.from")}</dt>
              <dd className="max-w-[60%] truncate text-right font-medium">
                {trip.originName}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">{t("tripForm.to")}</dt>
              <dd className="max-w-[60%] truncate text-right font-medium">
                {trip.destinationName}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">{t("tripForm.departure")}</dt>
              <dd className="font-medium">
                {departureDate} {departureTime}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">{t("tripDetail.totalCapacity")}</dt>
              <dd className="font-medium">{trip.availableCapacityKg} kg</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">
                {t("tripDetail.remainingCapacity")}
              </dt>
              <dd className="font-medium">{trip.remainingCapacityKg} kg</dd>
            </div>
            {trip.totalDistanceKm != null && (
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripDetail.totalDistance")}</dt>
                <dd className="font-medium">{trip.totalDistanceKm} km</dd>
              </div>
            )}
            {trip.estimatedDurationMinutes != null && (
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripDetail.estDuration")}</dt>
                <dd className="font-medium">
                  {trip.estimatedDurationMinutes} {t("tripDetail.minutes")}
                </dd>
              </div>
            )}
          </dl>
        </Card>

        {/* Route Stops — step-by-step navigation */}
        {hasStops && (
          <Card className="mb-6">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold">
                {t("tripDetail.routeStops")}
              </h2>
              {matchedOrders.length > 0 && (
                <Button
                  variant="outline"
                  className="h-8 text-xs border-amber-300 text-amber-700 hover:bg-amber-50"
                  onClick={handleBuildAndOptimize}
                  disabled={optimizing || actionLoading}
                >
                  {optimizing
                    ? t("tripDetail.optimizing")
                    : t("tripDetail.optimizeRoute")}
                </Button>
              )}
            </div>
            <div className="space-y-2">
              {stops.map((stop, i) => {
                const isCurrent = currentStopIndex === i;
                const isPickup = stop.stopType === "pickup";

                return (
                  <div
                    key={stop.id}
                    className={`flex items-center gap-3 rounded-md border p-3 transition-all ${
                      stop.completed
                        ? "border-gray-200 bg-gray-50 opacity-60"
                        : isCurrent
                          ? "border-amber-300 bg-amber-50"
                          : "border-gray-200"
                    }`}
                  >
                    {/* Sequence number */}
                    <span
                      className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white ${
                        stop.completed
                          ? "bg-gray-400"
                          : isPickup
                            ? "bg-emerald-500"
                            : "bg-amber-500"
                      }`}
                    >
                      {i + 1}
                    </span>

                    {/* Stop info */}
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium text-foreground">
                        {isPickup
                          ? t("tripDetail.pickupStop")
                          : t("tripDetail.deliveryStop")}
                      </p>
                      {stop.address && (
                        <p className="truncate text-xs text-gray-500">
                          {stop.address}
                        </p>
                      )}
                      {stop.estimatedArrival && !stop.completed && (
                        <p className="text-xs text-gray-400">
                          {t("tripDetail.eta")}{" "}
                          {stop.estimatedArrival.toLocaleTimeString(
                            locale === "ne" ? "ne-NP" : "en-US",
                            { hour: "2-digit", minute: "2-digit" },
                          )}
                        </p>
                      )}
                    </div>

                    {/* Complete button */}
                    {isCurrent && trip.status === TripStatus.InTransit && (
                      <Button
                        variant="primary"
                        className="h-8 shrink-0 text-xs"
                        onClick={() => handleCompleteStop(stop.id)}
                        disabled={actionLoading}
                      >
                        {t("tripDetail.markArrived")}
                      </Button>
                    )}

                    {stop.completed && (
                      <span className="shrink-0 text-xs font-medium text-green-600">
                        {t("tripDetail.arrived")}
                      </span>
                    )}
                  </div>
                );
              })}
            </div>
          </Card>
        )}

        {/* Optimize Route button — when orders exist but no stops yet */}
        {!hasStops && matchedOrders.length > 0 && (
          <Card className="mb-6">
            <div className="text-center">
              <p className="mb-3 text-sm text-gray-500">
                {t("tripDetail.optimizeHint")}
              </p>
              <Button
                onClick={handleBuildAndOptimize}
                className="bg-amber-500 hover:bg-amber-600"
                disabled={optimizing}
              >
                {optimizing
                  ? t("tripDetail.optimizing")
                  : t("tripDetail.optimizeRoute")}
              </Button>
            </div>
          </Card>
        )}

        {/* Matched Orders */}
        <Card className="mb-6">
          <h2 className="mb-4 text-lg font-semibold">
            {t("tripDetail.matchedOrders")}
          </h2>
          {matchedOrders.length === 0 ? (
            <p className="text-sm text-gray-500">
              {t("tripDetail.noMatchedOrders")}
            </p>
          ) : (
            <div className="space-y-3">
              {matchedOrders.map((order) => (
                <MatchedOrderCard
                  key={order.id}
                  order={order}
                  locale={locale}
                  onAction={async (action, farmerId) => {
                    setActionLoading(true);
                    setError(null);
                    let result;
                    if (action === "pickup" && farmerId) {
                      result = await confirmFarmerPickup(order.id, farmerId);
                    } else if (action === "pickup") {
                      result = await confirmPickup(order.id);
                    } else if (action === "unavailable" && farmerId) {
                      result = await markItemsUnavailable(order.id, farmerId);
                    } else if (action === "deliver") {
                      result = await startDelivery(order.id);
                    }
                    if (result?.error) {
                      setError(result.error);
                    } else {
                      await loadOrders();
                    }
                    setActionLoading(false);
                  }}
                  disabled={actionLoading}
                />
              ))}
            </div>
          )}
        </Card>

        {/* Action Buttons */}
        <div className="flex gap-3">
          {trip.status === TripStatus.Scheduled && (
            <>
              <Button
                onClick={() =>
                  router.push(`/${locale}/rider/trips/${trip.id}/edit`)
                }
                variant="outline"
                className="flex-1"
                disabled={actionLoading}
              >
                {t("tripDetail.edit")}
              </Button>
              <Button
                onClick={handleStart}
                className="flex-1"
                disabled={actionLoading}
              >
                {actionLoading
                  ? t("tripDetail.starting")
                  : t("tripDetail.startTrip")}
              </Button>
              <Button
                onClick={handleCancel}
                variant="outline"
                className="flex-1 border-red-300 text-red-600 hover:bg-red-50 hover:text-red-700"
                disabled={actionLoading}
              >
                {t("tripDetail.cancel")}
              </Button>
            </>
          )}
          {trip.status === TripStatus.InTransit && (
            <Button
              onClick={handleComplete}
              className="w-full bg-secondary hover:bg-green-600"
              disabled={actionLoading}
            >
              {actionLoading
                ? t("tripDetail.completing")
                : t("tripDetail.completeTrip")}
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}

function MatchedOrderCard({
  order,
  locale,
  onAction,
  disabled,
}: {
  order: OrderWithDetails;
  locale: string;
  onAction: (
    action: "pickup" | "deliver" | "unavailable",
    farmerId?: string,
  ) => Promise<void>;
  disabled: boolean;
}) {
  const t = useTranslations("rider");
  const totalKg = order.items.reduce((sum, i) => sum + i.quantity_kg, 0);

  // Group items by farmer for multi-farmer display
  const farmerGroups = new Map<string, OrderItemWithDetails[]>();
  for (const item of order.items) {
    const fid = item.farmer?.id ?? item.farmer_id;
    const group = farmerGroups.get(fid) ?? [];
    group.push(item);
    farmerGroups.set(fid, group);
  }
  const sortedGroups = [...farmerGroups.entries()].sort(
    (a, b) =>
      (a[1][0].pickup_sequence ?? 0) - (b[1][0].pickup_sequence ?? 0),
  );
  const isMultiFarmer = sortedGroups.length > 1;

  return (
    <div className="rounded-md border border-gray-200 p-3">
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-foreground">
            {totalKg} kg &middot; NPR {Number(order.total_price).toFixed(0)}
          </p>
          <p className="mt-1 truncate text-xs text-gray-500">
            {order.delivery_address}
          </p>
        </div>
        <OrderStatusBadge status={order.status as OrderStatus} />
      </div>

      {/* Per-farmer pickup sections */}
      {order.status === "matched" && isMultiFarmer ? (
        <div className="mt-3 space-y-3">
          {sortedGroups.map(([farmerId, items], idx) => {
            const farmerName = items[0].farmer?.name ?? "Unknown";
            const pickupStatus = items[0].pickup_status;
            const groupKg = items.reduce((s, i) => s + i.quantity_kg, 0);
            const itemNames = items
              .map((i) =>
                locale === "ne" ? i.listing?.name_ne : i.listing?.name_en,
              )
              .filter(Boolean)
              .join(", ");
            const isPending =
              pickupStatus === OrderItemStatus.PendingPickup;
            const isPickedUp = pickupStatus === OrderItemStatus.PickedUp;
            const isUnavailable =
              pickupStatus === OrderItemStatus.Unavailable;

            return (
              <div
                key={farmerId}
                className={`rounded-md border p-2 ${
                  isPickedUp
                    ? "border-green-200 bg-green-50"
                    : isUnavailable
                      ? "border-red-200 bg-red-50 opacity-60"
                      : "border-amber-200 bg-amber-50"
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-xs font-bold text-primary">
                      {idx + 1}
                    </span>
                    <span className="text-xs font-semibold text-gray-700">
                      {farmerName}
                    </span>
                  </div>
                  <span
                    className={`text-[10px] font-medium ${
                      isPickedUp
                        ? "text-green-700"
                        : isUnavailable
                          ? "text-red-700"
                          : "text-amber-700"
                    }`}
                  >
                    {isPickedUp
                      ? t("tripDetail.pickedUpStatus")
                      : isUnavailable
                        ? t("tripDetail.unavailableStatus")
                        : t("tripDetail.pendingPickup")}
                  </span>
                </div>
                <p className="mt-1 truncate text-xs text-gray-500">
                  {itemNames} &middot; {groupKg} kg
                </p>
                {isPending && (
                  <div className="mt-2 flex gap-2">
                    <Button
                      variant="primary"
                      className="h-8 flex-1 text-xs"
                      onClick={() => onAction("pickup", farmerId)}
                      disabled={disabled}
                    >
                      {t("tripDetail.confirmPickup")}
                    </Button>
                    <Button
                      variant="outline"
                      className="h-8 text-xs border-red-300 text-red-600 hover:bg-red-50"
                      onClick={() => onAction("unavailable", farmerId)}
                      disabled={disabled}
                    >
                      {t("tripDetail.markUnavailable")}
                    </Button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      ) : order.status === "matched" ? (
        <div className="mt-3">
          <p className="mb-2 truncate text-xs text-gray-500">
            {order.items
              .map((i) =>
                locale === "ne" ? i.listing?.name_ne : i.listing?.name_en,
              )
              .filter(Boolean)
              .join(", ")}
          </p>
          <Button
            variant="primary"
            className="h-9 w-full text-xs"
            onClick={() => onAction("pickup", sortedGroups[0]?.[0])}
            disabled={disabled}
          >
            {t("tripDetail.confirmPickup")}
          </Button>
        </div>
      ) : null}

      {/* Start delivery button when all pickups complete */}
      {order.status === "picked_up" && (
        <div className="mt-3">
          {isMultiFarmer && (
            <p className="mb-2 text-xs font-medium text-green-600">
              {t("tripDetail.allPickupsComplete")}
            </p>
          )}
          <Button
            variant="primary"
            className="h-9 w-full text-xs"
            onClick={() => onAction("deliver")}
            disabled={disabled}
          >
            {t("tripDetail.startDelivery")}
          </Button>
        </div>
      )}
    </div>
  );
}
