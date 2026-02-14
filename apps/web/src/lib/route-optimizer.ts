"use server";

import { OSRM_BASE_URL } from "@jirisewa/shared";
import type { StopType } from "@jirisewa/shared";
import type { OptimizedRoute } from "@/lib/types/trip-stop";

export interface RouteStop {
  lat: number;
  lng: number;
  stopType: StopType;
  address?: string;
  orderItemIds: string[];
  /** Used to enforce pickup-before-delivery constraint. */
  orderId?: string;
}

interface OsrmLeg {
  distance: number;
  duration: number;
}

interface OsrmRoute {
  geometry: { coordinates: [number, number][] };
  distance: number;
  duration: number;
  legs: OsrmLeg[];
}

interface OsrmTripResponse {
  code: string;
  waypoints?: { waypoint_index: number; trips_index: number }[];
  trips?: OsrmRoute[];
}

interface OsrmRouteResponse {
  code: string;
  routes?: OsrmRoute[];
}

/**
 * Optimize a sequence of pickup and delivery stops for a rider trip.
 *
 * Uses OSRM /trip/v1/ for initial TSP approximation, then enforces the
 * constraint that all pickups for a given order must precede its delivery.
 *
 * @param origin      Rider's current position (trip start)
 * @param stops       Unordered pickup and delivery stops
 * @param destination Trip's final destination
 * @returns Optimized route with stop ordering, distances, and geometry
 */
export async function optimizeRoute(
  origin: { lat: number; lng: number },
  stops: RouteStop[],
  destination: { lat: number; lng: number },
): Promise<OptimizedRoute | null> {
  if (stops.length === 0) {
    return null;
  }

  // For a single stop, no optimization needed
  if (stops.length === 1) {
    return buildRouteForSequence(origin, stops, destination);
  }

  // Try OSRM trip optimization first
  const osrmResult = await tryOsrmTripOptimization(origin, stops, destination);

  if (osrmResult) {
    // Enforce pickup-before-delivery constraints
    const constrained = enforcePickupBeforeDelivery(osrmResult);
    return buildRouteForSequence(origin, constrained, destination);
  }

  // Fallback: greedy nearest-neighbor with constraints
  const greedy = greedyNearestNeighborWithConstraints(origin, stops);
  return buildRouteForSequence(origin, greedy, destination);
}

/**
 * Call OSRM /trip/v1/ to get a TSP-optimized ordering of waypoints.
 * source=first (origin), destination=last (trip destination), roundtrip=false.
 */
async function tryOsrmTripOptimization(
  origin: { lat: number; lng: number },
  stops: RouteStop[],
  destination: { lat: number; lng: number },
): Promise<RouteStop[] | null> {
  try {
    // Build coordinates: origin ; stops... ; destination
    const allPoints = [
      origin,
      ...stops.map((s) => ({ lat: s.lat, lng: s.lng })),
      destination,
    ];
    const coords = allPoints.map((p) => `${p.lng},${p.lat}`).join(";");
    const url = `${OSRM_BASE_URL}/trip/v1/driving/${coords}?source=first&destination=last&roundtrip=false&geometries=geojson&overview=full`;

    const res = await fetch(url);
    if (!res.ok) {
      return null;
    }

    const data: OsrmTripResponse = await res.json();
    if (data.code !== "Ok" || !data.waypoints || !data.trips?.length) {
      return null;
    }

    // waypoints[0] is origin, waypoints[last] is destination
    // Extract the optimized order for intermediate stops (indices 1..n-1)
    const intermediateWaypoints = data.waypoints.slice(1, -1);

    // Map waypoint_index back to original stop index
    // waypoint_index gives the position in the optimized trip
    const reordered: { stop: RouteStop; waypointIndex: number }[] =
      intermediateWaypoints.map((wp, i) => ({
        stop: stops[i],
        waypointIndex: wp.waypoint_index,
      }));

    // Sort by waypoint_index to get the optimized order
    reordered.sort((a, b) => a.waypointIndex - b.waypointIndex);
    return reordered.map((r) => r.stop);
  } catch (err) {
    console.error("OSRM trip optimization failed:", err);
    return null;
  }
}

/**
 * Enforce that all pickup stops for an order come before its delivery stop.
 * Uses a simple fix-up: if a delivery appears before all its pickups,
 * move it to just after the last pickup for that order.
 */
