"use server";

import { TripStatus } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type {
  CreateTripInput,
  UpdateTripInput,
  RiderTrip,
  Trip,
  GeoPoint,
} from "@/lib/types/trip";
import { parseRiderTrip } from "@/lib/types/trip";

// TODO: Replace hardcoded rider ID with authenticated user once auth is implemented
const DEMO_RIDER_ID = "00000000-0000-0000-0000-000000000000";

function pointToWkt(point: GeoPoint): string {
  return `POINT(${point.lng} ${point.lat})`;
}

function routeToWkt(coordinates: [number, number][]): string {
  // coordinates are in GeoJSON order [lng, lat]
  const points = coordinates.map(([lng, lat]) => `${lng} ${lat}`).join(",");
  return `LINESTRING(${points})`;
}

export type { ActionResult } from "@/lib/types/action";
import type { ActionResult } from "@/lib/types/action";

export async function createTrip(
  input: CreateTripInput,
): Promise<ActionResult<Trip>> {
  try {
    const supabase = createServiceRoleClient();

    const insertData: Record<string, unknown> = {
      rider_id: DEMO_RIDER_ID,
      origin: pointToWkt(input.origin),
      origin_name: input.originName,
      destination: pointToWkt(input.destination),
      destination_name: input.destinationName,
      departure_at: input.departureAt,
      available_capacity_kg: input.availableCapacityKg,
      remaining_capacity_kg: input.availableCapacityKg,
      status: TripStatus.Scheduled,
    };

    if (input.routeGeoJson && input.routeGeoJson.length >= 2) {
      insertData.route = routeToWkt(input.routeGeoJson);
    }

    const { data, error } = await supabase
      .from("rider_trips")
      .insert(insertData)
      .select()
      .single();

    if (error) {
      console.error("createTrip error:", error);
      return { error: error.message };
    }

    return { data: parseRiderTrip(data as RiderTrip) };
  } catch (err) {
    console.error("createTrip unexpected error:", err);
    return { error: "Failed to create trip" };
  }
}

export async function listTrips(
  statusFilter?: TripStatus,
): Promise<ActionResult<Trip[]>> {
  try {
    const supabase = createServiceRoleClient();

    let query = supabase
      .from("rider_trips")
      .select("*")
      .eq("rider_id", DEMO_RIDER_ID)
      .order("departure_at", { ascending: true });

    if (statusFilter) {
      query = query.eq("status", statusFilter);
    }

    const { data, error } = await query;

    if (error) {
      console.error("listTrips error:", error);
      return { error: error.message };
    }

    return {
      data: (data as RiderTrip[]).map(parseRiderTrip),
    };
  } catch (err) {
    console.error("listTrips unexpected error:", err);
    return { error: "Failed to list trips" };
  }
}

export async function getTrip(
  tripId: string,
): Promise<ActionResult<Trip>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("rider_trips")
      .select("*")
      .eq("id", tripId)
      .single();

    if (error) {
      console.error("getTrip error:", error);
      return { error: error.message };
    }

    return { data: parseRiderTrip(data as RiderTrip) };
  } catch (err) {
    console.error("getTrip unexpected error:", err);
    return { error: "Failed to get trip" };
  }
}

