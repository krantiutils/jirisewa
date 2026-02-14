import type { Database } from "@/lib/supabase/types";

export type OrderPingRow = Database["public"]["Tables"]["order_pings"]["Row"];
export type PingStatusType = Database["public"]["Enums"]["ping_status"];

/** A pickup location snapshot stored in the ping's pickup_locations jsonb. */
export interface PingLocation {
  lat: number;
  lng: number;
  farmerName: string;
}

/** Parsed ping for frontend consumption. */
export interface OrderPing {
  id: string;
  orderId: string;
  riderId: string;
  tripId: string;
  pickupLocations: PingLocation[];
  deliveryLocation: { lat: number; lng: number; address?: string };
  totalWeightKg: number;
  estimatedEarnings: number;
  detourDistanceM: number;
  status: PingStatusType;
  expiresAt: Date;
  createdAt: Date;
}

/** Row returned by the find_eligible_riders RPC. */
export interface EligibleRider {
  trip_id: string;
  rider_id: string;
  remaining_capacity_kg: number;
  detour_distance_m: number;
}

/** Result of accepting a ping. */
export interface AcceptPingResult {
  orderId: string;
  tripId: string;
  routeUpdated: boolean;
}

/** Parse a raw OrderPingRow into a frontend OrderPing. */
export function parseOrderPing(row: OrderPingRow): OrderPing {
  return {
    id: row.id,
    orderId: row.order_id,
    riderId: row.rider_id,
    tripId: row.trip_id,
    pickupLocations: (row.pickup_locations ?? []) as unknown as PingLocation[],
    deliveryLocation: row.delivery_location as unknown as {
      lat: number;
      lng: number;
      address?: string;
    },
    totalWeightKg: Number(row.total_weight_kg),
    estimatedEarnings: Number(row.estimated_earnings),
    detourDistanceM: Number(row.detour_distance_m),
    status: row.status,
    expiresAt: new Date(row.expires_at),
    createdAt: new Date(row.created_at),
  };
}
