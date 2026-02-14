"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { acceptPing, declinePing } from "@/lib/actions/pings";
import type { OrderPing } from "@/lib/types/ping";

interface PingNotificationProps {
  ping: OrderPing;
  onAccepted?: (pingId: string) => void;
  onDeclined?: (pingId: string) => void;
}

export function PingNotification({
  ping,
  onAccepted,
  onDeclined,
}: PingNotificationProps) {
  const t = useTranslations("rider.pings");
  const [timeRemaining, setTimeRemaining] = useState(() =>
    Math.max(0, ping.expiresAt.getTime() - Date.now()),
  );
  const [accepting, setAccepting] = useState(false);
  const [declining, setDeclining] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const isExpired = timeRemaining <= 0;
  const minutes = Math.floor(timeRemaining / 60000);
  const seconds = Math.floor((timeRemaining % 60000) / 1000);
  const timeStr = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;

  // Countdown timer
  useEffect(() => {
    const timer = setInterval(() => {
      const remaining = Math.max(0, ping.expiresAt.getTime() - Date.now());
      setTimeRemaining(remaining);
    }, 1000);

    return () => clearInterval(timer);
  }, [ping.expiresAt]);

  const handleAccept = useCallback(async () => {
    setAccepting(true);
    setActionError(null);
    const result = await acceptPing(ping.id);
    if (result.error) {
      setActionError(result.error);
      setAccepting(false);
    } else {
      onAccepted?.(ping.id);
    }
  }, [ping.id, onAccepted]);

  const handleDecline = useCallback(async () => {
    setDeclining(true);
    setActionError(null);
    const result = await declinePing(ping.id);
    if (result.error) {
      setActionError(result.error);
      setDeclining(false);
    } else {
      onDeclined?.(ping.id);
    }
  }, [ping.id, onDeclined]);

  const detourKm = (ping.detourDistanceM / 1000).toFixed(1);

  return (
    <Card
      className={`relative border-2 transition-all ${
        isExpired
          ? "border-gray-200 opacity-60"
          : "border-primary animate-pulse-border"
      }`}
    >
      {/* Countdown badge */}
      <div className="absolute right-3 top-3">
        <Badge color={isExpired ? "danger" : timeRemaining < 60000 ? "warning" : "primary"}>
          {isExpired ? t("expired") : timeStr}
        </Badge>
      </div>

      {/* Header */}
      <div className="mb-3 pr-16">
        <h3 className="text-sm font-semibold text-foreground">
          {t("newOrders")}
        </h3>
      </div>

      {/* Pickup locations */}
      <div className="mb-2 space-y-1">
        {ping.pickupLocations.map((loc, idx) => (
          <div key={idx} className="flex items-center gap-2 text-xs text-gray-600">
            <span className="inline-block h-2 w-2 rounded-full bg-green-500" />
            <span>
              {t("pickup")}: {loc.farmerName}
            </span>
          </div>
        ))}
      </div>

      {/* Delivery */}
      <div className="mb-3 flex items-center gap-2 text-xs text-gray-600">
        <span className="inline-block h-2 w-2 rounded-full bg-red-500" />
        <span className="truncate">
          {t("delivery")}: {ping.deliveryLocation.address ?? `${ping.deliveryLocation.lat.toFixed(4)}, ${ping.deliveryLocation.lng.toFixed(4)}`}
        </span>
      </div>

      {/* Details row */}
      <div className="mb-3 flex flex-wrap gap-3 text-xs text-gray-500">
        <span>{t("weight")}: {ping.totalWeightKg} kg</span>
        <span>{t("earnings")}: NPR {ping.estimatedEarnings.toFixed(0)}</span>
        <span>{t("detour")}: ~{detourKm} km</span>
      </div>

      {/* Error */}
      {actionError && (
        <div className="mb-3 rounded bg-red-50 px-2 py-1 text-xs text-red-600">
          {actionError}
        </div>
      )}

      {/* Action buttons */}
      <div className="flex gap-2">
        <Button
          variant="primary"
          className="h-10 flex-1 text-sm"
          onClick={handleAccept}
          disabled={isExpired || accepting || declining}
        >
          {accepting ? t("accepting") : t("accept")}
        </Button>
        <Button
          variant="outline"
          className="h-10 flex-1 text-sm"
          onClick={handleDecline}
          disabled={isExpired || accepting || declining}
        >
          {declining ? t("declining") : t("decline")}
        </Button>
      </div>

      <style jsx>{`
        @keyframes pulse-border {
          0%, 100% { border-color: var(--color-primary, #3b82f6); }
          50% { border-color: var(--color-primary-light, #93c5fd); }
        }
        :global(.animate-pulse-border) {
          animation: pulse-border 2s ease-in-out infinite;
        }
      `}</style>
    </Card>
  );
}
