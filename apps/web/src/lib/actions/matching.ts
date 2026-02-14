"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import type { TripMatchResult } from "@/lib/types/order";

/**
 * Maximum distance (meters) a pickup or delivery point can be from a trip route
 * to be considered "along the route". 5km is generous for Nepal's rural roads.
 */
const MAX_DETOUR_METERS = 5000;

interface MatchInput {
  /** Pickup locations: one per unique farmer. */
  pickupPoints: { farmerId: string; lat: number; lng: number }[];
  /** Consumer delivery location. */
  deliveryLat: number;
  deliveryLng: number;
  /** Total weight of items in the order. */
  totalWeightKg: number;
}

/**
 * Find rider trips that can serve a multi-farmer order.
 *
 * A trip "covers" a pickup point if that point is within MAX_DETOUR_METERS
 * of the trip's route (PostGIS ST_DWithin on geography LineString).
 *
 * Returns trips sorted by: covers-all-pickups first, then by rider rating desc.
 */
export async function findMatchingTrips(
  input: MatchInput,
): Promise<ActionResult<TripMatchResult[]>> {
  try {
    if (input.pickupPoints.length === 0) {
      return { error: "No pickup points provided" };
    }

    const supabase = createServiceRoleClient();

    // Find scheduled trips with enough remaining capacity and route data
    const { data: trips, error: tripError } = await supabase
      .from("rider_trips")
      .select(
        `
        id, rider_id, route, departure_at, origin_name, destination_name,
        remaining_capacity_kg,
        rider:users!rider_trips_rider_id_fkey(name, rating_avg)
      `,
      )
      .eq("status", "scheduled")
      .gte("remaining_capacity_kg", input.totalWeightKg)
      .not("route", "is", null);

    if (tripError) {
      console.error("findMatchingTrips: trip query error:", tripError);
      return { error: "Failed to search for trips" };
    }

    if (!trips || trips.length === 0) {
      return { data: [] };
    }

    // For each trip, check which pickup points and the delivery point
    // are within MAX_DETOUR_METERS of the route using PostGIS ST_DWithin.
    // We do this per-trip using RPC or raw SQL via supabase.rpc.
    // Since we can't use RPC without defining it, we'll check in-app
    // by using individual ST_DWithin queries per trip+point pair.
    //
    // More efficient approach: use a single query that cross-joins trips with points.
    // But Supabase JS client doesn't support raw SQL directly. So we batch.

    const results: TripMatchResult[] = [];

    for (const trip of trips) {
      const rider = Array.isArray(trip.rider) ? trip.rider[0] : trip.rider;

      // Check delivery point proximity to route
      const deliveryNear = await isPointNearRoute(
        supabase,
        trip.id,
        input.deliveryLat,
        input.deliveryLng,
      );

      if (!deliveryNear) continue;

      // Check each pickup point
      const coveredFarmerIds: string[] = [];
      for (const pickup of input.pickupPoints) {
        const near = await isPointNearRoute(
          supabase,
          trip.id,
          pickup.lat,
          pickup.lng,
        );
        if (near) {
          coveredFarmerIds.push(pickup.farmerId);
        }
      }

      if (coveredFarmerIds.length === 0) continue;

      results.push({
        tripId: trip.id,
        riderId: trip.rider_id,
        riderName: rider?.name ?? "Unknown",
        riderRating: Number(rider?.rating_avg ?? 0),
        departureAt: trip.departure_at,
        originName: trip.origin_name,
        destinationName: trip.destination_name,
        remainingCapacityKg: Number(trip.remaining_capacity_kg),
        coveredFarmerIds,
        coversAllPickups: coveredFarmerIds.length === input.pickupPoints.length,
      });
    }

    // Sort: trips covering all pickups first, then by rating desc
    results.sort((a, b) => {
      if (a.coversAllPickups !== b.coversAllPickups) {
        return a.coversAllPickups ? -1 : 1;
      }
      return b.riderRating - a.riderRating;
    });

    return { data: results };
  } catch (err) {
    console.error("findMatchingTrips unexpected error:", err);
    return { error: "Failed to find matching trips" };
  }
}

/**
 * Check if a point is within MAX_DETOUR_METERS of a trip's route using PostGIS.
 * Uses a raw filter with ST_DWithin on the rider_trips table.
 */
async function isPointNearRoute(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  supabase: any,
  tripId: string,
  lat: number,
  lng: number,
): Promise<boolean> {
  const pointWkt = `SRID=4326;POINT(${lng} ${lat})`;

  // check_point_near_route returns 0 when trip has no route or point is too far
  const { data: rpcResult, error: spatialError } = await supabase
    .rpc("check_point_near_route", {
      trip_id: tripId,
      point_wkt: pointWkt,
      max_distance_meters: MAX_DETOUR_METERS,
    });

  if (spatialError) {
    console.error("isPointNearRoute: RPC error (may need migration):", spatialError.message);
    return false;
  }

  return (rpcResult ?? 0) > 0;
}

/**
 * Compute optimal pickup sequence for a multi-farmer order based on
 * the rider's route direction. Items from farmers closer to the trip origin
 * get lower sequence numbers.
 *
 * Uses ST_LineLocatePoint to find where each pickup falls along the route.
 */
export async function computePickupSequence(
  tripId: string,
  farmerPoints: { farmerId: string; lat: number; lng: number }[],
): Promise<ActionResult<{ farmerId: string; sequence: number }[]>> {
  try {
    if (farmerPoints.length === 0) {
      return { data: [] };
    }

    if (farmerPoints.length === 1) {
      return { data: [{ farmerId: farmerPoints[0].farmerId, sequence: 1 }] };
    }

    const supabase = createServiceRoleClient();

    // Get the fraction along the route for each farmer point
    const fractions: { farmerId: string; fraction: number }[] = [];

    for (const point of farmerPoints) {
      const pointWkt = `SRID=4326;POINT(${point.lng} ${point.lat})`;

      const { data, error } = await supabase.rpc("locate_point_on_route", {
        trip_id: tripId,
        point_wkt: pointWkt,
      });

      if (error) {
        console.error("computePickupSequence: RPC error:", error.message);
        // Fallback: assign based on input order
        return {
          data: farmerPoints.map((p, idx) => ({
            farmerId: p.farmerId,
            sequence: idx + 1,
          })),
        };
      }

      fractions.push({
        farmerId: point.farmerId,
        fraction: Number(data ?? 0),
      });
    }

    // Sort by fraction (0 = trip origin, 1 = trip destination)
    fractions.sort((a, b) => a.fraction - b.fraction);

    return {
      data: fractions.map((f, idx) => ({
        farmerId: f.farmerId,
        sequence: idx + 1,
      })),
    };
  } catch (err) {
    console.error("computePickupSequence unexpected error:", err);
    return { error: "Failed to compute pickup sequence" };
  }
}