export async function updateTrip(
  tripId: string,
  input: UpdateTripInput,
): Promise<ActionResult<Trip>> {
  try {
    const supabase = createServiceRoleClient();

    // Verify trip exists and is editable (only scheduled trips can be edited)
    const { data: existing, error: fetchError } = await supabase
      .from("rider_trips")
      .select("status, rider_id")
      .eq("id", tripId)
      .single();

    if (fetchError) {
      return { error: "Trip not found" };
    }

    if (existing.status !== TripStatus.Scheduled) {
      return { error: "Only scheduled trips can be edited" };
    }

    if (existing.rider_id !== DEMO_RIDER_ID) {
      return { error: "You can only edit your own trips" };
    }

    const updateData: Record<string, unknown> = {};

    if (input.origin) {
      updateData.origin = pointToWkt(input.origin);
    }
    if (input.originName !== undefined) {
      updateData.origin_name = input.originName;
    }
    if (input.destination) {
      updateData.destination = pointToWkt(input.destination);
    }
    if (input.destinationName !== undefined) {
      updateData.destination_name = input.destinationName;
    }
    if (input.routeGeoJson !== undefined) {
      updateData.route =
        input.routeGeoJson && input.routeGeoJson.length >= 2
          ? routeToWkt(input.routeGeoJson)
          : null;
    }
    if (input.departureAt !== undefined) {
      updateData.departure_at = input.departureAt;
    }
    if (input.availableCapacityKg !== undefined) {
      updateData.available_capacity_kg = input.availableCapacityKg;
      updateData.remaining_capacity_kg = input.availableCapacityKg;
    }

    if (Object.keys(updateData).length === 0) {
      return { error: "No fields to update" };
    }

    const { data, error } = await supabase
      .from("rider_trips")
      .update(updateData)
      .eq("id", tripId)
      .select()
      .single();

    if (error) {
      console.error("updateTrip error:", error);
      return { error: error.message };
    }

    return { data: parseRiderTrip(data as RiderTrip) };
  } catch (err) {
    console.error("updateTrip unexpected error:", err);
    return { error: "Failed to update trip" };
  }
}

export async function startTrip(
  tripId: string,
): Promise<ActionResult<Trip>> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("rider_trips")
      .select("status, rider_id")
      .eq("id", tripId)
      .single();

    if (fetchError) {
      return { error: "Trip not found" };
    }

    if (existing.rider_id !== DEMO_RIDER_ID) {
      return { error: "You can only start your own trips" };
    }

    if (existing.status !== TripStatus.Scheduled) {
      return { error: "Only scheduled trips can be started" };
    }

    const { data, error } = await supabase
      .from("rider_trips")
      .update({ status: TripStatus.InTransit })
      .eq("id", tripId)
      .select()
      .single();

    if (error) {
      console.error("startTrip error:", error);
      return { error: error.message };
    }

    return { data: parseRiderTrip(data as RiderTrip) };
  } catch (err) {
    console.error("startTrip unexpected error:", err);
    return { error: "Failed to start trip" };
  }
}

export async function completeTrip(
  tripId: string,
): Promise<ActionResult<Trip>> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("rider_trips")
      .select("status, rider_id")
      .eq("id", tripId)
      .single();

    if (fetchError) {
      return { error: "Trip not found" };
    }

    if (existing.rider_id !== DEMO_RIDER_ID) {
      return { error: "You can only complete your own trips" };
    }

    if (existing.status !== TripStatus.InTransit) {
      return { error: "Only in-transit trips can be completed" };
    }

    const { data, error } = await supabase
      .from("rider_trips")
      .update({ status: TripStatus.Completed })
      .eq("id", tripId)
      .select()
      .single();

    if (error) {
      console.error("completeTrip error:", error);
      return { error: error.message };
    }

    return { data: parseRiderTrip(data as RiderTrip) };
  } catch (err) {
    console.error("completeTrip unexpected error:", err);
    return { error: "Failed to complete trip" };
  }
}

export async function cancelTrip(
  tripId: string,
): Promise<ActionResult<Trip>> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("rider_trips")
      .select("status, rider_id")
      .eq("id", tripId)
      .single();

    if (fetchError) {
      return { error: "Trip not found" };
    }

    if (existing.rider_id !== DEMO_RIDER_ID) {
      return { error: "You can only cancel your own trips" };
    }

    if (existing.status !== TripStatus.Scheduled) {
      return { error: "Only scheduled trips can be cancelled" };
    }

    // TODO: Notify matched orders when cancelling

    const { data, error } = await supabase
      .from("rider_trips")
      .update({ status: TripStatus.Cancelled })
      .eq("id", tripId)
      .select()
      .single();

    if (error) {
      console.error("cancelTrip error:", error);
      return { error: error.message };
    }

    return { data: parseRiderTrip(data as RiderTrip) };
  } catch (err) {
    console.error("cancelTrip unexpected error:", err);
    return { error: "Failed to cancel trip" };
  }
}
