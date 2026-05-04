"use client";

import { useState, useEffect } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { useAuth } from "@/components/AuthProvider";
import { completeOnboarding } from "@/lib/actions/onboarding";
import { Card } from "@/components/ui";
import {
  Sprout,
  Package,
  User,
  ArrowRight,
  Check,
  Bike,
  Car,
  Truck,
  Bus,
  CircleHelp,
} from "lucide-react";
import { LocationSearchInput } from "@/components/map/LocationSearchInput";

type UserRole = "customer" | "farmer" | "rider";
type VehicleType = "bike" | "car" | "truck" | "bus" | "other";

const VEHICLE_ICONS: Record<VehicleType, typeof Bike> = {
  bike: Bike,
  car: Car,
  truck: Truck,
  bus: Bus,
  other: CircleHelp,
};
const VEHICLE_TYPES: VehicleType[] = ["bike", "car", "truck", "bus", "other"];
const FIXED_ROUTE_VEHICLES: VehicleType[] = ["bus", "truck"];

const ROLE_CONFIG: Record<
  UserRole,
  {
    icon: typeof Sprout;
    titleKey: string;
    descKey: string;
    color: string;
    features: string[];
  }
> = {
  farmer: {
    icon: Sprout,
    titleKey: "farmerTitle",
    descKey: "farmerDesc",
    color: "bg-emerald-500",
    features: ["listings", "analytics", "subscriptions"],
  },
  rider: {
    icon: Package,
    titleKey: "riderTitle",
    descKey: "riderDesc",
    color: "bg-amber-500",
    features: ["navigation", "earnings", "flexible"],
  },
  customer: {
    icon: User,
    titleKey: "customerTitle",
    descKey: "customerDesc",
    color: "bg-blue-500",
    features: ["browse", "delivery", "track"],
  },
};

