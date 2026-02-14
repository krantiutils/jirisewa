"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  forceResolveOrder,
  cancelOrder,
  updateOrderStatus,
} from "@/lib/admin/actions";
import { Button } from "@/components/ui";

interface OrderActionsProps {
  locale: string;
  orderId: string;
  status: string;
}

export function OrderActions({ locale, orderId, status }: OrderActionsProps) {
  const router = useRouter();
  const t = useTranslations("admin.orders");
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleAction(
    action: () => Promise<{ success: boolean; error?: string }>,
    actionName: string,
  ) {
    setLoading(actionName);
    setError(null);
    const result = await action();
    setLoading(null);
    if (!result.success && "error" in result) {
      setError(result.error ?? "Unknown error");
    } else {
      router.refresh();
    }
  }

  // No actions for terminal states
  if (status === "delivered" || status === "cancelled") {
    return null;
  }

  return (
    <div className="rounded-lg bg-white p-6">
      <h2 className="mb-4 text-lg font-semibold text-foreground">
        {t("adminActions")}
      </h2>

      {error && (
        <p className="mb-4 rounded-md bg-red-50 p-3 text-sm text-red-600">
          {error}
        </p>
      )}

      <div className="flex flex-wrap gap-3">
        {status === "disputed" && (
          <Button
            variant="primary"
            onClick={() =>
              handleAction(
                () => forceResolveOrder(locale, orderId),
                "resolve",
              )
            }
            disabled={loading !== null}
            className="text-sm h-10 px-4"
          >
            {loading === "resolve" ? t("resolving") : t("forceResolve")}
          </Button>
        )}

        {status !== "disputed" && status !== "delivered" && (
          <Button
            variant="primary"
            onClick={() =>
              handleAction(
                () => updateOrderStatus(locale, orderId, "disputed"),
                "dispute",
              )
            }
            disabled={loading !== null}
            className="text-sm h-10 px-4"
          >
            {loading === "dispute" ? t("marking") : t("markDisputed")}
          </Button>
        )}

        {status !== "cancelled" && (
          <Button
            variant="outline"
            onClick={() =>
              handleAction(() => cancelOrder(locale, orderId), "cancel")
            }
            disabled={loading !== null}
            className="text-sm h-10 px-4 border-red-500 text-red-500 hover:bg-red-500 hover:text-white"
          >
            {loading === "cancel" ? t("cancelling") : t("cancelOrder")}
          </Button>
        )}
      </div>
    </div>
  );
}
