"use client";

import { useTranslations } from "next-intl";
import { Badge } from "@/components/ui/Badge";
import type { BadgeColor } from "@/components/ui/Badge";
import type { OrderStatus } from "@/lib/types/order";

const STATUS_COLORS: Record<OrderStatus, BadgeColor> = {
  pending: "warning",
  matched: "primary",
  picked_up: "primary",
  in_transit: "accent",
  delivered: "success",
  cancelled: "danger",
  disputed: "danger",
};

export function OrderStatusBadge({ status }: { status: OrderStatus }) {
  const t = useTranslations("orders.status");
  return <Badge color={STATUS_COLORS[status]}>{t(status)}</Badge>;
}
