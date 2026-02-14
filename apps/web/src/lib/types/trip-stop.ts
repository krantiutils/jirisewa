import type { StopType } from "@jirisewa/shared";

/** Row shape returned by Supabase for the trip_stops table. */
export interface TripStopRow {
  id: string;
  trip_id: string;
  stop_type: StopType;
  location: string; // PostGIS geography
  address: string | null;
  address_ne: string | null;
  sequence_order: number;
  estimated_arrival: string | null; // ISO 8601
  actual_arrival: string | null;
  order_item_ids: string[];
  completed: boolean;
  created_at: string;
  updated_at: string;
}

/** Parsed trip stop for frontend use. */
export interface TripStop {
  id: string;
  tripId: string;
  stopType: StopType;
  location: { lat: number; lng: number };
  address: string | null;
  addressNe: string | null;
  sequenceOrder: number;
  estimatedArrival: Date | null;
  actualArrival: Date | null;
  orderItemIds: string[];
  completed: boolean;
}

/** Input for creating a new trip stop. */
export interface CreateTripStopInput {
  tripId: string;
  stopType: StopType;
  lat: number;
  lng: number;
  address?: string;
  addressNe?: string;
  sequenceOrder: number;
  orderItemIds: string[];
}

/** Result of route optimization: ordered stops with route geometry. */
export interface OptimizedRoute {
  stops: {
    lat: number;
    lng: number;
    stopType: StopType;
    address?: string;
    orderItemIds: string[];
    estimatedArrivalSeconds: number; // seconds from trip start
  }[];
  totalDistanceKm: number;
  totalDurationMinutes: number;
  routeGeometry: [number, number][]; // [lng, lat] GeoJSON order
  legs: {
    distanceKm: number;
    durationMinutes: number;
  }[];
}

export function parseTripStop(row: TripStopRow): TripStop {
  let location = { lat: 0, lng: 0 };

  if (typeof row.location === "string") {
    if (row.location.startsWith("{")) {
      const parsed = JSON.parse(row.location);
      location = { lat: parsed.coordinates[1], lng: parsed.coordinates[0] };
    } else {
      const match = row.location.match(/POINT\(([^ ]+) ([^ ]+)\)/);
      if (match) {
        location = { lat: parseFloat(match[2]), lng: parseFloat(match[1]) };
      }
    }
  } else {
    const loc = row.location as unknown as {
      type: string;
      coordinates: [number, number];
    };
    if (loc?.type === "Point" && Array.isArray(loc.coordinates)) {
      location = { lng: loc.coordinates[0], lat: loc.coordinates[1] };
    }
  }

  return {
    id: row.id,
    tripId: row.trip_id,
    stopType: row.stop_type,
    location,
    address: row.address,
    addressNe: row.address_ne,
    sequenceOrder: row.sequence_order,
    estimatedArrival: row.estimated_arrival
      ? new Date(row.estimated_arrival)
      : null,
    actualArrival: row.actual_arrival ? new Date(row.actual_arrival) : null,
    orderItemIds: row.order_item_ids ?? [],
    completed: row.completed,
  };
}
