"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { listPendingPings } from "@/lib/actions/pings";
import type { OrderPing, OrderPingRow } from "@/lib/types/ping";
import { parseOrderPing } from "@/lib/types/ping";

// TODO: Replace hardcoded rider ID with authenticated user once auth is implemented
const DEMO_RIDER_ID = "00000000-0000-0000-0000-000000000000";

interface UsePingSubscriptionReturn {
  pings: OrderPing[];
  loading: boolean;
  error: string | null;
  removePing: (pingId: string) => void;
}

/**
 * Real-time subscription hook for order pings.
 *
 * - Loads initial pending pings on mount
 * - Subscribes to postgres_changes on order_pings filtered by rider_id
 * - Handles INSERT (new ping) and UPDATE (status change)
 * - Client-side countdown timer removes expired pings from state
 */
export function usePingSubscription(): UsePingSubscriptionReturn {
  const [pings, setPings] = useState<OrderPing[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const removePing = useCallback((pingId: string) => {
    setPings((prev) => prev.filter((p) => p.id !== pingId));
  }, []);

  // Load initial pings
  useEffect(() => {
    async function loadInitial() {
      setLoading(true);
      const result = await listPendingPings();
      if (result.error) {
        setError(result.error);
      } else if (result.data) {
        setPings(result.data);
      }
      setLoading(false);
    }

    loadInitial();
  }, []);

  // Subscribe to realtime changes
  useEffect(() => {
    const supabase = createClient();

    const channel = supabase
      .channel("order-pings-realtime")
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "order_pings",
          filter: `rider_id=eq.${DEMO_RIDER_ID}`,
        },
        (payload) => {
          const newPing = parseOrderPing(payload.new as OrderPingRow);
          // Only add if still pending and not expired
          if (newPing.status === "pending" && newPing.expiresAt > new Date()) {
            setPings((prev) => {
              // Avoid duplicates
              if (prev.some((p) => p.id === newPing.id)) return prev;
              return [newPing, ...prev];
            });
          }
        },
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "order_pings",
          filter: `rider_id=eq.${DEMO_RIDER_ID}`,
        },
        (payload) => {
          const updated = parseOrderPing(payload.new as OrderPingRow);
          if (updated.status !== "pending") {
            // Ping was accepted/declined/expired — remove from active list
            setPings((prev) => prev.filter((p) => p.id !== updated.id));
          }
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  // Client-side countdown timer: remove expired pings every second
  useEffect(() => {
    timerRef.current = setInterval(() => {
      const now = new Date();
      setPings((prev) => prev.filter((p) => p.expiresAt > now));
    }, 1000);

    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, []);

  return { pings, loading, error, removePing };
}
