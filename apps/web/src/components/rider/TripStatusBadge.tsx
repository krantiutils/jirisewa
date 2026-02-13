import { TripStatus } from "@jirisewa/shared";
import { useTranslations } from "next-intl";
import type { BadgeColor } from "@/components/ui/Badge";
import { Badge } from "@/components/ui/Badge";

const STATUS_COLOR_MAP: Record<TripStatus, BadgeColor> = {
  [TripStatus.Scheduled]: "primary",
  [TripStatus.InTransit]: "accent",
  [TripStatus.Completed]: "secondary",
  [TripStatus.Cancelled]: "primary", // no "danger" color available; fallback
};

export function TripStatusBadge({ status }: { status: TripStatus }) {
  const t = useTranslations("rider");

  if (status === TripStatus.Cancelled) {
    // Badge doesn't have a red variant, use inline span
    return (
      <span className="inline-flex items-center rounded-full bg-red-100 px-3 py-1 text-sm font-medium text-red-700">
        {t(`tripStatus.${status}`)}
      </span>
    );
  }

  return (
    <Badge color={STATUS_COLOR_MAP[status]}>
      {t(`tripStatus.${status}`)}
    </Badge>
  );
}
