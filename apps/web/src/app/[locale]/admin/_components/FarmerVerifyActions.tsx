"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { verifyFarmer, rejectFarmerVerification } from "@/lib/admin/actions";

interface FarmerVerifyActionsProps {
  locale: string;
  roleId: string;
  hasDocuments: boolean;
}

export function FarmerVerifyActions({
  locale,
  roleId,
  hasDocuments,
}: FarmerVerifyActionsProps) {
  const router = useRouter();
  const t = useTranslations("admin.farmers");
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [notes, setNotes] = useState("");

  async function handleVerify() {
    setLoading("verify");
    setError(null);
    const result = await verifyFarmer(locale, roleId);
    setLoading(null);
    if (!result.success) {
      setError("error" in result ? result.error : "Failed to verify");
      return;
    }
    router.refresh();
  }

  async function handleReject() {
    setLoading("reject");
    setError(null);
    const result = await rejectFarmerVerification(locale, roleId, notes || undefined);
    setLoading(null);
    if (!result.success) {
      setError("error" in result ? result.error : "Failed to reject");
      return;
    }
    setShowRejectForm(false);
    setNotes("");
    router.refresh();
  }

  return (
    <div>
      {error && (
        <p className="mb-2 text-xs text-red-600">{error}</p>
      )}

      {showRejectForm ? (
        <div className="space-y-2">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder={t("rejectionNotesPlaceholder")}
            className="w-full rounded-md border border-gray-300 p-2 text-sm focus:border-primary focus:outline-none"
            rows={2}
          />
          <div className="flex gap-2">
            <button
              onClick={handleReject}
              disabled={loading !== null}
              className="rounded-md bg-red-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-red-600 transition-colors disabled:opacity-50 cursor-pointer"
            >
              {loading === "reject" ? t("rejecting") : t("reject")}
            </button>
            <button
              onClick={() => { setShowRejectForm(false); setNotes(""); }}
              disabled={loading !== null}
              className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200 transition-colors cursor-pointer"
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <div className="flex gap-2">
          <button
            onClick={handleVerify}
            disabled={loading !== null || !hasDocuments}
            title={!hasDocuments ? t("noDocuments") : undefined}
            className="rounded-md bg-emerald-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-emerald-600 transition-colors disabled:opacity-50 cursor-pointer"
          >
            {loading === "verify" ? t("verifying") : t("approve")}
          </button>
          <button
            onClick={() => setShowRejectForm(true)}
            disabled={loading !== null}
            className="rounded-md bg-red-100 px-3 py-1.5 text-sm font-medium text-red-600 hover:bg-red-200 transition-colors disabled:opacity-50 cursor-pointer"
          >
            {t("reject")}
          </button>
        </div>
      )}
    </div>
  );
}
