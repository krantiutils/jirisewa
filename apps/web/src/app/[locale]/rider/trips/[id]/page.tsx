"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { TripStatus } from "@jirisewa/shared";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { TripStatusBadge } from "@/components/rider/TripStatusBadge";
import {
  getTrip,
  startTrip,
  completeTrip,
  cancelTrip,
} from "@/lib/actions/trips";
import type { Trip } from "@/lib/types/trip";

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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    async function load() {
      setLoading(true);
      const result = await getTrip(tripId);

      if (result.error) {
        setError(result.error);
      } else if (result.data) {
        setTrip(result.data);
      }

      setLoading(false);
    }

    load();
  }, [tripId]);

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

        {/* Matched Orders — placeholder */}
        <Card className="mb-6">
          <h2 className="mb-4 text-lg font-semibold">
            {t("tripDetail.matchedOrders")}
          </h2>
          <p className="text-sm text-gray-500">
            {t("tripDetail.noMatchedOrders")}
          </p>
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
