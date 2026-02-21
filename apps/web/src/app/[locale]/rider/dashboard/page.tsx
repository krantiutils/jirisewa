"use client";

import { useEffect, useState, useCallback } from "react";
import { useTranslations } from "next-intl";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { TripStatus } from "@jirisewa/shared";
import { DollarSign } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { TripStatusBadge } from "@/components/rider/TripStatusBadge";
import { PingNotificationPanel } from "@/components/rider/PingNotificationPanel";
import { listTrips } from "@/lib/actions/trips";
import { getAvailableOrders, acceptOrderDirect } from "@/lib/actions/available-orders";
import { usePingSubscription } from "@/lib/hooks/usePingSubscription";
import { useAuth } from "@/components/AuthProvider";
import type { Trip } from "@/lib/types/trip";
import type { AvailableOrder } from "@/lib/actions/available-orders";

/** Parse EWKB hex point (from PostGIS geography) into lat/lng */
function parseEwkbPoint(hex: string | null | undefined): { lat: number; lng: number } | null {
  if (!hex || hex.length < 50) return null;
  const bytes = new Uint8Array(hex.match(/.{2}/g)!.map(b => parseInt(b, 16)));
  const view = new DataView(bytes.buffer);
  const lng = view.getFloat64(9, true);
  const lat = view.getFloat64(17, true);
  return { lat, lng };
}

const AvailableOrdersMap = dynamic(
  () =>
    import("@/components/rider/AvailableOrdersMap").then(
      (mod) => mod.AvailableOrdersMap,
    ),
  { ssr: false },
);

type TabKey = "browse" | "upcoming" | "active" | "completed";

const TAB_STATUS_MAP: Record<TabKey, TripStatus | undefined> = {
  browse: undefined,
  upcoming: TripStatus.Scheduled,
  active: TripStatus.InTransit,
  completed: undefined, // shows completed + cancelled
};

