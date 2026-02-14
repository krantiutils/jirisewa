"use client";

import { useRouter, useSearchParams } from "next/navigation";

export function PeriodSelector({
  current,
  labels,
}: {
  current: number;
  labels: { d7: string; d30: string; d90: string };
}) {
  const router = useRouter();
  const searchParams = useSearchParams();

  function handleChange(days: number) {
    const params = new URLSearchParams(searchParams.toString());
    params.set("days", days.toString());
    router.push(`?${params.toString()}`);
  }

  const options = [
    { value: 7, label: labels.d7 },
    { value: 30, label: labels.d30 },
    { value: 90, label: labels.d90 },
  ];

  return (
    <div className="flex gap-1 rounded-lg bg-gray-100 p-1">
      {options.map((opt) => (
        <button
          key={opt.value}
          onClick={() => handleChange(opt.value)}
          className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
            current === opt.value
              ? "bg-white text-foreground"
              : "text-gray-500 hover:text-gray-700"
          }`}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
