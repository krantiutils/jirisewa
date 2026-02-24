"use server";

import { OrderStatus, TripStatus } from "@jirisewa/shared";
import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import { parseEwkbPoint } from "@/lib/geo-utils";
import type { ActionResult } from "@/lib/types/action";

export interface AvailableOrder {
  id: string;
  deliveryAddress: string;
  deliveryLat: number;
  deliveryLng: number;
  totalPrice: number;
  deliveryFee: number;
  totalWeightKg: number;
  createdAt: string;
  pickupLocations: {
    farmerName: string;
    lat: number;
    lng: number;
  }[];
  items: {
    nameEn: string;
    quantityKg: number;
    farmerName: string;
  }[];
}

async function getAuthUserId(): Promise<string | null> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id ?? null;
}

/**
 * Fetch pending orders that have no rider assigned.
 */
export async function getAvailableOrders(): Promise<ActionResult<AvailableOrder[]>> {
  try {
    const riderId = await getAuthUserId();
    if (!riderId) return { error: "Not authenticated" };

    const supabase = createServiceRoleClient();

    const { data: orders, error } = await supabase
      .from("orders")
      .select(`
        id,
        delivery_address,
        delivery_location,
        total_price,
        delivery_fee,
        created_at,
        items:order_items(
          quantity_kg,
          listing:produce_listings!order_items_listing_id_fkey(name_en, location),
          farmer:users!order_items_farmer_id_fkey(name)
        )
      `)
      .eq("status", OrderStatus.Pending)
      .is("rider_id", null)
      .is("parent_order_id", null)
      .order("created_at", { ascending: false })
      .limit(50);

    if (error) {
      console.error("getAvailableOrders error:", error);
      return { error: error.message };
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const result: AvailableOrder[] = (orders ?? []).map((o: any) => {
      const deliveryPt = parseEwkbPoint(o.delivery_location);

      let totalWeightKg = 0;
      const pickupMap = new Map<string, { farmerName: string; lat: number; lng: number }>();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const items = (o.items ?? []).map((item: any) => {
        const listing = Array.isArray(item.listing) ? item.listing[0] : item.listing;
        const farmer = Array.isArray(item.farmer) ? item.farmer[0] : item.farmer;
        const qty = Number(item.quantity_kg) || 0;
        totalWeightKg += qty;

        // Parse pickup location
        if (listing?.location && farmer?.name) {
          const pt = parseEwkbPoint(listing.location);
          if (pt && !pickupMap.has(farmer.name)) {
            pickupMap.set(farmer.name, { farmerName: farmer.name, ...pt });
          }
        }

        return {
          nameEn: listing?.name_en ?? "Unknown",
          quantityKg: qty,
          farmerName: farmer?.name ?? "Unknown",
        };
      });

      return {
        id: o.id,
        deliveryAddress: o.delivery_address ?? "",
        deliveryLat: deliveryPt?.lat ?? 0,
        deliveryLng: deliveryPt?.lng ?? 0,
        totalPrice: Number(o.total_price) || 0,
        deliveryFee: Number(o.delivery_fee) || 0,
        totalWeightKg: Math.round(totalWeightKg * 100) / 100,
        createdAt: o.created_at,
        pickupLocations: [...pickupMap.values()],
        items,
      };
    }).filter((o: AvailableOrder) => o.deliveryLat !== 0 && o.deliveryLng !== 0);

    return { data: result };
  } catch (err) {
    console.error("getAvailableOrders unexpected error:", err);
    return { error: "Failed to fetch available orders" };
  }
}

/**
 * Rider directly accepts a pending order.
 * Creates a trip and assigns the order atomically.
 */
export async function acceptOrderDirect(
  orderId: string,
  riderOrigin: { lat: number; lng: number; name: string },
  riderDest: { lat: number; lng: number; name: string },
  capacityKg: number,
): Promise<ActionResult<{ tripId: string }>> {
  try {
    const riderId = await getAuthUserId();
    if (!riderId) return { error: "Not authenticated" };

    // Validate that rider has valid origin/destination
    if (riderOrigin.lat === 0 || riderOrigin.lng === 0 || riderDest.lat === 0 || riderDest.lng === 0) {
      return { error: "Please set your route origin and destination before accepting orders" };
    }

    const supabase = createServiceRoleClient();

    // Verify order is still pending
    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("id, status, rider_id")
      .eq("id", orderId)
      .single();

    if (orderErr) return { error: "Order not found" };
    if (order.status !== OrderStatus.Pending) return { error: "Order is no longer available" };
    if (order.rider_id) return { error: "Order already taken" };

    // Create a trip for this rider
    const { data: trip, error: tripErr } = await supabase
      .from("rider_trips")
      .insert({
        rider_id: riderId,
        origin: `POINT(${riderOrigin.lng} ${riderOrigin.lat})`,
        origin_name: riderOrigin.name,
        destination: `POINT(${riderDest.lng} ${riderDest.lat})`,
        destination_name: riderDest.name,
        departure_at: new Date().toISOString(),
        available_capacity_kg: capacityKg || 50,
        remaining_capacity_kg: capacityKg || 50,
        status: TripStatus.Scheduled,
      })
      .select("id")
      .single();

    if (tripErr) {
      console.error("acceptOrderDirect: trip creation failed:", tripErr);
      return { error: `Failed to create trip: ${tripErr.message}` };
    }

    // Assign the order to this rider/trip
    const { error: assignErr } = await supabase
      .from("orders")
      .update({
        rider_id: riderId,
        rider_trip_id: trip.id,
        status: OrderStatus.Matched,
      })
      .eq("id", orderId)
      .eq("status", OrderStatus.Pending); // optimistic lock

    if (assignErr) {
      console.error("acceptOrderDirect: order assignment failed:", assignErr);
      // Clean up the trip
      await supabase.from("rider_trips").delete().eq("id", trip.id);
      return { error: "Failed to accept order — it may have been taken" };
    }

    return { data: { tripId: trip.id } };
  } catch (err) {
    console.error("acceptOrderDirect unexpected error:", err);
    return { error: "Failed to accept order" };
  }
}
