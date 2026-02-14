"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { TripStatus } from "@jirisewa/shared";
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
  startDelivery,
} from "@/lib/actions/orders";
import { usePingSubscription } from "@/lib/hooks/usePingSubscription";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import type { Trip } from "@/lib/types/trip";
import type { OrderWithDetails, OrderStatus } from "@/lib/types/order";

const TripRouteMap = dynamic(
  () => import("@/components/map/TripRouteMap"),
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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const { pings, removePing } = usePingSubscription();

  const loadOrders = useCallback(async () => {
    const result = await listOrdersByTrip(tripId);
    if (result.data) {
      setMatchedOrders(result.data);
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

      await loadOrders();
      setLoading(false);
    }

    load();
  }, [tripId, loadOrders]);

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

        {/* Route Map */}
        <Card className="mb-6 p-0 overflow-hidden">
          <div className="h-64">
            <TripRouteMap
              origin={trip.origin}
              destination={trip.destination}
              originName={trip.originName}
              destinationName={trip.destinationName}
              routeCoordinates={trip.routeCoordinates ?? undefined}
              className="h-full"
            />
          </div>
        </Card>

        {/* Ping notifications — shown when trip is in_transit */}
        {trip.status === TripStatus.InTransit && pings.length > 0 && (
          <PingNotificationPanel
            pings={pings}
            onPingRemoved={removePing}
            onAccepted={async () => {
              // Reload trip data and matched orders after accepting a ping
              const tripResult = await getTrip(tripId);
              if (tripResult.data) setTrip(tripResult.data);
              await loadOrders();
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
          </dl>
        </Card>

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
                  onAction={async (action) => {
                    setActionLoading(true);
                    setError(null);
                    let result;
                    if (action === "pickup") {
                      result = await confirmPickup(order.id);
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
  onAction: (action: "pickup" | "deliver") => Promise<void>;
  disabled: boolean;
}) {
  const t = useTranslations("rider");
  const totalKg = order.items.reduce((sum, i) => sum + i.quantity_kg, 0);
  const itemNames = order.items
    .map((i) =>
      locale === "ne" ? i.listing?.name_ne : i.listing?.name_en,
    )
    .filter(Boolean)
    .join(", ");

  return (
    <div className="rounded-md border border-gray-200 p-3">
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-foreground">
            {itemNames}
          </p>
          <p className="text-xs text-gray-500">
            {totalKg} kg &middot; NPR {Number(order.total_price).toFixed(0)}
          </p>
          <p className="mt-1 text-xs text-gray-500 truncate">
            {order.delivery_address}
          </p>
        </div>
        <OrderStatusBadge status={order.status as OrderStatus} />
      </div>

      <div className="mt-3 flex gap-2">
        {order.status === "matched" && (
          <Button
            variant="primary"
            className="h-9 flex-1 text-xs"
            onClick={() => onAction("pickup")}
            disabled={disabled}
          >
            {t("tripDetail.confirmPickup")}
          </Button>
        )}
        {order.status === "picked_up" && (
          <Button
            variant="primary"
            className="h-9 flex-1 text-xs"
            onClick={() => onAction("deliver")}
            disabled={disabled}
          >
            {t("tripDetail.startDelivery")}
          </Button>
        )}
      </div>
    </div>
  );
}
