"use client";

import { useEffect, useRef, useCallback } from "react";
import { logRiderLocation } from "@/lib/actions/tracking";

const LOG_INTERVAL_MS = 10_000; // Log every 10 seconds

export function useGpsTracking(tripId: string, active: boolean) {
  const watchIdRef = useRef<number | null>(null);
  const lastLogRef = useRef<number>(0);

  const handlePosition = useCallback(
    (position: GeolocationPosition) => {
      const now = Date.now();
      if (now - lastLogRef.current < LOG_INTERVAL_MS) return;
      lastLogRef.current = now;

      const { latitude, longitude, speed } = position.coords;
      const speedKmh = speed != null ? speed * 3.6 : undefined; // m/s to km/h

      logRiderLocation(tripId, latitude, longitude, speedKmh).catch((err) =>
        console.error("Failed to log location:", err),
      );
    },
    [tripId],
  );

  useEffect(() => {
    if (!active || typeof navigator === "undefined" || !navigator.geolocation)
      return;

    watchIdRef.current = navigator.geolocation.watchPosition(
      handlePosition,
      (err) => console.error("Geolocation error:", err),
      { enableHighAccuracy: true, maximumAge: 5000 },
    );

    return () => {
      if (watchIdRef.current != null) {
        navigator.geolocation.clearWatch(watchIdRef.current);
        watchIdRef.current = null;
      }
    };
  }, [active, handlePosition]);
}
