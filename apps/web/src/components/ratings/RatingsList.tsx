"use client";

import { useLocale, useTranslations } from "next-intl";
import { Star, User } from "lucide-react";
import Image from "next/image";
import type { RatingWithUsers } from "@/lib/actions/ratings";
import type { Locale } from "@/lib/i18n";

interface RatingsListProps {
  ratings: RatingWithUsers[];
  emptyMessage?: string;
}

export function RatingsList({ ratings, emptyMessage }: RatingsListProps) {
  const t = useTranslations("ratings");
  const locale = useLocale() as Locale;

  if (ratings.length === 0) {
    return (
      <p className="py-8 text-center text-gray-500">
        {emptyMessage ?? t("noRatings")}
      </p>
    );
  }

  return (
    <div className="space-y-4">
      {ratings.map((rating) => (
        <div
          key={rating.id}
          className="rounded-lg bg-white p-4"
        >
          {/* Rater info + stars */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100">
                {rating.rater?.avatar_url ? (
                  <Image
                    src={rating.rater.avatar_url}
                    alt={rating.rater.name ?? ""}
                    width={40}
                    height={40}
                    className="rounded-full object-cover"
                    unoptimized
                  />
                ) : (
                  <User className="h-5 w-5 text-gray-400" />
                )}
              </div>
              <div>
                <p className="font-semibold text-foreground">
                  {rating.rater?.name ?? "Unknown"}
                </p>
                <p className="text-xs text-gray-500">
                  {new Date(rating.created_at).toLocaleDateString(
                    locale === "ne" ? "ne-NP" : "en-US",
                    { year: "numeric", month: "short", day: "numeric" },
                  )}
                </p>
              </div>
            </div>

            {/* Stars */}
            <div className="flex gap-0.5">
              {[1, 2, 3, 4, 5].map((star) => (
                <Star
                  key={star}
                  className={`h-4 w-4 ${
                    star <= rating.score
                      ? "fill-amber-400 text-amber-400"
                      : "fill-gray-200 text-gray-200"
                  }`}
                />
              ))}
            </div>
          </div>

          {/* Comment */}
          {rating.comment && (
            <p className="mt-3 text-sm leading-relaxed text-gray-700">
              {rating.comment}
            </p>
          )}
        </div>
      ))}
    </div>
  );
}
