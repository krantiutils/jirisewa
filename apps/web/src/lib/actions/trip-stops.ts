"use server";

import { StopType } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import type {
  TripStop,
  TripStopRow,
  CreateTripStopInput,
} from "@/lib/types/trip-stop";
import { parseTripStop } from "@/lib/types/trip-stop";
import { optimizeRoute, type RouteStop } from "@/lib/route-optimizer";
import type { OptimizedRoute } from "@/lib/types/trip-stop";

const DEMO_RIDER_ID = "00000000-0000-0000-0000-000000000000";

function pointToWkt(lat: number, lng: number): string {
  return `POINT(${lng} ${lat})`;
}

/**
 * List all stops for a trip, ordered by sequence.
 */
export async function listTripStops(
  tripId: string,
): Promise<ActionResult<TripStop[]>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("trip_stops")
      .select("*")
      .eq("trip_id", tripId)
      .order("sequence_order", { ascending: true });

    if (error) {
      console.error("listTripStops error:", error);
      return { error: error.message };
    }

    return {
      data: (data as TripStopRow[]).map(parseTripStop),
    };
  } catch (err) {
    console.error("listTripStops unexpected error:", err);
    return { error: "Failed to list trip stops" };
  }
}

/**
 * Create a new stop for a trip.
 */
export async function createTripStop(
  input: CreateTripStopInput,
): Promise<ActionResult<TripStop>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("trip_stops")
      .insert({
        trip_id: input.tripId,
        stop_type: input.stopType,
        location: pointToWkt(input.lat, input.lng),
        address: input.address ?? null,
        address_ne: input.addressNe ?? null,
        sequence_order: input.sequenceOrder,
        order_item_ids: input.orderItemIds,
      })
      .select()
      .single();

    if (error) {
      console.error("createTripStop error:", error);
      return { error: error.message };
    }

    return { data: parseTripStop(data as TripStopRow) };
  } catch (err) {
    console.error("createTripStop unexpected error:", err);
    return { error: "Failed to create trip stop" };
  }
}

/**
 * Mark a trip stop as completed (arrived + time recorded).
 */
export async function completeTripStop(
  stopId: string,
): Promise<ActionResult<TripStop>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("trip_stops")
      .update({
        completed: true,
        actual_arrival: new Date().toISOString(),
      })
      .eq("id", stopId)
      .select()
      .single();

    if (error) {
      console.error("completeTripStop error:", error);
      return { error: error.message };
    }

    return { data: parseTripStop(data as TripStopRow) };
  } catch (err) {
    console.error("completeTripStop unexpected error:", err);
    return { error: "Failed to complete trip stop" };
  }
}

/**
 * Run route optimization for an existing trip's stops.
 * Fetches the trip's current stops, optimizes the sequence via OSRM,
 * then updates stop ordering and trip metadata.
 */
export async function optimizeTripRoute(
  tripId: string,
): Promise<ActionResult<OptimizedRoute>> {
  try {
    const supabase = createServiceRoleClient();

    // Fetch the trip
    const { data: trip, error: tripError } = await supabase
      .from("rider_trips")
      .select("id, rider_id, origin, destination, status")
      .eq("id", tripId)
      .single();

    if (tripError || !trip) {
      return { error: "Trip not found" };
    }

    if (trip.rider_id !== DEMO_RIDER_ID) {
      return { error: "You can only optimize your own trips" };
    }

    // Parse origin and destination
    const originGeo = trip.origin as unknown as {
      type: string;
      coordinates: [number, number];
    };
    const destGeo = trip.destination as unknown as {
      type: string;
      coordinates: [number, number];
    };
    const origin = { lng: originGeo.coordinates[0], lat: originGeo.coordinates[1] };
    const dest = { lng: destGeo.coordinates[0], lat: destGeo.coordinates[1] };

    // Fetch current stops
    const { data: stopsData, error: stopsError } = await supabase
      .from("trip_stops")
      .select("*")
      .eq("trip_id", tripId)
      .order("sequence_order", { ascending: true });

    if (stopsError) {
      return { error: stopsError.message };
    }

    const stops = (stopsData as TripStopRow[]).map(parseTripStop);
    if (stops.length === 0) {
      return { error: "No stops to optimize" };
    }

    // Build RouteStop array for the optimizer
    const routeStops: RouteStop[] = stops.map((s) => ({
      lat: s.location.lat,
      lng: s.location.lng,
      stopType: s.stopType,
      address: s.address ?? undefined,
      orderItemIds: s.orderItemIds,
    }));

    const optimized = await optimizeRoute(origin, routeStops, dest);
    if (!optimized) {
      return { error: "Route optimization failed" };
    }

    // Update stop sequence_order and estimated_arrival based on optimization
    const departureAt = new Date(); // Use now as baseline for ETA
    for (let i = 0; i < optimized.stops.length; i++) {
      const optStop = optimized.stops[i];
      // Match by location (lat/lng) to find the correct trip_stop record
      const matchingStop = stops.find(
        (s) =>
          Math.abs(s.location.lat - optStop.lat) < 0.0001 &&
          Math.abs(s.location.lng - optStop.lng) < 0.0001,
      );

      if (matchingStop) {
        const eta = new Date(
          departureAt.getTime() + optStop.estimatedArrivalSeconds * 1000,
        );
        await supabase
          .from("trip_stops")
          .update({
            sequence_order: i,
            estimated_arrival: eta.toISOString(),
          })
          .eq("id", matchingStop.id);
      }
    }

    // Update trip metadata
    const routeWktPoints = optimized.routeGeometry
      .map(([lng, lat]) => `${lng} ${lat}`)
      .join(",");
    const routeWkt = `LINESTRING(${routeWktPoints})`;

    await supabase
      .from("rider_trips")
      .update({
        route: routeWkt,
        total_stops: optimized.stops.length,
        optimized_route: optimized as unknown as Record<string, unknown>,
        total_distance_km: optimized.totalDistanceKm,
        estimated_duration_minutes: optimized.totalDurationMinutes,
      })
      .eq("id", tripId);

    return { data: optimized };
  } catch (err) {
    console.error("optimizeTripRoute unexpected error:", err);
    return { error: "Failed to optimize route" };
  }
}

