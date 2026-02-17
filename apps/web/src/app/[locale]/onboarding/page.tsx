"use client";

import { useState, useEffect } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { useAuth } from "@/components/AuthProvider";
import { createClient } from "@/lib/supabase/client";
import { Card } from "@/components/ui";
import {
  Sprout,
  Package,
  User,
  ArrowRight,
  Check,
} from "lucide-react";

type UserRole = "customer" | "farmer" | "rider";

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
  const { user } = useAuth();
  const supabase = createClient();

  const [selectedRole, setSelectedRole] = useState<UserRole | null>(null);
  const [loading, setLoading] = useState(false);
  const [checkingProfile, setCheckingProfile] = useState(true);

  useEffect(() => {
    // Check if user already has a profile with completed onboarding
    const checkProfile = async () => {
      if (!user) {
        router.replace("/auth/login");
        return;
      }

      const { data: profile } = await supabase
        .from("user_profiles")
        .select("onboarding_completed, role")
        .eq("id", user.id)
        .single();

      setCheckingProfile(false);

      if (profile?.onboarding_completed) {
        // Redirect to the appropriate dashboard
        const dashboardMap: Record<string, string> = {
          farmer: "/farmer/dashboard",
          rider: "/rider/dashboard",
          customer: "/customer",
        };
        router.replace(dashboardMap[profile.role] || "/customer");
      }
    };

    checkProfile();
  }, [user, router, supabase]);

  const handleContinue = async () => {
    if (!selectedRole || !user) return;

    setLoading(true);

    const { error } = await supabase
      .from("user_profiles")
      .update({ role: selectedRole, onboarding_completed: true })
      .eq("id", user.id);

    if (error) {
      console.error("Error updating profile:", error);
      setLoading(false);
      return;
    }

    // Redirect to appropriate dashboard
    const dashboardMap: Record<UserRole, string> = {
      farmer: "/farmer/dashboard",
      rider: "/rider/dashboard",
      customer: "/customer",
    };

    router.replace(dashboardMap[selectedRole]);
  };

  if (checkingProfile) {
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

        {/* Continue Button */}
        <div className="mt-10 flex justify-center">
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
