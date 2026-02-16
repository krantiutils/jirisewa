"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useParams, useRouter } from "next/navigation";
import { TripStatus } from "@jirisewa/shared";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { TripStatusBadge } from "@/components/rider/TripStatusBadge";
import { PingNotificationPanel } from "@/components/rider/PingNotificationPanel";
import { listTrips } from "@/lib/actions/trips";
import { usePingSubscription } from "@/lib/hooks/usePingSubscription";
import type { Trip } from "@/lib/types/trip";

type TabKey = "upcoming" | "active" | "completed";

const TAB_STATUS_MAP: Record<TabKey, TripStatus | undefined> = {
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
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string;

  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authChecked, setAuthChecked] = useState(false);
  const [activeTab, setActiveTab] = useState<TabKey>("upcoming");
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { pings, removePing } = usePingSubscription();

  // Check auth first
  useEffect(() => {
    async function checkAuth() {
      try {
        const res = await fetch("/api/auth/session");
        if (!res.ok || !(await res.json()).user) {
          router.replace(`/${locale}/auth/login`);
          return;
        }
        setIsAuthenticated(true);
      } catch {
        router.replace(`/${locale}/auth/login`);
        return;
      } finally {
        setAuthChecked(true);
      }
    }
    checkAuth();
  }, [locale, router]);

  useEffect(() => {
    if (!authChecked || !isAuthenticated) return;

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
        // For "completed" tab, show both completed and cancelled
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
  }, [activeTab]);

  const tabs: { key: TabKey; label: string }[] = [
    { key: "upcoming", label: t("dashboard.upcoming") },
    { key: "active", label: t("dashboard.active") },
    { key: "completed", label: t("dashboard.completed") },
  ];

  // Don't render until auth is checked
  if (!authChecked) {
    return null;
  }

  // Show loading state while checking auth
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
          <Button
            onClick={() => router.push(`/${locale}/rider/trips/new`)}
          >
            {t("dashboard.postTrip")}
          </Button>
        </div>

        {/* Tabs */}
        <div className="mb-6 flex gap-1 rounded-lg bg-white p-1">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex-1 rounded-md px-4 py-2.5 text-sm font-medium transition-colors ${
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

        {/* Trip List */}
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
      </div>
    </div>
  );
}