/**
 * Create stops from matched orders and run optimization.
 * Called when building stops from existing order data on a trip.
 */
export async function buildStopsFromOrders(
  tripId: string,
): Promise<ActionResult<TripStop[]>> {
  try {
    const supabase = createServiceRoleClient();

    // Fetch matched orders for this trip
    const { data: orders, error: ordersError } = await supabase
      .from("orders")
      .select(`
        id,
        delivery_location,
        delivery_address,
        order_items:order_items(
          id,
          farmer_id,
          pickup_location,
          pickup_sequence
        )
      `)
      .eq("rider_trip_id", tripId)
      .in("status", ["matched", "picked_up", "in_transit"]);

    if (ordersError) {
      return { error: ordersError.message };
    }

    if (!orders || orders.length === 0) {
      return { data: [] };
    }

    // Delete existing stops for this trip (we're rebuilding)
    await supabase.from("trip_stops").delete().eq("trip_id", tripId);

    // Build stops from order data
    const stopInserts: {
      trip_id: string;
      stop_type: StopType;
      location: string;
      address: string | null;
      sequence_order: number;
      order_item_ids: string[];
    }[] = [];

    let seq = 0;
    const seenPickupLocations = new Map<string, number>(); // dedup by location

    for (const order of orders) {
      const items = order.order_items as {
        id: string;
        farmer_id: string;
        pickup_location: { type: string; coordinates: [number, number] } | null;
        pickup_sequence: number;
      }[];

      // Group items by farmer for pickup stops
      const farmerItems = new Map<string, string[]>();
      const farmerLocations = new Map<
        string,
        { type: string; coordinates: [number, number] }
      >();

      for (const item of items) {
        const fid = item.farmer_id;
        const group = farmerItems.get(fid) ?? [];
        group.push(item.id);
        farmerItems.set(fid, group);
        if (item.pickup_location) {
          farmerLocations.set(fid, item.pickup_location);
        }
      }

      // Create pickup stops per farmer
      for (const [farmerId, itemIds] of farmerItems) {
        const loc = farmerLocations.get(farmerId);
        if (!loc || loc.type !== "Point") continue;

        const locKey = `${loc.coordinates[0].toFixed(6)},${loc.coordinates[1].toFixed(6)}`;
        if (seenPickupLocations.has(locKey)) {
          // Merge items into existing pickup stop
          const existingIdx = seenPickupLocations.get(locKey)!;
          stopInserts[existingIdx].order_item_ids.push(...itemIds);
          continue;
        }

        seenPickupLocations.set(locKey, stopInserts.length);
        stopInserts.push({
          trip_id: tripId,
          stop_type: StopType.Pickup,
          location: pointToWkt(loc.coordinates[1], loc.coordinates[0]),
          address: null,
          sequence_order: seq++,
          order_item_ids: itemIds,
        });
      }

      // Create delivery stop
      const delivLoc = order.delivery_location as {
        type: string;
        coordinates: [number, number];
      } | null;
      if (delivLoc && delivLoc.type === "Point") {
        stopInserts.push({
          trip_id: tripId,
          stop_type: StopType.Delivery,
          location: pointToWkt(
            delivLoc.coordinates[1],
            delivLoc.coordinates[0],
          ),
          address: order.delivery_address,
          sequence_order: seq++,
          order_item_ids: items.map((i) => i.id),
        });
      }
    }

    if (stopInserts.length === 0) {
      return { data: [] };
    }

    const { data: insertedStops, error: insertError } = await supabase
      .from("trip_stops")
      .insert(stopInserts)
      .select();

    if (insertError) {
      return { error: insertError.message };
    }

    return {
      data: (insertedStops as TripStopRow[]).map(parseTripStop),
    };
  } catch (err) {
    console.error("buildStopsFromOrders unexpected error:", err);
    return { error: "Failed to build stops from orders" };
  }
}
