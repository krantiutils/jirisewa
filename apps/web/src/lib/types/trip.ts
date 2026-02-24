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
  origin_municipality_id: string | null;
  destination_municipality_id: string | null;
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
  originMunicipalityId: string | null;
  destinationMunicipalityId: string | null;
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
  originMunicipalityId?: string;
  destinationMunicipalityId?: string;
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
 * Supabase returns geography as EWKB hex, WKT, or GeoJSON depending on context.
 */
export function parseGeoPoint(value: string): GeoPoint {
  // Handle GeoJSON format: {"type":"Point","coordinates":[lng,lat]}
  if (value.startsWith("{")) {
    const parsed = JSON.parse(value);
    return { lat: parsed.coordinates[1], lng: parsed.coordinates[0] };
  }

  // Handle WKT: POINT(lng lat)
  const wktMatch = value.match(/POINT\(([^ ]+) ([^ ]+)\)/);
  if (wktMatch) {
    return { lat: parseFloat(wktMatch[2]), lng: parseFloat(wktMatch[1]) };
  }

  // Handle EWKB hex: e.g. "0101000020E6100000..." (Point with SRID 4326)
  if (/^[0-9a-fA-F]+$/.test(value) && value.length >= 50) {
    const buf = Buffer.from(value, "hex");
    // EWKB Point with SRID: 1 byte endian + 4 bytes type + 4 bytes SRID = 9 bytes offset
    const lng = buf.readDoubleLE(9);
    const lat = buf.readDoubleLE(17);
    if (Number.isFinite(lng) && Number.isFinite(lat)) {
      return { lat, lng };
    }
  }

  throw new Error(`Cannot parse geography point: ${value}`);
}

/**
 * Parse a PostGIS LineString to [lat, lng] coordinate pairs for Leaflet.
 * Supabase returns geography as EWKB hex, WKT, or GeoJSON.
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
  const wktMatch = value.match(/LINESTRING\((.+)\)/);
  if (wktMatch) {
    return wktMatch[1].split(",").map((pair) => {
      const [lng, lat] = pair.trim().split(" ").map(Number);
      return [lat, lng] as [number, number];
    });
  }

  // Handle EWKB hex for LineString
  if (/^[0-9a-fA-F]+$/.test(value) && value.length >= 50) {
    try {
      const buf = Buffer.from(value, "hex");
      // EWKB LineString with SRID: 1 endian + 4 type + 4 SRID + 4 numPoints = 13 bytes header
      const numPoints = buf.readUInt32LE(9); // at offset 9 (after endian+type+SRID)
      const coords: [number, number][] = [];
      let offset = 13;
      for (let i = 0; i < numPoints; i++) {
        const lng = buf.readDoubleLE(offset);
        const lat = buf.readDoubleLE(offset + 8);
        coords.push([lat, lng]);
        offset += 16;
      }
      return coords.length > 0 ? coords : null;
    } catch {
      return null;
    }
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
    originMunicipalityId: row.origin_municipality_id ?? null,
    destinationMunicipalityId: row.destination_municipality_id ?? null,
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at),
  };
}
