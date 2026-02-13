"use client";

import { useCallback, useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter, useParams } from "next/navigation";
import dynamic from "next/dynamic";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { Card } from "@/components/ui/Card";
import { createTrip } from "@/lib/actions/trips";
import { fetchRoute } from "@/lib/map";
import type { LatLng } from "@/lib/map";
import type { CreateTripInput } from "@/lib/types/trip";
import { VehicleType } from "@jirisewa/shared";

const LocationPicker = dynamic(
  () => import("@/components/map/LocationPicker"),
  { ssr: false },
);

const TripRouteMap = dynamic(
  () => import("@/components/map/TripRouteMap"),
  { ssr: false },
);

type Step = "origin" | "destination" | "details" | "review";

export default function NewTripPage() {
  const t = useTranslations("rider");
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string;

  const [step, setStep] = useState<Step>("origin");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Form state
  const [origin, setOrigin] = useState<LatLng | null>(null);
  const [originName, setOriginName] = useState("");
  const [destination, setDestination] = useState<LatLng | null>(null);
  const [destinationName, setDestinationName] = useState("");
  const [departureDate, setDepartureDate] = useState("");
  const [departureTime, setDepartureTime] = useState("");
  const [capacityKg, setCapacityKg] = useState("");
  const [vehicleType, setVehicleType] = useState<VehicleType>(VehicleType.Bike);

  // Route state
  const [routeCoords, setRouteCoords] = useState<[number, number][] | null>(
    null,
  );
  const [routeDistance, setRouteDistance] = useState<number | null>(null);
  const [routeDuration, setRouteDuration] = useState<number | null>(null);
  const [loadingRoute, setLoadingRoute] = useState(false);

  const handleOriginSelect = useCallback(
    (location: LatLng, address: string) => {
      setOrigin(location);
      setOriginName(address);
    },
    [],
  );

  const handleDestinationSelect = useCallback(
    (location: LatLng, address: string) => {
      setDestination(location);
      setDestinationName(address);
    },
    [],
  );

  const calculateRoute = useCallback(async () => {
    if (!origin || !destination) return;

    setLoadingRoute(true);
    setError(null);

    const result = await fetchRoute(origin, destination);

    if (result) {
      setRouteCoords(
        result.coordinates.map(([lng, lat]) => [lat, lng] as [number, number]),
      );
      setRouteDistance(result.distanceMeters);
      setRouteDuration(result.durationSeconds);
    } else {
      setError(t("tripForm.routeError"));
    }

    setLoadingRoute(false);
  }, [origin, destination, t]);

  const goToDestination = useCallback(async () => {
    setStep("destination");
  }, []);

  const goToDetails = useCallback(async () => {
    await calculateRoute();
    setStep("details");
  }, [calculateRoute]);

  const goToReview = useCallback(() => {
    if (!departureDate || !departureTime || !capacityKg) {
      setError(t("tripForm.fillAllFields"));
      return;
    }

    const capacity = parseFloat(capacityKg);
    if (isNaN(capacity) || capacity <= 0) {
      setError(t("tripForm.invalidCapacity"));
      return;
    }

    setError(null);
    setStep("review");
  }, [departureDate, departureTime, capacityKg, t]);

  const handleSubmit = useCallback(async () => {
    if (!origin || !destination || !departureDate || !departureTime) return;

    setSubmitting(true);
    setError(null);

    const departureAt = new Date(
      `${departureDate}T${departureTime}`,
    ).toISOString();

    const input: CreateTripInput = {
      origin,
      originName,
      destination,
      destinationName,
      routeGeoJson: routeCoords
        ? routeCoords.map(([lat, lng]) => [lng, lat] as [number, number])
        : null,
      departureAt,
      availableCapacityKg: parseFloat(capacityKg),
    };

    const result = await createTrip(input);

    if (result.error) {
      setError(result.error);
      setSubmitting(false);
      return;
    }

    router.push(`/${locale}/rider/dashboard`);
  }, [
    origin,
    destination,
    originName,
    destinationName,
    departureDate,
    departureTime,
    capacityKg,
    routeCoords,
    router,
    locale,
  ]);

  const formatDistance = (meters: number) => {
    if (meters >= 1000) {
      return `${(meters / 1000).toFixed(1)} km`;
    }
    return `${Math.round(meters)} m`;
  };

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h ${mins}m`;
    }
    return `${mins}m`;
  };

  return (
    <div className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        <h1 className="mb-6 text-2xl font-bold text-foreground">
          {t("tripForm.title")}
        </h1>

        {/* Step indicator */}
        <div className="mb-8 flex gap-2">
          {(["origin", "destination", "details", "review"] as Step[]).map(
            (s, i) => (
              <div
                key={s}
                className={`h-1.5 flex-1 rounded-full transition-colors ${
                  (["origin", "destination", "details", "review"] as Step[]).indexOf(step) >= i
                    ? "bg-primary"
                    : "bg-border"
                }`}
              />
            ),
          )}
        </div>

        {error && (
          <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Step 1: Origin */}
        {step === "origin" && (
          <Card className="space-y-4">
            <h2 className="text-lg font-semibold">{t("tripForm.pickOrigin")}</h2>
            <p className="text-sm text-gray-500">
              {t("tripForm.pickOriginHint")}
            </p>
            <div className="h-80 overflow-hidden rounded-md border-2 border-border">
              <LocationPicker
                value={origin}
                onChange={handleOriginSelect}
                className="h-full"
              />
            </div>
            {originName && (
              <p className="truncate text-sm text-gray-600">{originName}</p>
            )}
            <Button
              onClick={goToDestination}
              disabled={!origin}
              className="w-full"
            >
              {t("tripForm.next")}
            </Button>
          </Card>
        )}

        {/* Step 2: Destination */}
        {step === "destination" && (
          <Card className="space-y-4">
            <h2 className="text-lg font-semibold">
              {t("tripForm.pickDestination")}
            </h2>
            <p className="text-sm text-gray-500">
              {t("tripForm.pickDestinationHint")}
            </p>
            <div className="h-80 overflow-hidden rounded-md border-2 border-border">
              <LocationPicker
                value={destination}
                onChange={handleDestinationSelect}
                className="h-full"
              />
            </div>
            {destinationName && (
              <p className="truncate text-sm text-gray-600">
                {destinationName}
              </p>
            )}
            <div className="flex gap-3">
              <Button
                variant="outline"
                onClick={() => setStep("origin")}
                className="flex-1"
              >
                {t("tripForm.back")}
              </Button>
              <Button
                onClick={goToDetails}
                disabled={!destination || loadingRoute}
                className="flex-1"
              >
                {loadingRoute ? t("tripForm.calculatingRoute") : t("tripForm.next")}
              </Button>
            </div>
          </Card>
        )}

        {/* Step 3: Trip Details */}
        {step === "details" && (
          <Card className="space-y-4">
            <h2 className="text-lg font-semibold">
              {t("tripForm.tripDetails")}
            </h2>

            {/* Route preview */}
            {origin && destination && (
              <div className="h-48 overflow-hidden rounded-md border-2 border-border">
                <TripRouteMap
                  origin={origin}
                  destination={destination}
                  originName={originName}
                  destinationName={destinationName}
                  routeCoordinates={routeCoords ?? undefined}
                  className="h-full"
                />
              </div>
            )}

            {routeDistance !== null && routeDuration !== null && (
              <div className="flex gap-4 text-sm text-gray-600">
                <span>
                  {t("tripForm.distance")}: {formatDistance(routeDistance)}
                </span>
                <span>
                  {t("tripForm.duration")}: {formatDuration(routeDuration)}
                </span>
              </div>
            )}

            <div className="space-y-3">
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-foreground">
                  {t("tripForm.departureDate")}
                </span>
                <Input
                  type="date"
                  value={departureDate}
                  onChange={(e) => setDepartureDate(e.target.value)}
                  min={new Date().toISOString().split("T")[0]}
                />
              </label>

              <label className="block">
                <span className="mb-1 block text-sm font-medium text-foreground">
                  {t("tripForm.departureTime")}
                </span>
                <Input
                  type="time"
                  value={departureTime}
                  onChange={(e) => setDepartureTime(e.target.value)}
                />
              </label>

              <label className="block">
                <span className="mb-1 block text-sm font-medium text-foreground">
                  {t("tripForm.capacity")}
                </span>
                <Input
                  type="number"
                  value={capacityKg}
                  onChange={(e) => setCapacityKg(e.target.value)}
                  placeholder="e.g. 50"
                  min="1"
                  step="0.5"
                />
              </label>

              <label className="block">
                <span className="mb-1 block text-sm font-medium text-foreground">
                  {t("tripForm.vehicleType")}
                </span>
                <select
                  value={vehicleType}
                  onChange={(e) =>
                    setVehicleType(e.target.value as VehicleType)
                  }
                  className="w-full rounded-md border-2 border-transparent bg-gray-100 px-4 h-14 transition-all duration-200 focus:border-primary focus:bg-white focus:outline-none"
                >
                  {Object.values(VehicleType).map((vt) => (
                    <option key={vt} value={vt}>
                      {t(`vehicleTypes.${vt}`)}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <div className="flex gap-3">
              <Button
                variant="outline"
                onClick={() => setStep("destination")}
                className="flex-1"
              >
                {t("tripForm.back")}
              </Button>
              <Button onClick={goToReview} className="flex-1">
                {t("tripForm.review")}
              </Button>
            </div>
          </Card>
        )}

        {/* Step 4: Review */}
        {step === "review" && origin && destination && (
          <Card className="space-y-4">
            <h2 className="text-lg font-semibold">
              {t("tripForm.reviewTitle")}
            </h2>

            <div className="h-48 overflow-hidden rounded-md border-2 border-border">
              <TripRouteMap
                origin={origin}
                destination={destination}
                originName={originName}
                destinationName={destinationName}
                routeCoordinates={routeCoords ?? undefined}
                className="h-full"
              />
            </div>

            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripForm.from")}</dt>
                <dd className="max-w-[60%] truncate text-right font-medium">
                  {originName || `${origin.lat.toFixed(4)}, ${origin.lng.toFixed(4)}`}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripForm.to")}</dt>
                <dd className="max-w-[60%] truncate text-right font-medium">
                  {destinationName || `${destination.lat.toFixed(4)}, ${destination.lng.toFixed(4)}`}
                </dd>
              </div>
              {routeDistance !== null && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">{t("tripForm.distance")}</dt>
                  <dd className="font-medium">{formatDistance(routeDistance)}</dd>
                </div>
              )}
              {routeDuration !== null && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">{t("tripForm.duration")}</dt>
                  <dd className="font-medium">
                    {formatDuration(routeDuration)}
                  </dd>
                </div>
              )}
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripForm.departure")}</dt>
                <dd className="font-medium">
                  {departureDate} {departureTime}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripForm.capacity")}</dt>
                <dd className="font-medium">{capacityKg} kg</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">{t("tripForm.vehicleType")}</dt>
                <dd className="font-medium">{t(`vehicleTypes.${vehicleType}`)}</dd>
              </div>
            </dl>

            <div className="flex gap-3">
              <Button
                variant="outline"
                onClick={() => setStep("details")}
                className="flex-1"
                disabled={submitting}
              >
                {t("tripForm.back")}
              </Button>
              <Button
                onClick={handleSubmit}
                disabled={submitting}
                className="flex-1"
              >
                {submitting ? t("tripForm.posting") : t("tripForm.postTrip")}
              </Button>
            </div>
          </Card>
        )}
      </div>
    </div>
  );
}
