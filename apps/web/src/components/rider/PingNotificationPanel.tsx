"use client";

import { useCallback, useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import dynamic from "next/dynamic";
import { PingNotification } from "@/components/rider/PingNotification";
import type { OrderPing } from "@/lib/types/ping";

interface PingNotificationPanelProps {
  pings: OrderPing[];
  onPingRemoved: (pingId: string) => void;
  /** Called when a ping is accepted so parent can refresh data */
  onAccepted?: () => void;
}

const PingBeaconMap = dynamic(
  () => import("@/components/rider/PingBeaconMap"),
  { ssr: false },
);

export function PingNotificationPanel({
  pings,
  onPingRemoved,
  onAccepted,
}: PingNotificationPanelProps) {
  const t = useTranslations("rider.pings");
  const prevCountRef = useRef(pings.length);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  // Request Web Notification API permission on mount
  useEffect(() => {
    if (typeof window !== "undefined" && "Notification" in window) {
      if (Notification.permission === "default") {
        Notification.requestPermission();
      }
    }
  }, []);

  // Play audio and send browser notification when new pings arrive
  useEffect(() => {
    if (pings.length > prevCountRef.current) {
      // New ping(s) arrived
      try {
        if (!audioRef.current) {
          audioRef.current = new Audio("/sounds/ping.mp3");
        }
        audioRef.current.currentTime = 0;
        audioRef.current.play().catch(() => {
          // Audio autoplay may be blocked — that's fine
        });
      } catch {
        // Audio not available
      }

      // Send browser notification
      if (
        typeof window !== "undefined" &&
        "Notification" in window &&
        Notification.permission === "granted"
      ) {
        new Notification(t("newOrders"), {
          body: t("newOrderBody"),
          icon: "/favicon.ico",
        });
      }
    }
    prevCountRef.current = pings.length;
  }, [pings.length, t]);

  const handleAccepted = useCallback(
    (pingId: string) => {
      onPingRemoved(pingId);
      onAccepted?.();
    },
    [onPingRemoved, onAccepted],
  );

  if (pings.length === 0) return null;

  return (
    <div className="mb-6 space-y-3">
      <h2 className="text-lg font-semibold text-foreground">
        {t("newOrders")} ({pings.length})
      </h2>
      <PingBeaconMap pings={pings} />
      {pings.map((ping) => (
        <PingNotification
          key={ping.id}
          ping={ping}
          onAccepted={handleAccepted}
          onDeclined={onPingRemoved}
        />
      ))}
    </div>
  );
}
