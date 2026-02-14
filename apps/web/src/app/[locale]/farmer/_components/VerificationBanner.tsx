"use client";

import { useTranslations } from "next-intl";
import { ShieldCheck, ShieldAlert, Clock, ShieldX } from "lucide-react";
import { Link } from "@/i18n/navigation";
import type { VerificationStatus } from "@/lib/supabase/types";

interface VerificationBannerProps {
  status: VerificationStatus;
  adminNotes?: string | null;
}

export function VerificationBanner({ status, adminNotes }: VerificationBannerProps) {
  const t = useTranslations("farmer.verification");

  if (status === "approved") {
    return (
      <div className="flex items-center gap-3 rounded-lg bg-emerald-50 p-4">
        <ShieldCheck className="h-6 w-6 shrink-0 text-emerald-600" />
        <div>
          <p className="font-medium text-emerald-800">{t("statusApproved")}</p>
        </div>
      </div>
    );
  }

  if (status === "pending") {
    return (
      <div className="flex items-center gap-3 rounded-lg bg-amber-50 p-4">
        <Clock className="h-6 w-6 shrink-0 text-amber-600" />
        <div>
          <p className="font-medium text-amber-800">{t("statusPending")}</p>
        </div>
      </div>
    );
  }

  if (status === "rejected") {
    return (
      <div className="rounded-lg bg-red-50 p-4">
        <div className="flex items-center gap-3">
          <ShieldX className="h-6 w-6 shrink-0 text-red-600" />
          <div className="flex-1">
            <p className="font-medium text-red-800">{t("statusRejected")}</p>
            {adminNotes && (
              <p className="mt-1 text-sm text-red-600">
                {t("rejectionReason")}: {adminNotes}
              </p>
            )}
          </div>
          <Link
            href="/farmer/verification"
            className="rounded-md bg-red-100 px-4 py-2 text-sm font-medium text-red-700 transition-colors hover:bg-red-200"
          >
            {t("resubmit")}
          </Link>
        </div>
      </div>
    );
  }

  // Unverified
  return (
    <div className="flex items-start gap-3 rounded-lg bg-blue-50 p-4">
      <ShieldAlert className="h-6 w-6 shrink-0 text-blue-600" />
      <div className="flex-1">
        <p className="font-medium text-blue-800">{t("statusUnverified")}</p>
        <p className="mt-1 text-sm text-blue-600">{t("benefits")}</p>
      </div>
      <Link
        href="/farmer/verification"
        className="rounded-md bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-600"
      >
        {t("submitDocuments")}
      </Link>
    </div>
  );
}
