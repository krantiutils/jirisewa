"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Building2, Loader2 } from "lucide-react";
import { createBusinessProfile, getBusinessProfile } from "@/lib/actions/business";
import { Button } from "@/components/ui/Button";
import type { Locale } from "@/lib/i18n";

const BUSINESS_TYPES = ["restaurant", "hotel", "canteen", "other"] as const;

export default function BusinessRegisterPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("business");

  const [businessName, setBusinessName] = useState("");
  const [businessType, setBusinessType] = useState<typeof BUSINESS_TYPES[number]>("restaurant");
  const [registrationNumber, setRegistrationNumber] = useState("");
  const [address, setAddress] = useState("");
  const [phone, setPhone] = useState("");
  const [contactPerson, setContactPerson] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function checkExisting() {
      const result = await getBusinessProfile();
      if (result.data) {
        router.push(`/${locale}/business/dashboard`);
      }
      setLoading(false);
    }
    checkExisting();
  }, [locale, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    const result = await createBusinessProfile({
      business_name: businessName,
      business_type: businessType,
      registration_number: registrationNumber || undefined,
      address,
      phone: phone || undefined,
      contact_person: contactPerson || undefined,
    });

    if (result.error) {
      setError(result.error);
      setSubmitting(false);
      return;
    }

    router.push(`/${locale}/business/dashboard`);
  };

  if (loading) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
        <div className="mb-6 flex items-center gap-3">
          <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
            <Building2 className="h-6 w-6 text-blue-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-foreground">
              {t("register.title")}
            </h1>
            <p className="text-sm text-gray-500">{t("register.subtitle")}</p>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Business Name */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
              {t("register.businessName")}
            </label>
            <input
              type="text"
              value={businessName}
              onChange={(e) => setBusinessName(e.target.value)}
              placeholder={t("register.businessNamePlaceholder")}
              required
              className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
            />
          </div>

          {/* Business Type */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
              {t("register.businessType")}
            </label>
            <div className="mt-2 grid grid-cols-2 gap-2">
              {BUSINESS_TYPES.map((type) => (
                <button
                  key={type}
                  type="button"
                  onClick={() => setBusinessType(type)}
                  className={`rounded-md px-4 py-3 text-sm font-medium transition-all ${
                    businessType === type
                      ? "bg-primary text-white"
                      : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                  }`}
                >
                  {t(`register.types.${type}`)}
                </button>
              ))}
            </div>
          </div>

          {/* Registration Number */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
              {t("register.registrationNumber")}
            </label>
            <input
              type="text"
              value={registrationNumber}
              onChange={(e) => setRegistrationNumber(e.target.value)}
              placeholder={t("register.registrationNumberPlaceholder")}
              className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
            />
          </div>

          {/* Address */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
              {t("register.address")}
            </label>
            <input
              type="text"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder={t("register.addressPlaceholder")}
              required
              className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
            />
          </div>

          {/* Phone */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
              {t("register.phone")}
            </label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder={t("register.phonePlaceholder")}
              className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
            />
          </div>

          {/* Contact Person */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
              {t("register.contactPerson")}
            </label>
            <input
              type="text"
              value={contactPerson}
              onChange={(e) => setContactPerson(e.target.value)}
              placeholder={t("register.contactPersonPlaceholder")}
              className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
            />
          </div>

          <Button
            variant="primary"
            type="submit"
            disabled={submitting || !businessName || !address}
            className="w-full h-14 text-base"
          >
            {submitting ? (
              <>
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                {t("register.submitting")}
              </>
            ) : (
              t("register.submit")
            )}
          </Button>
        </form>
      </div>
    </main>
  );
}