function enforcePickupBeforeDelivery(stops: RouteStop[]): RouteStop[] {
  const result = [...stops];

  // Build a map: orderId → indices of pickup stops
  const pickupIndices = new Map<string, number[]>();
  for (let i = 0; i < result.length; i++) {
    const stop = result[i];
    if (stop.stopType === "pickup" && stop.orderId) {
      const indices = pickupIndices.get(stop.orderId) ?? [];
      indices.push(i);
      pickupIndices.set(stop.orderId, indices);
    }
  }

  // For each delivery stop, ensure all pickups for its order come before it
  let modified = true;
  let iterations = 0;
  const maxIterations = result.length * result.length; // prevent infinite loops

  while (modified && iterations < maxIterations) {
    modified = false;
    iterations++;

    for (let i = 0; i < result.length; i++) {
      const stop = result[i];
      if (stop.stopType !== "delivery" || !stop.orderId) continue;

      // Find the last pickup for this order
      let lastPickupIdx = -1;
      for (let j = 0; j < result.length; j++) {
        if (
          result[j].stopType === "pickup" &&
          result[j].orderId === stop.orderId
        ) {
          lastPickupIdx = j;
        }
      }

      if (lastPickupIdx > i) {
        // Delivery is before its last pickup — move delivery after last pickup
        const [delivery] = result.splice(i, 1);
        result.splice(lastPickupIdx, 0, delivery);
        modified = true;
        break; // restart loop since indices shifted
      }
    }
  }

  return result;
}

/**
 * Greedy nearest-neighbor heuristic with pickup-before-delivery constraint.
 * Used as fallback when OSRM trip endpoint fails.
 */
function greedyNearestNeighborWithConstraints(
  origin: { lat: number; lng: number },
  stops: RouteStop[],
): RouteStop[] {
  const remaining = new Set(stops.map((_, i) => i));
  const result: RouteStop[] = [];
  const pickedUpOrders = new Set<string>(); // orders whose pickups are done
  let current = origin;

  while (remaining.size > 0) {
    let bestIdx = -1;
    let bestDist = Infinity;

    for (const idx of remaining) {
      const stop = stops[idx];

      // Skip delivery stops if not all pickups for this order are done
      if (stop.stopType === "delivery" && stop.orderId) {
        const allPickupsDone = stops.every(
          (s, si) =>
            s.orderId !== stop.orderId ||
            s.stopType !== "pickup" ||
            !remaining.has(si),
        );
        if (!allPickupsDone) continue;
      }

      const dist = haversineDistance(current, stop);
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = idx;
      }
    }

    if (bestIdx === -1) {
      // Shouldn't happen, but add remaining stops in order
      for (const idx of remaining) {
        result.push(stops[idx]);
      }
      break;
    }

    const chosen = stops[bestIdx];
    result.push(chosen);
    remaining.delete(bestIdx);
    current = { lat: chosen.lat, lng: chosen.lng };

    if (chosen.stopType === "pickup" && chosen.orderId) {
      pickedUpOrders.add(chosen.orderId);
    }
  }

  return result;
}

/**
 * Build a full route (with OSRM routing) for a given stop sequence.
 * Calls OSRM /route/v1/ with all waypoints in order.
 */
async function buildRouteForSequence(
  origin: { lat: number; lng: number },
  stops: RouteStop[],
  destination: { lat: number; lng: number },
): Promise<OptimizedRoute | null> {
  const allPoints = [
    origin,
    ...stops.map((s) => ({ lat: s.lat, lng: s.lng })),
    destination,
  ];
  const coords = allPoints.map((p) => `${p.lng},${p.lat}`).join(";");
  const url = `${OSRM_BASE_URL}/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=false`;

  try {
    const res = await fetch(url);
    if (!res.ok) {
      return null;
    }

    const data: OsrmRouteResponse = await res.json();
    if (data.code !== "Ok" || !data.routes?.length) {
      return null;
    }

    const route = data.routes[0];
    let cumulativeSeconds = 0;

    const optimizedStops = stops.map((stop, i) => {
      // legs[0] = origin→stop[0], legs[1] = stop[0]→stop[1], etc.
      const leg = route.legs[i];
      cumulativeSeconds += leg?.duration ?? 0;

      return {
        lat: stop.lat,
        lng: stop.lng,
        stopType: stop.stopType,
        address: stop.address,
        orderItemIds: stop.orderItemIds,
        estimatedArrivalSeconds: cumulativeSeconds,
      };
    });

    const legs = route.legs.slice(0, stops.length).map((leg) => ({
      distanceKm: Math.round((leg.distance / 1000) * 100) / 100,
      durationMinutes: Math.round(leg.duration / 60),
    }));

    return {
      stops: optimizedStops,
      totalDistanceKm: Math.round((route.distance / 1000) * 100) / 100,
      totalDurationMinutes: Math.round(route.duration / 60),
      routeGeometry: route.geometry.coordinates,
      legs,
    };
  } catch (err) {
    console.error("buildRouteForSequence OSRM error:", err);
    return null;
  }
}

/**
 * Haversine distance approximation in meters between two lat/lng points.
 * Used for the greedy nearest-neighbor heuristic only (not for real routing).
 */
function haversineDistance(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const R = 6371000; // Earth radius in meters
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const sinDLat = Math.sin(dLat / 2);
  const sinDLng = Math.sin(dLng / 2);
  const h =
    sinDLat * sinDLat +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * sinDLng * sinDLng;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}
