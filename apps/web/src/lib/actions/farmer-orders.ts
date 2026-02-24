"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

async function getAuthUserId(): Promise<string | null> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id ?? null;
}

export interface FarmerOrderItem {
  id: string;
  listing_id: string;
  quantity_kg: number;
  price_per_kg: number;
  subtotal: number;
  pickup_status: string;
  listing: {
    name_en: string;
    name_ne: string;
    photos: string[];
  } | null;
}

export interface FarmerOrder {
  id: string;
  order_id: string;
  status: string;
  created_at: string;
  delivery_address: string | null;
  total_price: number;
  consumer_name: string;
  rider_name: string | null;
  items: FarmerOrderItem[];
  farmerSubtotal: number;
}

/**
 * Fetch orders that contain items from the current farmer.
 * Groups order_items by order and returns farmer-relevant details.
 */
export async function getFarmerOrders(): Promise<ActionResult<FarmerOrder[]>> {
  try {
    const farmerId = await getAuthUserId();
    if (!farmerId) return { error: "Not authenticated" };

    const supabase = createServiceRoleClient();

    // Fetch order_items for this farmer with order details
    const { data: items, error } = await supabase
      .from("order_items")
      .select(`
        id,
        order_id,
        listing_id,
        quantity_kg,
        price_per_kg,
        subtotal,
        pickup_status,
        listing:produce_listings!order_items_listing_id_fkey(name_en, name_ne, photos),
        order:orders!order_items_order_id_fkey(
          id,
          status,
          created_at,
          delivery_address,
          total_price,
          consumer:users!orders_consumer_id_fkey(name),
          rider:users!orders_rider_id_fkey(name)
        )
      `)
      .eq("farmer_id", farmerId)
      .order("created_at", { ascending: false, referencedTable: "orders" });

    if (error) {
      console.error("getFarmerOrders error:", error);
      return { error: error.message };
    }

    // Group items by order
    const orderMap = new Map<string, FarmerOrder>();

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    for (const item of (items ?? []) as any[]) {
      const order = Array.isArray(item.order) ? item.order[0] : item.order;
      if (!order) continue;

      const orderId = order.id as string;
      const listing = Array.isArray(item.listing) ? item.listing[0] : item.listing;
      const consumer = Array.isArray(order.consumer) ? order.consumer[0] : order.consumer;
      const rider = Array.isArray(order.rider) ? order.rider[0] : order.rider;

      const orderItem: FarmerOrderItem = {
        id: item.id,
        listing_id: item.listing_id,
        quantity_kg: item.quantity_kg,
        price_per_kg: item.price_per_kg,
        subtotal: Number(item.subtotal),
        pickup_status: item.pickup_status,
        listing: listing ?? null,
      };

      if (orderMap.has(orderId)) {
        const existing = orderMap.get(orderId)!;
        existing.items.push(orderItem);
        existing.farmerSubtotal += orderItem.subtotal;
      } else {
        orderMap.set(orderId, {
          id: orderId,
          order_id: orderId,
          status: order.status,
          created_at: order.created_at,
          delivery_address: order.delivery_address,
          total_price: Number(order.total_price),
          consumer_name: consumer?.name ?? "Unknown",
          rider_name: rider?.name ?? null,
          items: [orderItem],
          farmerSubtotal: orderItem.subtotal,
        });
      }
    }

    // Sort by created_at descending
    const orders = [...orderMap.values()].sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    );

    return { data: orders };
  } catch (err) {
    console.error("getFarmerOrders unexpected error:", err);
    return { error: "Failed to fetch farmer orders" };
  }
}