export default function OnboardingPage() {
  const t = useTranslations("onboarding");
  const router = useRouter();
  const { user, profile, loading: authLoading, refreshProfile } = useAuth();

  const [selectedRole, setSelectedRole] = useState<UserRole | null>(null);
  const [fullName, setFullName] = useState("");
  const [loading, setLoading] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Rider-specific state
  const [vehicleType, setVehicleType] = useState<VehicleType | null>(null);
  const [fixedRouteOrigin, setFixedRouteOrigin] = useState<{ lat: number; lng: number; name: string } | null>(null);
  const [fixedRouteDest, setFixedRouteDest] = useState<{ lat: number; lng: number; name: string } | null>(null);

  useEffect(() => {
    // Wait for auth to settle before checking anything
    if (authLoading) return;

    if (!user) {
      router.replace("/auth/login");
      return;
    }

    // If profile exists and onboarding is done, redirect to dashboard
    if (profile?.onboarding_completed) {
      const dashboardMap: Record<string, string> = {
        farmer: "/farmer/dashboard",
        rider: "/rider/dashboard",
        customer: "/customer",
      };
      router.replace(dashboardMap[profile.role || "customer"] || "/customer");
    }
  }, [authLoading, user, profile, router]);

  const handleContinue = async () => {
    if (!selectedRole || !user) return;

    setLoading(true);
    setSubmitError(null);

    const result = await completeOnboarding({
      role: selectedRole,
      fullName: fullName.trim() || undefined,
      vehicleType: selectedRole === "rider" ? (vehicleType ?? undefined) : undefined,
      fixedRouteOrigin:
        selectedRole === "rider" && vehicleType && FIXED_ROUTE_VEHICLES.includes(vehicleType)
          ? fixedRouteOrigin
          : null,
      fixedRouteDest:
        selectedRole === "rider" && vehicleType && FIXED_ROUTE_VEHICLES.includes(vehicleType)
          ? fixedRouteDest
          : null,
    });

    if (result.error) {
      console.error("Onboarding error:", result.error);
      setSubmitError(result.error);
      setLoading(false);
      return;
    }

    // Refresh the AuthProvider profile so downstream pages see the update
    await refreshProfile();
    router.replace(result.data!.dashboard);
  };

  if (authLoading || (!user && !authLoading)) {
    return (
      <div className="flex min-h-[calc(100vh-57px)] items-center justify-center">
        <div className="text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto" />
          <p className="mt-4 text-sm text-gray-500">{t("loading")}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-[calc(100vh-57px)] bg-gradient-to-b from-gray-50 to-white px-4 py-12">
      <div className="mx-auto max-w-4xl">
        {/* Header */}
        <div className="mb-10 text-center">
          <h1 className="text-3xl font-bold text-gray-900 sm:text-4xl">
            {t("heading")}
          </h1>
          <p className="mt-3 text-lg text-gray-600">{t("subheading")}</p>
        </div>

        {/* Name input */}
        <div className="mx-auto mb-8 max-w-md">
          <label
            htmlFor="fullName"
            className="mb-2 block text-sm font-medium text-gray-700"
          >
            {t("nameLabel")}
          </label>
          <input
            id="fullName"
            type="text"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            placeholder={t("namePlaceholder")}
            className="w-full rounded-lg border-2 border-gray-200 px-4 py-3 text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
          />
        </div>

        {/* Role Selection */}
        <div className="grid gap-6 sm:grid-cols-3">
          {(Object.keys(ROLE_CONFIG) as UserRole[]).map((role) => {
            const config = ROLE_CONFIG[role];
            const Icon = config.icon;
            const isSelected = selectedRole === role;

            return (
              <Card
                key={role}
                className={`relative cursor-pointer border-2 transition-all hover:scale-[1.02] ${
                  isSelected
                    ? "border-primary shadow-lg"
                    : "border-gray-200 hover:border-gray-300"
                }`}
                onClick={() => setSelectedRole(role)}
              >
                {isSelected && (
                  <div className="absolute right-3 top-3 flex h-6 w-6 items-center justify-center rounded-full bg-primary">
                    <Check className="h-4 w-4 text-white" />
                  </div>
                )}

                <div className="p-6 text-center">
                  <div
                    className={`mx-flex mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full ${config.color}`}
                  >
                    <Icon className="h-8 w-8 text-white" />
                  </div>

                  <h3 className="text-xl font-semibold text-gray-900">
                    {t(config.titleKey)}
                  </h3>

                  <p className="mt-2 text-sm text-gray-600">
                    {t(config.descKey)}
                  </p>

                  <ul className="mt-4 space-y-2 text-left">
                    {config.features.map((feature) => (
                      <li
                        key={feature}
                        className="flex items-center gap-2 text-sm text-gray-600"
                      >
                        <div className="h-1.5 w-1.5 rounded-full bg-gray-400" />
                        {t(`features.${feature}`)}
                      </li>
                    ))}
                  </ul>
                </div>
              </Card>
            );
          })}
        </div>

        {/* Rider-specific options */}
        {selectedRole === "rider" && (
          <div className="mx-auto mt-8 max-w-md space-y-6">
            {/* Vehicle Type */}
            <div>
              <label className="mb-3 block text-sm font-medium text-gray-700">
                {t("vehicleType")}
              </label>
              <div className="flex flex-wrap gap-2">
                {VEHICLE_TYPES.map((vt) => {
                  const VIcon = VEHICLE_ICONS[vt];
                  const isSelected = vehicleType === vt;
                  return (
                    <button
                      key={vt}
                      type="button"
                      onClick={() => setVehicleType(vt)}
                      className={`flex items-center gap-2 rounded-lg border-2 px-4 py-2.5 text-sm font-medium transition-all ${
                        isSelected
                          ? "border-primary bg-primary/5 text-primary"
                          : "border-gray-200 text-gray-600 hover:border-gray-300"
                      }`}
                    >
                      <VIcon className="h-4 w-4" />
                      {t(`vehicleTypes.${vt}`)}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Fixed Route — shown for bus/truck */}
            {vehicleType && FIXED_ROUTE_VEHICLES.includes(vehicleType) && (
              <div className="rounded-lg border-2 border-gray-200 bg-gray-50 p-4">
                <h4 className="text-sm font-semibold text-gray-900">
                  {t("fixedRouteTitle")}
                </h4>
                <p className="mt-1 text-xs text-gray-500">
                  {t("fixedRouteHint")}
                </p>

                <div className="mt-4 space-y-3">
                  <div>
                    <label className="mb-1 block text-xs font-medium text-gray-600">
                      {t("routeOrigin")}
                    </label>
                    <LocationSearchInput
                      value={fixedRouteOrigin?.name}
                      placeholder={t("routeOriginPlaceholder")}
                      onChange={setFixedRouteOrigin}
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-medium text-gray-600">
                      {t("routeDestination")}
                    </label>
                    <LocationSearchInput
                      value={fixedRouteDest?.name}
                      placeholder={t("routeDestinationPlaceholder")}
                      onChange={setFixedRouteDest}
                    />
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Continue Button */}
        <div className="mt-10 flex flex-col items-center gap-3">
          <button
            onClick={handleContinue}
            disabled={!selectedRole || loading}
            className={`flex items-center gap-2 rounded-full px-8 py-4 font-semibold text-white transition-all ${
              !selectedRole || loading
                ? "cursor-not-allowed bg-gray-300"
                : "bg-primary hover:bg-primary/90 hover:shadow-lg"
            }`}
          >
            {loading ? t("saving") : t("continue")}
            {!loading && <ArrowRight className="h-5 w-5" />}
          </button>
          {submitError && (
            <p className="max-w-md rounded-md bg-red-50 px-4 py-2 text-center text-sm text-red-700">
              {submitError}
            </p>
          )}
        </div>

        {/* Skip Link */}
        <p className="mt-6 text-center text-sm text-gray-500">
          {t("skipPrefix")}{" "}
          <button
            onClick={() => setSelectedRole("customer")}
            className="font-medium text-primary hover:underline"
          >
            {t("skipLink")}
          </button>
        </p>
      </div>
    </div>
  );
}
