"use server";

import {
  OrderStatus,
  PingStatus,
  StopType,
  PING_EXPIRY_MS,
  MAX_DETOUR_M,
  MAX_DETOUR_PERCENTAGE,
  MAX_PINGS_PER_ORDER,
  OSRM_BASE_URL,
} from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import type {
  OrderPingRow,
  OrderPing,
  EligibleRider,
  AcceptPingResult,
  PingLocation,
} from "@/lib/types/ping";
import { parseOrderPing } from "@/lib/types/ping";

// TODO: Replace hardcoded rider ID with authenticated user once auth is implemented
const DEMO_RIDER_ID = "00000000-0000-0000-0000-000000000000";

/**
 * Find eligible riders for an order and create pings.
 * Called after order placement. Non-fatal — order exists regardless.
 */
export async function findAndPingRiders(
  orderId: string,
): Promise<ActionResult<{ pingedCount: number }>> {
  try {
    const supabase = createServiceRoleClient();

    // 1. Call the PostGIS RPC to find eligible riders
    const { data: eligibleRiders, error: rpcError } = await supabase
      .rpc("find_eligible_riders", {
        p_order_id: orderId,
        p_max_detour_m: MAX_DETOUR_M,
        p_max_results: MAX_PINGS_PER_ORDER,
      });

    if (rpcError) {
      console.error("findAndPingRiders: RPC error:", rpcError);
      return { error: rpcError.message };
    }

    const riders = (eligibleRiders ?? []) as EligibleRider[];
    if (riders.length === 0) {
      return { data: { pingedCount: 0 } };
    }

    // 2. Fetch order details for ping snapshots
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, delivery_location, delivery_address, delivery_fee, total_price")
      .eq("id", orderId)
      .single();

    if (orderError || !order) {
      console.error("findAndPingRiders: failed to fetch order:", orderError);
      return { error: "Order not found" };
    }

    // 3. Fetch order items with farmer names for pickup location snapshots
    const { data: items, error: itemsError } = await supabase
      .from("order_items")
      .select(`
        quantity_kg,
        pickup_location,
        farmer:users!order_items_farmer_id_fkey(name)
      `)
      .eq("order_id", orderId);

    if (itemsError) {
      console.error("findAndPingRiders: failed to fetch items:", itemsError);
      return { error: "Failed to fetch order items" };
    }

    // Build pickup locations snapshot
    const pickupLocations: PingLocation[] = [];
    let totalWeightKg = 0;

    for (const item of items ?? []) {
      totalWeightKg += Number(item.quantity_kg);
      if (item.pickup_location) {
        const loc = item.pickup_location as { type: string; coordinates: [number, number] };
        if (loc.type === "Point" && Array.isArray(loc.coordinates)) {
          const farmer = Array.isArray(item.farmer) ? item.farmer[0] : item.farmer;
          pickupLocations.push({
            lng: loc.coordinates[0],
            lat: loc.coordinates[1],
            farmerName: farmer?.name ?? "Unknown",
          });
        }
      }
    }

    // Build delivery location snapshot
    const deliveryLoc = order.delivery_location as { type: string; coordinates: [number, number] } | null;
    let deliverySnapshot: { lat: number; lng: number; address?: string };
    if (deliveryLoc && deliveryLoc.type === "Point" && Array.isArray(deliveryLoc.coordinates)) {
      deliverySnapshot = {
        lng: deliveryLoc.coordinates[0],
        lat: deliveryLoc.coordinates[1],
        address: order.delivery_address,
      };
    } else {
      deliverySnapshot = { lat: 0, lng: 0, address: order.delivery_address };
    }

    // Estimated earnings = delivery fee (rider's cut)
    const estimatedEarnings = Number(order.delivery_fee ?? 0);

    // 4. Build ping rows
    const expiresAt = new Date(Date.now() + PING_EXPIRY_MS).toISOString();

    const pingRows = riders.map((rider) => ({
      order_id: orderId,
      rider_id: rider.rider_id,
      trip_id: rider.trip_id,
      pickup_locations: pickupLocations as unknown as Record<string, unknown>[],
      delivery_location: deliverySnapshot as unknown as Record<string, unknown>,
      total_weight_kg: totalWeightKg,
      estimated_earnings: estimatedEarnings,
      detour_distance_m: Number(rider.detour_distance_m),
      status: PingStatus.Pending as const,
      expires_at: expiresAt,
    }));

    // 5. Batch insert pings
    const { error: insertError } = await supabase
      .from("order_pings")
      .insert(pingRows);

    if (insertError) {
      console.error("findAndPingRiders: failed to insert pings:", insertError);
      return { error: insertError.message };
    }

    return { data: { pingedCount: pingRows.length } };
  } catch (err) {
    console.error("findAndPingRiders unexpected error:", err);
    return { error: "Failed to find and ping riders" };
  }
}

