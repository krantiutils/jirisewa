"use client";

import { useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import {
  getLatestRiderLocation,
  getTripRouteData,
} from "@/lib/actions/tracking";
import type {
  RiderLocationPoint,
  TripRouteData,
} from "@/lib/actions/tracking";
import { OSRM_BASE_URL } from "@jirisewa/shared";

/** How often (ms) we consider a location update "stale" (no update received). */
const STALE_THRESHOLD_MS = 30_000;

/** Minimum interval (ms) between ETA calculations to avoid OSRM rate limits. */
const ETA_THROTTLE_MS = 15_000;

export interface RiderTrackingState {
  /** Latest rider position (null until first location received) */
  riderLocation: RiderLocationPoint | null;
  /** Trip route data (origin, destination, route polyline) */
  tripRoute: TripRouteData | null;
  /** Estimated time of arrival in seconds (null if can't calculate) */
  etaSeconds: number | null;
  /** Remaining distance to delivery in meters */
  remainingDistanceMeters: number | null;
  /** Whether the location data is stale (no update in 30s) */
  isStale: boolean;
  /** Whether we're loading initial data */
  loading: boolean;
  /** Error message if something went wrong */
  error: string | null;
}

/**
 * Parse a PostGIS point from a Realtime payload into a RiderLocationPoint.
 */
function parseRealtimeLocation(
  payload: Record<string, unknown>,
): RiderLocationPoint | null {
  const location = payload.location;
  if (!location || typeof location !== "string") return null;

  let lat: number;
  let lng: number;

  // GeoJSON: {"type":"Point","coordinates":[lng,lat]}
  if (location.startsWith("{")) {
    try {
      const parsed = JSON.parse(location);
      lng = parsed.coordinates[0];
      lat = parsed.coordinates[1];
    } catch {
      return null;
    }
  } else {
    // WKT: POINT(lng lat)
    const match = location.match(/POINT\(([^ ]+) ([^ ]+)\)/);
    if (!match) return null;
    lng = parseFloat(match[1]);
    lat = parseFloat(match[2]);
  }

  return {
    lat,
    lng,
    speedKmh:
      typeof payload.speed_kmh === "number" ? payload.speed_kmh : null,
    recordedAt: (payload.recorded_at as string) ?? new Date().toISOString(),
  };
}

/**
 * Hook that subscribes to live rider location updates for a given trip.
 *
 * Uses Supabase Realtime Postgres Changes to listen for INSERT events
 * on the rider_location_log table filtered by trip_id.
 *
 * ETA is calculated using OSRM route distance from rider position to
 * delivery destination, combined with current rider speed.
 */
export function useRiderTracking(
  tripId: string | null,
  deliveryLat?: number,
  deliveryLng?: number,
): RiderTrackingState {
  const [riderLocation, setRiderLocation] =
    useState<RiderLocationPoint | null>(null);
  const [tripRoute, setTripRoute] = useState<TripRouteData | null>(null);
  const [etaSeconds, setEtaSeconds] = useState<number | null>(null);
  const [remainingDistanceMeters, setRemainingDistanceMeters] = useState<
    number | null
  >(null);
  const [isStale, setIsStale] = useState(false);
  const [loading, setLoading] = useState(!!tripId);
  const [error, setError] = useState<string | null>(null);

  const lastUpdateRef = useRef<number>(0);
  const lastEtaCalcRef = useRef<number>(0);
  const etaAbortRef = useRef<AbortController | null>(null);
  const deliveryLatRef = useRef(deliveryLat);
  const deliveryLngRef = useRef(deliveryLng);

  // Keep delivery coords in refs so the main effect doesn't re-subscribe
  useEffect(() => {
    deliveryLatRef.current = deliveryLat;
    deliveryLngRef.current = deliveryLng;
  }, [deliveryLat, deliveryLng]);

  useEffect(() => {
    if (!tripId) {
      return;
    }

    let cancelled = false;

    /**
     * Calculate ETA via OSRM. Throttled to avoid rate limits.
     * Uses AbortController to cancel stale requests.
     */
    async function calculateEta(
      lat: number,
      lng: number,
      speedKmh: number | null,
    ) {
      const dLat = deliveryLatRef.current;
      const dLng = deliveryLngRef.current;
      if (dLat == null || dLng == null) return;

      // Throttle ETA calculations
      const now = Date.now();
      if (now - lastEtaCalcRef.current < ETA_THROTTLE_MS) return;
      lastEtaCalcRef.current = now;

      // Abort any in-flight request
      etaAbortRef.current?.abort();
      const controller = new AbortController();
      etaAbortRef.current = controller;

      try {
        const coords = `${lng},${lat};${dLng},${dLat}`;
        const url = `${OSRM_BASE_URL}/route/v1/driving/${coords}?overview=false`;
        const res = await fetch(url, { signal: controller.signal });

        if (!res.ok || cancelled) return;

        const data = await res.json();
        if (data.code !== "Ok" || !data.routes?.length) return;

        const route = data.routes[0];
        const distanceMeters: number = route.distance;
        const osrmDurationSeconds: number = route.duration;

        if (cancelled) return;

        setRemainingDistanceMeters(distanceMeters);

        // Use rider's actual speed if available and > 5 km/h (moving),
        // otherwise fall back to OSRM's estimated duration
        if (speedKmh && speedKmh > 5) {
          const speedMs = (speedKmh * 1000) / 3600;
          setEtaSeconds(Math.round(distanceMeters / speedMs));
        } else {
          setEtaSeconds(Math.round(osrmDurationSeconds));
        }
      } catch (e: unknown) {
        // Ignore abort errors; other errors are best-effort
        if (e instanceof DOMException && e.name === "AbortError") return;
      }
    }

    async function init() {
      // Fetch trip route data and latest location in parallel
      const [routeResult, locationResult] = await Promise.all([
        getTripRouteData(tripId!),
        getLatestRiderLocation(tripId!),
      ]);

      if (cancelled) return;

      if (routeResult.error) {
        setError(routeResult.error);
        setLoading(false);
        return;
      }

      if (routeResult.data) {
        setTripRoute(routeResult.data);
      }

      if (locationResult.data) {
        setRiderLocation(locationResult.data);
        lastUpdateRef.current = Date.now();

        // Calculate initial ETA (bypasses throttle for first call)
        lastEtaCalcRef.current = 0;
        calculateEta(
          locationResult.data.lat,
          locationResult.data.lng,
          locationResult.data.speedKmh,
        );
      }

      setLoading(false);
    }

    init();

    // Subscribe to Realtime Postgres Changes on rider_location_log
    const supabase = createClient();
    const channel = supabase
      .channel(`trip:${tripId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "rider_location_log",
          filter: `trip_id=eq.${tripId}`,
        },
        (payload) => {
          if (cancelled) return;

          const loc = parseRealtimeLocation(
            payload.new as Record<string, unknown>,
          );
          if (!loc) return;

          setRiderLocation(loc);
          setIsStale(false);
          lastUpdateRef.current = Date.now();

          calculateEta(loc.lat, loc.lng, loc.speedKmh);
        },
      )
      .subscribe((status) => {
        if (
          status === "TIMED_OUT" ||
          status === "CHANNEL_ERROR"
        ) {
          setError("Live tracking connection failed. Try refreshing.");
        }
      });

    // Staleness check: if no update in STALE_THRESHOLD_MS, mark as stale
    const staleTimer = setInterval(() => {
      if (
        lastUpdateRef.current > 0 &&
        Date.now() - lastUpdateRef.current > STALE_THRESHOLD_MS
      ) {
        setIsStale(true);
      }
    }, 5_000);

    return () => {
      cancelled = true;
      etaAbortRef.current?.abort();
      channel.unsubscribe();
      clearInterval(staleTimer);
    };
  }, [tripId]); // Only re-subscribe when tripId changes

  return {
    riderLocation,
    tripRoute,
    etaSeconds,
    remainingDistanceMeters,
    isStale,
    loading,
    error,
  };
}
