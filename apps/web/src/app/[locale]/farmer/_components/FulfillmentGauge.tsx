"use client";

import type { FulfillmentRate } from "../analytics-actions";

export function FulfillmentGauge({
  data,
  deliveredLabel,
  cancelledLabel,
  totalLabel,
  rateLabel,
}: {
  data: FulfillmentRate;
  deliveredLabel: string;
  cancelledLabel: string;
  totalLabel: string;
  rateLabel: string;
}) {
  const pct = Number(data.fulfillment_pct);
  const circumference = 2 * Math.PI * 60;
  const dashOffset = circumference - (circumference * pct) / 100;

  const gaugeColor =
    pct >= 80
      ? "stroke-emerald-500"
      : pct >= 50
        ? "stroke-amber-500"
        : "stroke-red-500";

  return (
    <div className="flex flex-col items-center gap-4">
      <div className="relative">
        <svg width="150" height="150" viewBox="0 0 150 150">
          <circle
            cx="75"
            cy="75"
            r="60"
            fill="none"
            stroke="#e5e7eb"
            strokeWidth="12"
          />
          <circle
            cx="75"
            cy="75"
            r="60"
            fill="none"
            className={gaugeColor}
            strokeWidth="12"
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={dashOffset}
            transform="rotate(-90 75 75)"
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-2xl font-bold text-foreground">{pct}%</span>
          <span className="text-xs text-gray-500">{rateLabel}</span>
        </div>
      </div>
      <div className="flex gap-6 text-sm">
        <div className="text-center">
          <p className="font-semibold text-foreground">{data.delivered}</p>
          <p className="text-gray-500">{deliveredLabel}</p>
        </div>
        <div className="text-center">
          <p className="font-semibold text-foreground">{data.cancelled}</p>
          <p className="text-gray-500">{cancelledLabel}</p>
        </div>
        <div className="text-center">
          <p className="font-semibold text-foreground">{data.total_orders}</p>
          <p className="text-gray-500">{totalLabel}</p>
        </div>
      </div>
    </div>
  );
}
