import type { TripStatus } from "@jirisewa/shared";

/** Geographic point as stored in PostGIS (SRID 4326). */
export interface GeoPoint {
  lat: number;
  lng: number;
}

/** Row shape returned by Supabase for the rider_trips table. */
export interface RiderTrip {
  id: string;
  rider_id: string;
  origin: string; // PostGIS WKT or GeoJSON from Supabase — parsed via helpers
  origin_name: string;
  destination: string;
  destination_name: string;
  route: string | null;
  departure_at: string; // ISO 8601
  available_capacity_kg: number;
  remaining_capacity_kg: number;
  status: TripStatus;
  total_stops: number;
  optimized_route: Record<string, unknown> | null;
  total_distance_km: number | null;
  estimated_duration_minutes: number | null;
  created_at: string;
  updated_at: string;
}

/** Parsed trip with typed geo fields for frontend use. */
export interface Trip {
  id: string;
  riderId: string;
  origin: GeoPoint;
  originName: string;
  destination: GeoPoint;
  destinationName: string;
  routeCoordinates: [number, number][] | null; // [lat, lng] pairs for Leaflet
  departureAt: Date;
  availableCapacityKg: number;
  remainingCapacityKg: number;
  status: TripStatus;
  totalStops: number;
  optimizedRoute: Record<string, unknown> | null;
  totalDistanceKm: number | null;
  estimatedDurationMinutes: number | null;
  createdAt: Date;
  updatedAt: Date;
}

/** Input for creating a new trip. */
export interface CreateTripInput {
  origin: GeoPoint;
  originName: string;
  destination: GeoPoint;
  destinationName: string;
  routeGeoJson: [number, number][] | null; // [lng, lat] GeoJSON coordinate order
  departureAt: string; // ISO 8601
  availableCapacityKg: number;
}

/** Input for updating an existing trip. */
export interface UpdateTripInput {
  origin?: GeoPoint;
  originName?: string;
  destination?: GeoPoint;
  destinationName?: string;
  routeGeoJson?: [number, number][] | null;
  departureAt?: string;
  availableCapacityKg?: number;
}

/**
 * Parse a PostGIS geography point string to GeoPoint.
 * Supabase returns geography as WKT: "POINT(lng lat)" or as GeoJSON.
 */
export function parseGeoPoint(value: string): GeoPoint {
  // Handle GeoJSON format: {"type":"Point","coordinates":[lng,lat]}
  if (value.startsWith("{")) {
    const parsed = JSON.parse(value);
    return { lat: parsed.coordinates[1], lng: parsed.coordinates[0] };
  }

  // Handle WKT: POINT(lng lat)
  const match = value.match(/POINT\(([^ ]+) ([^ ]+)\)/);
  if (match) {
    return { lat: parseFloat(match[2]), lng: parseFloat(match[1]) };
  }

  throw new Error(`Cannot parse geography point: ${value}`);
}

/**
 * Parse a PostGIS LineString to [lat, lng] coordinate pairs for Leaflet.
 * Supabase returns geography as WKT or GeoJSON.
 */
export function parseRouteToLatLng(
  value: string | null,
): [number, number][] | null {
  if (!value) return null;

  // Handle GeoJSON format
  if (value.startsWith("{")) {
    const parsed = JSON.parse(value);
    // GeoJSON is [lng, lat], Leaflet needs [lat, lng]
    return parsed.coordinates.map(([lng, lat]: [number, number]) => [
      lat,
      lng,
    ]);
  }

  // Handle WKT: LINESTRING(lng1 lat1, lng2 lat2, ...)
  const match = value.match(/LINESTRING\((.+)\)/);
  if (match) {
    return match[1].split(",").map((pair) => {
      const [lng, lat] = pair.trim().split(" ").map(Number);
      return [lat, lng] as [number, number];
    });
  }

  return null;
}

/** Convert a RiderTrip row from Supabase into a parsed Trip object. */
export function parseRiderTrip(row: RiderTrip): Trip {
  return {
    id: row.id,
    riderId: row.rider_id,
    origin: parseGeoPoint(row.origin),
    originName: row.origin_name,
    destination: parseGeoPoint(row.destination),
    destinationName: row.destination_name,
    routeCoordinates: parseRouteToLatLng(row.route),
    departureAt: new Date(row.departure_at),
    availableCapacityKg: Number(row.available_capacity_kg),
    remainingCapacityKg: Number(row.remaining_capacity_kg),
    status: row.status,
    totalStops: row.total_stops ?? 0,
    optimizedRoute: row.optimized_route ?? null,
    totalDistanceKm: row.total_distance_km != null ? Number(row.total_distance_km) : null,
    estimatedDurationMinutes: row.estimated_duration_minutes ?? null,
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at),
  };
}
