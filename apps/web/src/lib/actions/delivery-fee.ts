"use server";

import { OSRM_BASE_URL } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import type { DeliveryFeeEstimate } from "@/lib/types/order";

interface CalculateDeliveryFeeInput {
  listingIds: string[];
  itemWeights: { listingId: string; quantityKg: number }[];
  deliveryLat: number;
  deliveryLng: number;
}

interface GeoJsonPoint {
  type: "Point";
  coordinates: [number, number]; // [lng, lat]
}

function parseGeoJsonPoint(
  value: unknown,
): { lat: number; lng: number } | null {
  if (!value || typeof value !== "object") return null;
  const geo = value as GeoJsonPoint;
  if (
    geo.type !== "Point" ||
    !Array.isArray(geo.coordinates) ||
    geo.coordinates.length < 2
  ) {
    return null;
  }
  const [lng, lat] = geo.coordinates;
  if (typeof lng !== "number" || typeof lat !== "number") return null;
  return { lat, lng };
}

async function fetchOsrmDistance(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number,
): Promise<number | null> {
  try {
    const coords = `${originLng},${originLat};${destLng},${destLat}`;
    const url = `${OSRM_BASE_URL}/route/v1/driving/${coords}?overview=false`;
    const res = await fetch(url);
    if (!res.ok) return null;

    const data = await res.json();
    if (data.code !== "Ok" || !data.routes?.length) return null;

    return data.routes[0].distance; // meters
  } catch {
    return null;
  }
}

/**
 * Calculate delivery fee estimate based on distance (OSRM) and weight.
 *
 * Distance is the farthest farmer-to-consumer road distance (via OSRM).
 * Weight is total kg across all items.
 * Rate is pulled from the active delivery_rates row.
 */
export async function calculateDeliveryFee(
  input: CalculateDeliveryFeeInput,
): Promise<ActionResult<DeliveryFeeEstimate>> {
  try {
    if (input.listingIds.length === 0) {
      return { error: "No items provided" };
    }

    if (
      input.deliveryLat < -90 || input.deliveryLat > 90 ||
      input.deliveryLng < -180 || input.deliveryLng > 180
    ) {
      return { error: "Invalid delivery coordinates" };
    }

    const supabase = createServiceRoleClient();

    // Fetch active rate
    const { data: rate, error: rateError } = await supabase
      .from("delivery_rates")
      .select("*")
      .eq("is_active", true)
      .single();

    if (rateError || !rate) {
      console.error("calculateDeliveryFee: no active rate found:", rateError);
      return { error: "Delivery rates not configured" };
    }

    // Fetch listing locations
    const { data: listings, error: listingError } = await supabase
      .from("produce_listings")
      .select("id, location")
      .in("id", input.listingIds)
      .eq("is_active", true);

    if (listingError || !listings) {
      console.error("calculateDeliveryFee: failed to fetch listings:", listingError);
      return { error: "Failed to fetch produce locations" };
    }

    // Calculate total weight
    const totalWeightKg = input.itemWeights.reduce(
      (sum, item) => sum + item.quantityKg,
      0,
    );

    // Calculate distance from each farmer to delivery point, take the max
    let maxDistanceMeters = 0;
    let hasValidRoute = false;

    for (const listing of listings) {
      const farmerLocation = parseGeoJsonPoint(listing.location);
      if (!farmerLocation) continue;

      const distance = await fetchOsrmDistance(
        farmerLocation.lat,
        farmerLocation.lng,
        input.deliveryLat,
        input.deliveryLng,
      );

      if (distance !== null) {
        hasValidRoute = true;
        if (distance > maxDistanceMeters) {
          maxDistanceMeters = distance;
        }
      }
    }

    if (!hasValidRoute) {
      return { error: "Could not calculate route distance. Please verify locations." };
    }

    const distanceKm = maxDistanceMeters / 1000;

    // Apply rate formula
    const baseFee = Number(rate.base_fee_npr);
    const distanceFee = Math.round(distanceKm * Number(rate.per_km_rate_npr) * 100) / 100;
    const weightFee = Math.round(totalWeightKg * Number(rate.per_kg_rate_npr) * 100) / 100;
    let totalFee = baseFee + distanceFee + weightFee;

    // Apply min/max bounds
    const minFee = Number(rate.min_fee_npr);
    if (totalFee < minFee) {
      totalFee = minFee;
    }
    if (rate.max_fee_npr !== null) {
      const maxFee = Number(rate.max_fee_npr);
      if (totalFee > maxFee) {
        totalFee = maxFee;
      }
    }

    totalFee = Math.round(totalFee * 100) / 100;

    return {
      data: {
        baseFee,
        distanceFee,
        weightFee,
        totalFee,
        distanceKm: Math.round(distanceKm * 10) / 10,
        weightKg: Math.round(totalWeightKg * 100) / 100,
      },
    };
  } catch (err) {
    console.error("calculateDeliveryFee unexpected error:", err);
    return { error: "Failed to calculate delivery fee" };
  }
}
