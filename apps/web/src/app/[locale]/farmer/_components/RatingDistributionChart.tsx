"use client";

import type { RatingDistribution } from "../analytics-actions";

export function RatingDistributionChart({
  data,
  avgRating,
  totalRatings,
  avgLabel,
  totalLabel,
}: {
  data: RatingDistribution[];
  avgRating: number;
  totalRatings: number;
  avgLabel: string;
  totalLabel: string;
}) {
  const maxCount = Math.max(...data.map((d) => Number(d.count)), 1);

  return (
    <div className="space-y-4">
      <div className="flex items-baseline gap-4">
        <div>
          <span className="text-3xl font-bold text-foreground">
            {avgRating.toFixed(1)}
          </span>
          <span className="ml-1 text-gray-400">/5</span>
        </div>
        <span className="text-sm text-gray-500">
          {avgLabel} ({totalRatings} {totalLabel})
        </span>
      </div>
      <div className="space-y-2">
        {[...data].reverse().map((item) => {
          const pct = maxCount > 0 ? (Number(item.count) / maxCount) * 100 : 0;
          return (
            <div key={item.score} className="flex items-center gap-3">
              <span className="w-4 text-right text-sm text-gray-500">
                {item.score}
              </span>
              <span className="text-sm text-amber-500">&#9733;</span>
              <div className="flex-1 h-3 rounded-full bg-gray-100 overflow-hidden">
                <div
                  className="h-full rounded-full bg-amber-400 transition-all"
                  style={{ width: `${pct}%` }}
                />
              </div>
              <span className="w-8 text-right text-sm text-gray-500">
                {item.count}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
