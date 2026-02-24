"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";

interface PayoutStatusFilterProps {
  locale: string;
  initialStatus?: string;
}

const statuses = ["all", "pending", "processing", "completed", "rejected"];

export function PayoutStatusFilter({
  locale,
  initialStatus,
}: PayoutStatusFilterProps) {
  const router = useRouter();
  const t = useTranslations("admin.payouts");

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
              router.push(`/${locale}/admin/payouts?${params.toString()}`);
            }}
            className={`rounded-full px-4 py-1.5 text-sm font-medium transition-colors cursor-pointer ${
              isActive
                ? "bg-primary text-white"
                : "bg-gray-100 text-gray-600 hover:bg-gray-200"
            }`}
          >
            {status === "all"
              ? t("allStatuses")
              : t(`statusLabels.${status}` as never)}
          </button>
        );
      })}
    </div>
  );
}