/**
 * Rider accepts a ping — first-accept-wins atomicity via orders WHERE status='pending'.
 */
export async function acceptPing(
  pingId: string,
): Promise<ActionResult<AcceptPingResult>> {
  try {
    const supabase = createServiceRoleClient();

    // 1. Fetch the ping and verify ownership + status + expiry
    const { data: ping, error: pingError } = await supabase
      .from("order_pings")
      .select("*")
      .eq("id", pingId)
      .single();

    if (pingError || !ping) {
      return { error: "Ping not found" };
    }

    if (ping.rider_id !== DEMO_RIDER_ID) {
      return { error: "You can only accept your own pings" };
    }

    if (ping.status !== PingStatus.Pending) {
      return { error: "This ping has already been responded to" };
    }

    if (new Date(ping.expires_at) < new Date()) {
      // Mark as expired
      await supabase
        .from("order_pings")
        .update({ status: PingStatus.Expired })
        .eq("id", pingId);
      return { error: "This ping has expired" };
    }

    // 2. Atomic lock: UPDATE orders WHERE status='pending' RETURNING id
    //    If two riders race, only one gets a RETURNING row
    const { data: matchedOrder, error: matchError } = await supabase
      .from("orders")
      .update({
        status: OrderStatus.Matched,
        rider_id: ping.rider_id,
        rider_trip_id: ping.trip_id,
      })
      .eq("id", ping.order_id)
      .eq("status", OrderStatus.Pending)
      .select("id")
      .single();

    if (matchError || !matchedOrder) {
      // Race condition — another rider got it first
      await supabase
        .from("order_pings")
        .update({
          status: PingStatus.Declined,
          responded_at: new Date().toISOString(),
        })
        .eq("id", pingId);
      return { error: "This order has already been matched to another rider" };
    }

    // 3. Mark this ping as accepted
    const { error: acceptError } = await supabase
      .from("order_pings")
      .update({
        status: PingStatus.Accepted,
        responded_at: new Date().toISOString(),
      })
      .eq("id", pingId);

    if (acceptError) {
      console.error("acceptPing: failed to update ping status:", acceptError);
      // Non-fatal — the order is already matched
    }

    // 4. Expire all other pending pings for this order
    const { error: expireError } = await supabase
      .from("order_pings")
      .update({ status: PingStatus.Expired })
      .eq("order_id", ping.order_id)
      .eq("status", PingStatus.Pending)
      .neq("id", pingId);

    if (expireError) {
      console.error("acceptPing: failed to expire other pings:", expireError);
    }

    // 5. Deduct remaining capacity on the trip
    const { data: trip, error: tripFetchError } = await supabase
      .from("rider_trips")
      .select("remaining_capacity_kg")
      .eq("id", ping.trip_id)
      .single();

    if (!tripFetchError && trip) {
      const newCapacity = Math.max(
        0,
        Number(trip.remaining_capacity_kg) - Number(ping.total_weight_kg),
      );
      await supabase
        .from("rider_trips")
        .update({ remaining_capacity_kg: newCapacity })
        .eq("id", ping.trip_id);
    }

    // 6. Create trip_stops for the new pickup/delivery locations
    const pickupLocations = ping.pickup_locations as unknown as PingLocation[];
    const deliveryLocation = ping.delivery_location as unknown as { lat: number; lng: number; address?: string };

    try {
      // Get current max sequence_order
      const { data: existingStops } = await supabase
        .from("trip_stops")
        .select("sequence_order")
        .eq("trip_id", ping.trip_id)
        .order("sequence_order", { ascending: false })
        .limit(1);

      let nextSeq = (existingStops?.[0]?.sequence_order ?? -1) + 1;

      // Insert pickup stops
      for (const pl of pickupLocations) {
        await supabase.from("trip_stops").insert({
          trip_id: ping.trip_id,
          stop_type: StopType.Pickup,
          location: `POINT(${pl.lng} ${pl.lat})`,
          address: pl.farmerName ?? null,
          sequence_order: nextSeq++,
          order_item_ids: [],
        });
      }

      // Insert delivery stop
      await supabase.from("trip_stops").insert({
        trip_id: ping.trip_id,
        stop_type: StopType.Delivery,
        location: `POINT(${deliveryLocation.lng} ${deliveryLocation.lat})`,
        address: deliveryLocation.address ?? null,
        sequence_order: nextSeq,
        order_item_ids: [],
      });
    } catch (stopErr) {
      console.error("acceptPing: failed to create trip stops:", stopErr);
    }

    // 7. Recalculate and optimize route via OSRM (non-fatal)
    let routeUpdated = false;
    try {
      routeUpdated = await recalculateRouteWithStops(
        supabase,
        ping.trip_id,
        pickupLocations,
        deliveryLocation,
      );
    } catch (routeErr) {
      console.error("acceptPing: route recalculation failed:", routeErr);
    }

    // 8. Add rider to the order's chat conversation (3-way chat)
    try {
      const { addRiderToConversation } = await import("@/lib/actions/chat");
      await addRiderToConversation(ping.order_id, ping.rider_id);
    } catch (chatErr) {
      // Non-fatal - chat is optional
      console.error("acceptPing: failed to add rider to chat:", chatErr);
    }

    return {
      data: {
        orderId: ping.order_id,
        tripId: ping.trip_id,
        routeUpdated,
      },
    };
  } catch (err) {
    console.error("acceptPing unexpected error:", err);
    return { error: "Failed to accept ping" };
  }
}

