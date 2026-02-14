"use client";

import { useState, useCallback } from "react";
import { useLocale, useTranslations } from "next-intl";
import { Star, Package, ChevronDown, ChevronUp } from "lucide-react";
import { Badge, Button } from "@/components/ui";
import { RatingModal } from "@/components/ratings";
import type { OrderWithDetails } from "@/lib/types/order";
import type { RatingStatus } from "@/lib/actions/ratings";
import type { RoleRated } from "@jirisewa/shared";
import type { Locale } from "@/lib/i18n";

interface OrderCardProps {
  order: OrderWithDetails;
  ratingStatus: RatingStatus | null;
}

const statusColors: Record<string, "primary" | "secondary" | "accent"> = {
  pending: "accent",
  matched: "primary",
  picked_up: "primary",
  in_transit: "primary",
  delivered: "secondary",
  cancelled: "accent",
  disputed: "accent",
};

export function OrderCard({ order, ratingStatus }: OrderCardProps) {
  const locale = useLocale() as Locale;
  const t = useTranslations("orders");
  const tRatings = useTranslations("ratings");
  const [expanded, setExpanded] = useState(false);
  const [ratingModal, setRatingModal] = useState<{
    ratedId: string;
    ratedName: string;
    roleRated: RoleRated;
  } | null>(null);
  const [completedRatings, setCompletedRatings] = useState<Set<string>>(new Set());

  const handleRatingSuccess = useCallback(() => {
    if (ratingModal) {
      setCompletedRatings((prev) => new Set(prev).add(ratingModal.ratedId));
    }
    setRatingModal(null);
  }, [ratingModal]);

  const isDelivered = order.status === "delivered";
  const canRate = ratingStatus?.canRate.filter(
    (r) => !completedRatings.has(r.ratedId),
  ) ?? [];
  const alreadyRated = [
    ...(ratingStatus?.alreadyRated ?? []),
    ...(ratingStatus?.canRate.filter((r) => completedRatings.has(r.ratedId)).map(
      (r) => ({ ...r, score: 0 }),
    ) ?? []),
  ];

  return (
    <>
      <div className="rounded-lg bg-white p-5 transition-all duration-200">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100">
              <Package className="h-5 w-5 text-gray-500" />
            </div>
            <div>
              <p className="font-bold text-foreground">
                {t("orderNumber", { id: order.id.slice(0, 8) })}
              </p>
              <p className="text-xs text-gray-500">
                {t("placed", {
                  date: new Date(order.created_at).toLocaleDateString(
                    locale === "ne" ? "ne-NP" : "en-US",
                    { year: "numeric", month: "short", day: "numeric" },
                  ),
                })}
              </p>
            </div>
          </div>

          <Badge color={statusColors[order.status] ?? "primary"}>
            {t(`status.${order.status}`)}
          </Badge>
        </div>

        {/* Summary */}
        <div className="mt-3 flex items-center justify-between text-sm text-gray-600">
          <span>
            {t("totalItems", { count: order.items.length })}
          </span>
          <span className="font-semibold text-foreground">
            {t("totalWithDelivery", {
              total: Number(order.total_price).toLocaleString(),
              fee: Number(order.delivery_fee).toLocaleString(),
            })}
          </span>
        </div>

        {/* Expand/collapse items */}
        <button
          onClick={() => setExpanded(!expanded)}
          className="mt-2 flex w-full items-center justify-center gap-1 rounded-md py-1 text-sm text-gray-500 transition-colors hover:bg-gray-50 hover:text-primary"
        >
          {expanded ? (
            <ChevronUp className="h-4 w-4" />
          ) : (
            <ChevronDown className="h-4 w-4" />
          )}
        </button>

        {/* Expanded items */}
        {expanded && (
          <div className="mt-2 space-y-2 border-t border-gray-100 pt-3">
            {order.items.map((item) => {
              const itemName = locale === "ne"
                ? item.listing?.name_ne
                : item.listing?.name_en;
              return (
                <div
                  key={item.id}
                  className="flex items-center justify-between text-sm"
                >
                  <span className="text-gray-700">
                    {itemName ?? "Unknown"} x {item.quantity_kg}kg
                  </span>
                  <span className="font-medium text-foreground">
                    NPR {Number(item.subtotal).toLocaleString()}
                  </span>
                </div>
              );
            })}
          </div>
        )}

        {/* Rating section — only for delivered orders */}
        {isDelivered && (canRate.length > 0 || alreadyRated.length > 0) && (
          <div className="mt-4 border-t border-gray-100 pt-4">
            <p className="mb-3 text-sm font-semibold text-gray-600">
              {t("rateOrder")}
            </p>

            <div className="flex flex-wrap gap-2">
              {/* Rate buttons for unrated parties */}
              {canRate.map((target) => (
                <Button
                  key={target.ratedId}
                  variant="outline"
                  className="h-10 px-4 text-sm"
                  onClick={() =>
                    setRatingModal({
                      ratedId: target.ratedId,
                      ratedName: target.ratedName,
                      roleRated: target.roleRated,
                    })
                  }
                >
                  <Star className="mr-1.5 h-4 w-4" />
                  {target.roleRated === "farmer"
                    ? t("rateFarmer")
                    : t("rateRider")}
                  {" — "}
                  {target.ratedName}
                </Button>
              ))}

              {/* Already rated indicators */}
              {alreadyRated.map((rated) => (
                <div
                  key={rated.ratedId}
                  className="inline-flex items-center gap-1.5 rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-700"
                >
                  <Star className="h-3.5 w-3.5 fill-emerald-500 text-emerald-500" />
                  {t("rated")} — {rated.ratedName}
                  {rated.score > 0 && (
                    <span className="font-semibold">({rated.score}/5)</span>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Rating Modal */}
      {ratingModal && (
        <RatingModal
          isOpen={!!ratingModal}
          onClose={() => setRatingModal(null)}
          onSuccess={handleRatingSuccess}
          orderId={order.id}
          ratedId={ratingModal.ratedId}
          ratedName={ratingModal.ratedName}
          roleRated={ratingModal.roleRated}
        />
      )}
    </>
  );
}
