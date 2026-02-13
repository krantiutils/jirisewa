"use client";

import { useState, useCallback, useEffect } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { useAuth } from "@/components/AuthProvider";
import { UserRole, VehicleType } from "@jirisewa/shared";
import { createClient } from "@/lib/supabase/client";
import { Button, Input, Card } from "@/components/ui";

const TOTAL_STEPS = 3;

interface FormData {
  name: string;
  lang: "en" | "ne";
  address: string;
  municipality: string;
  roles: UserRole[];
  farmName: string;
  vehicleType: VehicleType;
  vehicleCapacityKg: string;
}

const VEHICLE_TYPES: VehicleType[] = [
  VehicleType.Bike,
  VehicleType.Car,
  VehicleType.Truck,
  VehicleType.Bus,
  VehicleType.Other,
];

export default function RegisterPage() {
  const t = useTranslations("register");
  const router = useRouter();
  const { user, loading: authLoading } = useAuth();
  const supabase = createClient();

  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState<FormData>({
    name: "",
    lang: "ne",
    address: "",
    municipality: "",
    roles: [],
    farmName: "",
    vehicleType: VehicleType.Bike,
    vehicleCapacityKg: "",
  });

  // Redirect if not logged in
  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/auth/login");
    }
  }, [user, authLoading, router]);

  const updateForm = useCallback(
    <K extends keyof FormData>(key: K, value: FormData[K]) => {
      setForm((prev) => ({ ...prev, [key]: value }));
      setError("");
    },
    [],
  );

  const toggleRole = useCallback((role: UserRole) => {
    setForm((prev) => ({
      ...prev,
      roles: prev.roles.includes(role)
        ? prev.roles.filter((r) => r !== role)
        : [...prev.roles, role],
    }));
    setError("");
  }, []);

  const validateStep = useCallback((): boolean => {
    if (step === 1) {
      if (!form.name.trim()) {
        setError(t("nameRequired"));
        return false;
      }
      return true;
    }
    if (step === 2) {
      if (form.roles.length === 0) {
        setError(t("selectRole"));
        return false;
      }
      return true;
    }
    return true;
  }, [step, form, t]);

  const handleNext = useCallback(() => {
    if (!validateStep()) return;
    setStep((s) => Math.min(s + 1, TOTAL_STEPS));
  }, [validateStep]);

  const handleBack = useCallback(() => {
    setStep((s) => Math.max(s - 1, 1));
    setError("");
  }, []);

  const handleComplete = useCallback(async () => {
    if (!validateStep() || !user) return;

    setLoading(true);
    setError("");

    // 1. Upsert user profile
    const { error: userError } = await supabase.from("users").upsert(
      {
        id: user.id,
        phone: user.phone ?? "",
        name: form.name.trim(),
        lang: form.lang,
        address: form.address.trim() || null,
        municipality: form.municipality.trim() || null,
      },
      { onConflict: "id" },
    );

    if (userError) {
      setLoading(false);
      setError(userError.message);
      return;
    }

    // 2. Insert user roles
    const roleInserts = form.roles.map((role) => {
      const base: Record<string, unknown> = {
        user_id: user.id,
        role,
      };
      if (role === UserRole.Farmer && form.farmName.trim()) {
        base.farm_name = form.farmName.trim();
      }
      if (role === UserRole.Rider) {
        base.vehicle_type = form.vehicleType;
        const capacity = parseFloat(form.vehicleCapacityKg);
        base.vehicle_capacity_kg =
          !isNaN(capacity) && capacity > 0 ? capacity : null;
      }
      return base;
    });

    const { error: roleError } = await supabase
      .from("user_roles")
      .upsert(roleInserts, { onConflict: "user_id,role" });

    if (roleError) {
      setLoading(false);
      setError(roleError.message);
      return;
    }

    setLoading(false);
    router.replace("/");
  }, [validateStep, user, supabase, form, router]);

  if (authLoading || !user) {
    return null;
  }

  const hasFarmer = form.roles.includes(UserRole.Farmer);
  const hasRider = form.roles.includes(UserRole.Rider);

  return (
    <div className="flex min-h-[calc(100vh-57px)] flex-col items-center justify-center p-6">
      <Card className="w-full max-w-md cursor-default hover:scale-100">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
          <p className="mt-1 text-sm text-gray-500">{t("subtitle")}</p>
          <p className="mt-2 text-xs font-medium text-primary">
            {t("step", { current: step, total: TOTAL_STEPS })}
          </p>
          {/* Progress bar */}
          <div className="mt-2 h-1 w-full rounded-full bg-gray-100">
            <div
              className="h-1 rounded-full bg-primary transition-all duration-300"
              style={{ width: `${(step / TOTAL_STEPS) * 100}%` }}
            />
          </div>
        </div>

        {/* Step 1: Name + Language */}
        {step === 1 && (
          <div className="space-y-4">
            <div>
              <label
                htmlFor="name"
                className="mb-1.5 block text-sm font-medium text-foreground"
              >
                {t("nameLabel")}
              </label>
              <Input
                id="name"
                placeholder={t("namePlaceholder")}
                value={form.name}
                onChange={(e) => updateForm("name", e.target.value)}
                autoFocus
              />
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-medium text-foreground">
                {t("languageLabel")}
              </label>
              <div className="flex gap-3">
                {(["ne", "en"] as const).map((lang) => (
                  <button
                    key={lang}
                    type="button"
                    onClick={() => updateForm("lang", lang)}
                    className={`flex-1 rounded-md border-2 px-4 py-3 text-sm font-medium transition-all ${
                      form.lang === lang
                        ? "border-primary bg-blue-50 text-primary"
                        : "border-gray-200 text-gray-600 hover:border-gray-300"
                    }`}
                  >
                    {lang === "ne" ? "नेपाली" : "English"}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label
                htmlFor="address"
                className="mb-1.5 block text-sm font-medium text-foreground"
              >
                {t("addressLabel")}
              </label>
              <Input
                id="address"
                placeholder={t("addressPlaceholder")}
                value={form.address}
                onChange={(e) => updateForm("address", e.target.value)}
              />
            </div>

            <div>
              <label
                htmlFor="municipality"
                className="mb-1.5 block text-sm font-medium text-foreground"
              >
                {t("municipalityLabel")}
              </label>
              <Input
                id="municipality"
                placeholder={t("municipalityPlaceholder")}
                value={form.municipality}
                onChange={(e) => updateForm("municipality", e.target.value)}
              />
            </div>
          </div>
        )}

        {/* Step 2: Role selection */}
        {step === 2 && (
          <div className="space-y-4">
            <div>
              <p className="text-lg font-semibold text-foreground">
                {t("roleTitle")}
              </p>
              <p className="text-sm text-gray-500">{t("roleSubtitle")}</p>
            </div>

            {[
              {
                role: UserRole.Farmer,
                label: t("roleFarmer"),
                desc: t("roleFarmerDesc"),
                color: "border-emerald-500 bg-emerald-50 text-emerald-700",
              },
              {
                role: UserRole.Consumer,
                label: t("roleConsumer"),
                desc: t("roleConsumerDesc"),
                color: "border-blue-500 bg-blue-50 text-blue-700",
              },
              {
                role: UserRole.Rider,
                label: t("roleRider"),
                desc: t("roleRiderDesc"),
                color: "border-amber-500 bg-amber-50 text-amber-700",
              },
            ].map(({ role, label, desc, color }) => {
              const selected = form.roles.includes(role);
              return (
                <button
                  key={role}
                  type="button"
                  onClick={() => toggleRole(role)}
                  className={`w-full rounded-lg border-2 p-4 text-left transition-all ${
                    selected ? color : "border-gray-200 hover:border-gray-300"
                  }`}
                >
                  <span className="block text-base font-semibold">{label}</span>
                  <span
                    className={`block text-sm ${selected ? "" : "text-gray-500"}`}
                  >
                    {desc}
                  </span>
                </button>
              );
            })}
          </div>
        )}

        {/* Step 3: Role-specific fields */}
        {step === 3 && (
          <div className="space-y-4">
            {hasFarmer && (
              <div>
                <label
                  htmlFor="farmName"
                  className="mb-1.5 block text-sm font-medium text-foreground"
                >
                  {t("farmNameLabel")}
                </label>
                <Input
                  id="farmName"
                  placeholder={t("farmNamePlaceholder")}
                  value={form.farmName}
                  onChange={(e) => updateForm("farmName", e.target.value)}
                />
              </div>
            )}

            {hasRider && (
              <>
                <div>
                  <label className="mb-1.5 block text-sm font-medium text-foreground">
                    {t("vehicleTypeLabel")}
                  </label>
                  <div className="grid grid-cols-3 gap-2">
                    {VEHICLE_TYPES.map((vt) => (
                      <button
                        key={vt}
                        type="button"
                        onClick={() => updateForm("vehicleType", vt)}
                        className={`rounded-md border-2 px-3 py-2.5 text-sm font-medium transition-all ${
                          form.vehicleType === vt
                            ? "border-primary bg-blue-50 text-primary"
                            : "border-gray-200 text-gray-600 hover:border-gray-300"
                        }`}
                      >
                        {t(vt)}
                      </button>
                    ))}
                  </div>
                </div>

                <div>
                  <label
                    htmlFor="capacity"
                    className="mb-1.5 block text-sm font-medium text-foreground"
                  >
                    {t("vehicleCapacityLabel")}
                  </label>
                  <Input
                    id="capacity"
                    type="number"
                    inputMode="decimal"
                    placeholder={t("vehicleCapacityPlaceholder")}
                    value={form.vehicleCapacityKg}
                    onChange={(e) =>
                      updateForm("vehicleCapacityKg", e.target.value)
                    }
                    min="0"
                  />
                </div>
              </>
            )}

            {!hasFarmer && !hasRider && (
              <p className="py-8 text-center text-sm text-gray-500">
                {t("subtitle")}
              </p>
            )}
          </div>
        )}

        {error && (
          <p className="mt-3 text-sm font-medium text-red-600">{error}</p>
        )}

        <div className="mt-6 flex gap-3">
          {step > 1 && (
            <Button variant="secondary" className="flex-1" onClick={handleBack}>
              {t("back")}
            </Button>
          )}

          {step < TOTAL_STEPS ? (
            <Button className="flex-1" onClick={handleNext}>
              {t("next")}
            </Button>
          ) : (
            <Button
              className="flex-1"
              onClick={handleComplete}
              disabled={loading}
            >
              {loading ? t("completing") : t("complete")}
            </Button>
          )}
        </div>
      </Card>
    </div>
  );
}