/**
 * Rider declines a ping.
 */
export async function declinePing(
  pingId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: ping, error: pingError } = await supabase
      .from("order_pings")
      .select("id, rider_id, status")
      .eq("id", pingId)
      .single();

    if (pingError || !ping) {
      return { error: "Ping not found" };
    }

    if (ping.rider_id !== DEMO_RIDER_ID) {
      return { error: "You can only decline your own pings" };
    }

    if (ping.status !== PingStatus.Pending) {
      return { error: "This ping has already been responded to" };
    }

    const { error } = await supabase
      .from("order_pings")
      .update({
        status: PingStatus.Declined,
        responded_at: new Date().toISOString(),
      })
      .eq("id", pingId);

    if (error) {
      console.error("declinePing error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("declinePing unexpected error:", err);
    return { error: "Failed to decline ping" };
  }
}

/**
 * List pending (non-expired) pings for the current rider.
 * Used for initial page-load hydration before realtime takes over.
 */
export async function listPendingPings(): Promise<ActionResult<OrderPing[]>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("order_pings")
      .select("*")
      .eq("rider_id", DEMO_RIDER_ID)
      .eq("status", PingStatus.Pending)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false });

    if (error) {
      console.error("listPendingPings error:", error);
      return { error: error.message };
    }

    const pings = (data as OrderPingRow[]).map(parseOrderPing);
    return { data: pings };
  } catch (err) {
    console.error("listPendingPings unexpected error:", err);
    return { error: "Failed to list pending pings" };
  }
}

/**
 * Recalculate the trip route via OSRM including new pickup/delivery stops.
 *
 * Builds waypoints: current_position → pickups → delivery → trip_destination.
 * Checks detour threshold (MAX_DETOUR_PERCENTAGE) and logs a warning if exceeded.
 * Updates rider_trips with new route, distance, and duration metadata.
 */
