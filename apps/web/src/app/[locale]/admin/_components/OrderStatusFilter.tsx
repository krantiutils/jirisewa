"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";

interface OrderStatusFilterProps {
  locale: string;
  initialStatus?: string;
}

const statuses = [
  "all",
  "pending",
  "matched",
  "picked_up",
  "in_transit",
  "delivered",
  "cancelled",
  "disputed",
];

export function OrderStatusFilter({
  locale,
  initialStatus,
}: OrderStatusFilterProps) {
  const router = useRouter();
  const t = useTranslations("admin.orders");

  return (
    <div className="flex flex-wrap gap-2">
      {statuses.map((status) => {
        const isActive =
          status === "all"
            ? !initialStatus || initialStatus === "all"
            : initialStatus === status;
        return (
          <button
            key={status}
            onClick={() => {
              const params = new URLSearchParams();
              if (status !== "all") params.set("status", status);
              router.push(`/${locale}/admin/orders?${params.toString()}`);
            }}
            className={`rounded-full px-4 py-1.5 text-sm font-medium transition-colors cursor-pointer ${
              isActive
                ? "bg-primary text-white"
                : "bg-gray-100 text-gray-600 hover:bg-gray-200"
            }`}
          >
            {status === "all" ? t("allStatuses") : status.replace("_", " ")}
          </button>
        );
      })}
    </div>
  );
}