function TripCard({ trip, locale }: { trip: Trip; locale: string }) {
  const t = useTranslations("rider");
  const router = useRouter();

  const departureStr = trip.departureAt.toLocaleDateString(
    locale === "ne" ? "ne-NP" : "en-US",
    { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" },
  );

  return (
    <Card
      onClick={() => router.push(`/${locale}/rider/trips/${trip.id}`)}
      className="border-2 border-border"
    >
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold text-foreground">
            {trip.originName || t("dashboard.unknownLocation")}
          </p>
          <p className="text-sm text-gray-400">&darr;</p>
          <p className="truncate font-semibold text-foreground">
            {trip.destinationName || t("dashboard.unknownLocation")}
          </p>
        </div>
        <TripStatusBadge status={trip.status} />
      </div>
      <div className="mt-3 flex gap-4 text-xs text-gray-500">
        <span>{departureStr}</span>
        <span>
          {trip.remainingCapacityKg}/{trip.availableCapacityKg} kg
        </span>
      </div>
    </Card>
  );
}

export default function RiderDashboard() {
  const t = useTranslations("rider");
  const tEarnings = useTranslations("earnings");
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string;
  const { user, profile, loading: authLoading } = useAuth();

  const [activeTab, setActiveTab] = useState<TabKey>("browse");
  const [trips, setTrips] = useState<Trip[]>([]);
  const [availableOrders, setAvailableOrders] = useState<AvailableOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [accepting, setAccepting] = useState<string | null>(null);
  const { pings, removePing } = usePingSubscription();

  const isAuthenticated = !!user;
  const authChecked = !authLoading;

  // Redirect if not authenticated
  useEffect(() => {
    if (authChecked && !isAuthenticated) {
      router.replace(`/${locale}/auth/login`);
    }
  }, [authChecked, isAuthenticated, locale, router]);

  // Load available orders for browse tab
  useEffect(() => {
    if (!authChecked || !isAuthenticated || activeTab !== "browse") return;

    async function loadOrders() {
      setLoading(true);
      setError(null);
      const result = await getAvailableOrders();
      if (result.error) {
        setError(result.error);
        setAvailableOrders([]);
      } else {
        setAvailableOrders(result.data ?? []);
      }
      setLoading(false);
    }

    loadOrders();
  }, [activeTab, authChecked, isAuthenticated]);

  // Load trips for other tabs
  useEffect(() => {
    if (!authChecked || !isAuthenticated || activeTab === "browse") return;

    async function load() {
      setLoading(true);
      setError(null);

      const statusFilter = TAB_STATUS_MAP[activeTab];
      const result = await listTrips(statusFilter);

      if (result.error) {
        setError(result.error);
        setTrips([]);
      } else if (result.data) {
        let filtered = result.data;
        if (activeTab === "completed" && result.data) {
          filtered = result.data.filter(
            (trip) =>
              trip.status === TripStatus.Completed ||
              trip.status === TripStatus.Cancelled,
          );
        }
        setTrips(filtered);
      }

      setLoading(false);
    }

    load();
  }, [activeTab, authChecked, isAuthenticated]);

  const handleAcceptOrder = useCallback(
    async (orderId: string) => {
      setAccepting(orderId);
      // Use rider's profile route or defaults
      const origin = profile?.fixed_route_origin_name
        ? { lat: 0, lng: 0, name: profile.fixed_route_origin_name }
        : { lat: 27.7172, lng: 85.3240, name: "Kathmandu" };
      const dest = profile?.fixed_route_destination_name
        ? { lat: 0, lng: 0, name: profile.fixed_route_destination_name }
        : { lat: 27.6, lng: 85.5, name: "Delivery" };

      const vehicleType = profile?.vehicle_type || "bike";

      const result = await acceptOrderDirect(orderId, origin, dest, vehicleType, 50);
      setAccepting(null);

      if (result.error) {
        setError(result.error);
      } else {
        // Remove from list and switch to upcoming
        setAvailableOrders((prev) => prev.filter((o) => o.id !== orderId));
        if (result.data?.tripId) {
          router.push(`/${locale}/rider/trips/${result.data.tripId}`);
        }
      }
    },
    [profile, locale, router],
  );

  const tabs: { key: TabKey; label: string }[] = [
    { key: "browse", label: t("dashboard.browseOrders") },
    { key: "upcoming", label: t("dashboard.upcoming") },
    { key: "active", label: t("dashboard.active") },
    { key: "completed", label: t("dashboard.completed") },
  ];

  // Don't render until auth is checked
  if (!authChecked) {
    return null;
  }

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-muted flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-500">Please log in to access rider dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-foreground">
            {t("dashboard.title")}
          </h1>
          <div className="flex items-center gap-3">
            <button
              onClick={() => router.push(`/${locale}/rider/earnings`)}
              className="inline-flex items-center gap-2 rounded-md border border-amber-200 bg-amber-50 px-4 h-14 font-semibold text-amber-700 transition-all duration-200 hover:bg-amber-100 hover:scale-105"
            >
              <DollarSign className="h-5 w-5" />
              {tEarnings("title")}
            </button>
            <Button
              onClick={() => router.push(`/${locale}/rider/trips/new`)}
            >
              {t("dashboard.postTrip")}
            </Button>
          </div>
        </div>

        {/* Tabs */}
        <div className="mb-6 flex gap-1 rounded-lg bg-white p-1 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex-1 whitespace-nowrap rounded-md px-3 py-2.5 text-sm font-medium transition-colors ${
                activeTab === tab.key
                  ? "bg-primary text-white"
                  : "text-gray-600 hover:bg-gray-100"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {error && (
          <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Farmer beacon opportunities — shown after route selection and while active */}
        {(activeTab === "upcoming" || activeTab === "active") &&
          pings.length > 0 && (
          <PingNotificationPanel
            pings={pings}
            onPingRemoved={removePing}
          />
          )}

        {/* Browse Orders — map view */}
        {activeTab === "browse" && (
          <>
            {loading ? (
              <div className="py-12 text-center text-gray-500">
                {t("loading")}
              </div>
            ) : availableOrders.length === 0 ? (
              <div className="py-12 text-center">
                <p className="text-gray-500">{t("dashboard.noAvailableOrders")}</p>
              </div>
            ) : (
              <AvailableOrdersMap
                orders={availableOrders}
                onAccept={handleAcceptOrder}
                accepting={accepting}
                fixedRoute={(() => {
                  const o = parseEwkbPoint(profile?.fixed_route_origin);
                  const d = parseEwkbPoint(profile?.fixed_route_destination);
                  if (o && d && profile?.fixed_route_origin_name && profile?.fixed_route_destination_name) {
                    return {
                      originLat: o.lat, originLng: o.lng,
                      originName: profile.fixed_route_origin_name,
                      destLat: d.lat, destLng: d.lng,
                      destName: profile.fixed_route_destination_name,
                    };
                  }
                  return null;
                })()}
              />
            )}
          </>
        )}

        {/* Trip List for other tabs */}
        {activeTab !== "browse" && (
          <>
            {loading ? (
              <div className="py-12 text-center text-gray-500">
                {t("loading")}
              </div>
            ) : trips.length === 0 ? (
              <div className="py-12 text-center">
                <p className="text-gray-500">{t("dashboard.noTrips")}</p>
                {activeTab === "upcoming" && (
                  <Button
                    variant="outline"
                    className="mt-4"
                    onClick={() => router.push(`/${locale}/rider/trips/new`)}
                  >
                    {t("dashboard.postFirstTrip")}
                  </Button>
                )}
              </div>
            ) : (
              <div className="space-y-3">
                {trips.map((trip) => (
                  <TripCard key={trip.id} trip={trip} locale={locale} />
                ))}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