async function recalculateRouteWithStops(
  supabase: ReturnType<typeof createServiceRoleClient>,
  tripId: string,
  pickupLocations: PingLocation[],
  deliveryLocation: { lat: number; lng: number },
): Promise<boolean> {
  // Get the trip's current data
  const { data: trip, error: tripError } = await supabase
    .from("rider_trips")
    .select("rider_id, destination, route, total_distance_km")
    .eq("id", tripId)
    .single();

  if (tripError || !trip) {
    console.error("recalculateRoute: trip not found:", tripError);
    return false;
  }

  const previousDistanceKm = trip.total_distance_km
    ? Number(trip.total_distance_km)
    : null;

  // Get rider's latest location as starting point
  const { data: latestLoc } = await supabase
    .from("rider_location_log")
    .select("location")
    .eq("trip_id", tripId)
    .eq("rider_id", trip.rider_id)
    .order("recorded_at", { ascending: false })
    .limit(1)
    .single();

  // Parse current position
  let currentPos: { lat: number; lng: number } | null = null;
  if (latestLoc?.location) {
    const loc = latestLoc.location as { type: string; coordinates: [number, number] };
    if (loc.type === "Point" && Array.isArray(loc.coordinates)) {
      currentPos = { lng: loc.coordinates[0], lat: loc.coordinates[1] };
    }
  }

  // Parse trip destination
  const dest = trip.destination as { type: string; coordinates: [number, number] } | null;
  let destPos: { lat: number; lng: number } | null = null;
  if (dest && dest.type === "Point" && Array.isArray(dest.coordinates)) {
    destPos = { lng: dest.coordinates[0], lat: dest.coordinates[1] };
  }

  if (!destPos) {
    console.error("recalculateRoute: no destination found");
    return false;
  }

  // Build waypoints: current → pickups → delivery → destination
  const waypoints: { lat: number; lng: number }[] = [];

  if (currentPos) {
    waypoints.push(currentPos);
  } else {
    if (pickupLocations.length > 0) {
      waypoints.push({ lat: pickupLocations[0].lat, lng: pickupLocations[0].lng });
    } else {
      return false;
    }
  }

  for (const pl of pickupLocations) {
    waypoints.push({ lat: pl.lat, lng: pl.lng });
  }
  waypoints.push({ lat: deliveryLocation.lat, lng: deliveryLocation.lng });
  waypoints.push(destPos);

  if (waypoints.length < 2) return false;

  // Call OSRM
  const coords = waypoints
    .map((w) => `${w.lng},${w.lat}`)
    .join(";");
  const url = `${OSRM_BASE_URL}/route/v1/driving/${coords}?overview=full&geometries=geojson`;

  const res = await fetch(url);
  if (!res.ok) {
    console.error("recalculateRoute: OSRM error:", res.status);
    return false;
  }

  const data = await res.json();
  if (data.code !== "Ok" || !data.routes?.length) {
    console.error("recalculateRoute: OSRM returned no routes");
    return false;
  }

  const route = data.routes[0];
  const routeCoords = route.geometry.coordinates as [number, number][];
  const newDistanceKm = Math.round((route.distance / 1000) * 100) / 100;
  const newDurationMinutes = Math.round(route.duration / 60);

  // Check detour threshold
  if (previousDistanceKm != null && previousDistanceKm > 0) {
    const detourRatio = (newDistanceKm - previousDistanceKm) / previousDistanceKm;
    if (detourRatio > MAX_DETOUR_PERCENTAGE) {
      console.warn(
        `recalculateRoute: detour exceeds threshold. ` +
          `Previous: ${previousDistanceKm}km, New: ${newDistanceKm}km, ` +
          `Detour: ${(detourRatio * 100).toFixed(1)}% (max ${MAX_DETOUR_PERCENTAGE * 100}%)`,
      );
      // Still update the route but log the warning.
      // In production, this could reject the order or notify the rider.
    }
  }

  // Convert GeoJSON [lng, lat] to WKT LINESTRING
  const wktPoints = routeCoords.map(([lng, lat]) => `${lng} ${lat}`).join(",");
  const routeWkt = `LINESTRING(${wktPoints})`;

  // Count stops for this trip
  const { count: stopCount } = await supabase
    .from("trip_stops")
    .select("id", { count: "exact", head: true })
    .eq("trip_id", tripId);

  const { error: updateError } = await supabase
    .from("rider_trips")
    .update({
      route: routeWkt,
      total_distance_km: newDistanceKm,
      estimated_duration_minutes: newDurationMinutes,
      total_stops: stopCount ?? 0,
    })
    .eq("id", tripId);

  if (updateError) {
    console.error("recalculateRoute: failed to update route:", updateError);
    return false;
  }

  return true;
}
