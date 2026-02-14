"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import { parseGeoPoint, parseRouteToLatLng } from "@/lib/types/trip";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface RiderLocationPoint {
  lat: number;
  lng: number;
  speedKmh: number | null;
  recordedAt: string;
}

export interface TripRouteData {
  tripId: string;
  riderId: string;
  originLat: number;
  originLng: number;
  originName: string;
  destinationLat: number;
  destinationLng: number;
  destinationName: string;
  /** [lat, lng] pairs for Leaflet, converted from GeoJSON [lng, lat] */
  routeCoordinates: [number, number][] | null;
  status: string;
}

/**
 * Safe wrapper: parse PostGIS point, returning null instead of throwing.
 */
function safeParsePoint(
  value: unknown,
): { lat: number; lng: number } | null {
  if (!value || typeof value !== "string") return null;
  try {
    return parseGeoPoint(value);
  } catch {
    return null;
  }
}

/**
 * Safe wrapper: parse PostGIS LineString, returning null instead of throwing.
 */
function safeParseRoute(value: unknown): [number, number][] | null {
  if (!value || typeof value !== "string") return null;
  return parseRouteToLatLng(value);
}

/**
 * Get the latest rider location for a given trip.
 * Used as initial state before the Realtime subscription provides live updates.
 */
export async function getLatestRiderLocation(
  tripId: string,
): Promise<ActionResult<RiderLocationPoint | null>> {
  if (!UUID_RE.test(tripId)) {
    return { error: "Invalid trip ID" };
  }

  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("rider_location_log")
      .select("location, speed_kmh, recorded_at")
      .eq("trip_id", tripId)
      .order("recorded_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error("getLatestRiderLocation error:", error);
      return { error: error.message };
    }

    if (!data) {
      return { data: null };
    }

    const point = safeParsePoint(data.location);
    if (!point) {
      return { data: null };
    }

    return {
      data: {
        lat: point.lat,
        lng: point.lng,
        speedKmh: data.speed_kmh,
        recordedAt: data.recorded_at,
      },
    };
  } catch (err) {
    console.error("getLatestRiderLocation unexpected error:", err);
    return { error: "Failed to get rider location" };
  }
}

/**
 * Get trip route data needed for the tracking map.
 * Fetches the rider_trip row and parses geography fields.
 */
export async function getTripRouteData(
  tripId: string,
): Promise<ActionResult<TripRouteData>> {
  if (!UUID_RE.test(tripId)) {
    return { error: "Invalid trip ID" };
  }

  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("rider_trips")
      .select(
        "id, rider_id, origin, origin_name, destination, destination_name, route, status",
      )
      .eq("id", tripId)
      .single();

    if (error) {
      console.error("getTripRouteData error:", error);
      return { error: error.message };
    }

    const origin = safeParsePoint(data.origin);
    const destination = safeParsePoint(data.destination);

    if (!origin || !destination) {
      return { error: "Invalid trip geography data" };
    }

    return {
      data: {
        tripId: data.id,
        riderId: data.rider_id,
        originLat: origin.lat,
        originLng: origin.lng,
        originName: data.origin_name,
        destinationLat: destination.lat,
        destinationLng: destination.lng,
        destinationName: data.destination_name,
        routeCoordinates: safeParseRoute(data.route),
        status: data.status,
      },
    };
  } catch (err) {
    console.error("getTripRouteData unexpected error:", err);
    return { error: "Failed to get trip route data" };
  }
}
