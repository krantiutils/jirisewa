"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { processPayoutRequest } from "@/lib/actions/admin/payouts";

interface PayoutActionsProps {
  locale: string;
  payoutId: string;
  currentStatus: string;
}

export function PayoutActions({
  locale,
  payoutId,
  currentStatus,
}: PayoutActionsProps) {
  const router = useRouter();
  const t = useTranslations("admin.payouts");
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [notes, setNotes] = useState("");

  async function handleAction(status: string, adminNotes?: string) {
    setLoading(status);
    setError(null);
    const result = await processPayoutRequest(locale, payoutId, {
      status,
      adminNotes,
    });
    setLoading(null);
    if (!result.success) {
      setError("error" in result ? result.error : "Failed to process");
      return;
    }
    setShowRejectForm(false);
    setNotes("");
    router.refresh();
  }

  // No actions available for completed or rejected payouts
  if (currentStatus === "completed" || currentStatus === "rejected") {
    return null;
  }

  return (
    <div>
      {error && <p className="mb-2 text-xs text-red-600">{error}</p>}

      {showRejectForm ? (
        <div className="space-y-2">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder={t("rejectNotesPlaceholder")}
            className="w-full rounded-md border border-gray-300 p-2 text-sm focus:border-primary focus:outline-none"
            rows={2}
          />
          <div className="flex gap-2">
            <button
              onClick={() => handleAction("rejected", notes || undefined)}
              disabled={loading !== null}
              className="rounded-md bg-red-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-red-600 transition-colors disabled:opacity-50 cursor-pointer"
            >
              {loading === "rejected" ? t("rejecting") : t("reject")}
            </button>
            <button
              onClick={() => {
                setShowRejectForm(false);
                setNotes("");
              }}
              disabled={loading !== null}
              className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200 transition-colors cursor-pointer"
            >
              {t("cancel")}
            </button>
          </div>
        </div>
      ) : (
        <div className="flex gap-2">
          {currentStatus === "pending" && (
            <button
              onClick={() => handleAction("processing")}
              disabled={loading !== null}
              className="rounded-md bg-blue-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-blue-600 transition-colors disabled:opacity-50 cursor-pointer"
            >
              {loading === "processing" ? t("approving") : t("approve")}
            </button>
          )}
          {currentStatus === "processing" && (
            <button
              onClick={() => handleAction("completed")}
              disabled={loading !== null}
              className="rounded-md bg-emerald-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-emerald-600 transition-colors disabled:opacity-50 cursor-pointer"
            >
              {loading === "completed" ? t("completing") : t("complete")}
            </button>
          )}
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
