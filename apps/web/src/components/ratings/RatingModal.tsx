"use client";

import { useState, useCallback } from "react";
import { X } from "lucide-react";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ui";
import { StarRating } from "./StarRating";
import { submitRating } from "@/lib/actions/ratings";
import type { RoleRated } from "@jirisewa/shared";

interface RatingModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  orderId: string;
  ratedId: string;
  ratedName: string;
  roleRated: RoleRated;
}

export function RatingModal({
  isOpen,
  onClose,
  onSuccess,
  orderId,
  ratedId,
  ratedName,
  roleRated,
}: RatingModalProps) {
  const t = useTranslations("ratings");
  const [score, setScore] = useState(0);
  const [comment, setComment] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const titleKey = roleRated === "farmer" ? "rateFarmerTitle" : "rateRiderTitle";

  const handleSubmit = useCallback(async () => {
    if (score < 1 || score > 5) {
      setError("Please select a rating");
      return;
    }

    setSubmitting(true);
    setError(null);

    const result = await submitRating({
      orderId,
      ratedId,
      roleRated,
      score,
      comment: comment.trim() || undefined,
    });

    setSubmitting(false);

    if (!result.success) {
      setError(result.error);
      return;
    }

    onSuccess();
  }, [score, comment, orderId, ratedId, roleRated, onSuccess]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-lg bg-white p-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-foreground">
            {t(titleKey, { name: ratedName })}
          </h2>
          <button
            onClick={onClose}
            className="rounded-md p-1 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600"
            aria-label={t("close")}
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Star selector */}
        <div className="mt-6">
          <label className="mb-2 block text-sm font-semibold text-gray-600">
            {t("rateYourExperience")}
          </label>
          <StarRating
            value={score}
            onChange={setScore}
            size="lg"
            showLabel
          />
        </div>

        {/* Comment */}
        <div className="mt-4">
          <textarea
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder={t("commentPlaceholder")}
            maxLength={500}
            rows={3}
            className="w-full rounded-md border-2 border-transparent bg-gray-100 px-4 py-3 text-foreground transition-all duration-200 focus:border-primary focus:bg-white focus:outline-none"
          />
        </div>

        {/* Error */}
        {error && (
          <p className="mt-2 text-sm text-red-600">{error}</p>
        )}

        {/* Actions */}
        <div className="mt-6 flex gap-3">
          <Button
            variant="secondary"
            onClick={onClose}
            className="flex-1 h-12"
            disabled={submitting}
          >
            {t("cancel")}
          </Button>
          <Button
            variant="primary"
            onClick={handleSubmit}
            className="flex-1 h-12"
            disabled={submitting || score < 1}
          >
            {submitting ? t("submitting") : t("submitRating")}
          </Button>
        </div>
      </div>
    </div>
  );
}
