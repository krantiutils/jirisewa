"use client";

import { useState } from "react";
import { Star } from "lucide-react";
import { useTranslations } from "next-intl";

interface StarRatingProps {
  value: number;
  onChange?: (value: number) => void;
  readonly?: boolean;
  size?: "sm" | "md" | "lg";
  showLabel?: boolean;
}

const sizeClasses = {
  sm: "h-4 w-4",
  md: "h-6 w-6",
  lg: "h-8 w-8",
};

export function StarRating({
  value,
  onChange,
  readonly = false,
  size = "md",
  showLabel = false,
}: StarRatingProps) {
  const [hoveredStar, setHoveredStar] = useState(0);
  const t = useTranslations("ratings");

  const displayValue = hoveredStar || value;
  const starSize = sizeClasses[size];

  const labelKey = displayValue >= 1 && displayValue <= 5
    ? String(displayValue) as "1" | "2" | "3" | "4" | "5"
    : null;

  return (
    <div className="flex items-center gap-1">
      <div className="flex gap-0.5">
        {[1, 2, 3, 4, 5].map((star) => (
          <button
            key={star}
            type="button"
            disabled={readonly}
            onClick={() => onChange?.(star)}
            onMouseEnter={() => !readonly && setHoveredStar(star)}
            onMouseLeave={() => !readonly && setHoveredStar(0)}
            className={`transition-transform ${
              readonly
                ? "cursor-default"
                : "cursor-pointer hover:scale-110"
            }`}
            aria-label={`${star} star${star > 1 ? "s" : ""}`}
          >
            <Star
              className={`${starSize} transition-colors ${
                star <= displayValue
                  ? "fill-amber-400 text-amber-400"
                  : "fill-gray-200 text-gray-200"
              }`}
            />
          </button>
        ))}
      </div>
      {showLabel && labelKey && (
        <span className="ml-2 text-sm text-gray-600">
          {t(`stars.${labelKey}`)}
        </span>
      )}
    </div>
  );
}
