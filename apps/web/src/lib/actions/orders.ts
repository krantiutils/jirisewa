"use server";

import { OrderStatus } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import type {
  PlaceOrderInput,
  OrderWithDetails,
  OrderItemWithDetails,
} from "@/lib/types/order";
import {
  notifyFarmerNewOrder,
  notifyRiderPickedUp,
  notifyRiderDeliveryConfirmed,
} from "@/lib/actions/notifications";

// TODO: Replace hardcoded consumer ID with authenticated user once auth is implemented
const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";
const DEMO_RIDER_ID = "00000000-0000-0000-0000-000000000000";

function pointToWkt(lng: number, lat: number): string {
  return `POINT(${lng} ${lat})`;
}

/**
 * Place a new order from cart items.
 * Creates the order row and all order_items in a single transaction-like flow.
 */
export async function placeOrder(
  input: PlaceOrderInput,
): Promise<ActionResult<{ orderId: string }>> {
  try {
    if (input.items.length === 0) {
      return { error: "Cart is empty" };
    }

    if (
      input.deliveryLat < -90 || input.deliveryLat > 90 ||
      input.deliveryLng < -180 || input.deliveryLng > 180
    ) {
      return { error: "Invalid delivery coordinates" };
    }

    if (!input.deliveryAddress || input.deliveryAddress.length > 500) {
      return { error: "Invalid delivery address" };
    }

    const supabase = createServiceRoleClient();

    // Fetch listings to verify prices, availability, and get locations
    const listingIds = input.items.map((i) => i.listingId);
    const { data: listings, error: listingError } = await supabase
      .from("produce_listings")
      .select("id, farmer_id, price_per_kg, available_qty_kg, location")
      .in("id", listingIds)
      .eq("is_active", true);

    if (listingError) {
      console.error("placeOrder: failed to fetch listings:", listingError);
      return { error: "Failed to verify produce listings" };
    }

    if (!listings || listings.length !== listingIds.length) {
      return { error: "One or more produce items are no longer available" };
    }

    const listingMap = new Map(
      listings.map((l) => [l.id, l]),
    );

    // Validate each item against the actual listing data
    for (const item of input.items) {
      if (item.quantityKg <= 0) {
        return { error: "Quantity must be greater than 0" };
      }

      const listing = listingMap.get(item.listingId);
      if (!listing) {
        return { error: "Produce item not found" };
      }

      if (listing.farmer_id !== item.farmerId) {
        return { error: "Farmer mismatch for produce item" };
      }

      if (item.quantityKg > listing.available_qty_kg) {
        return { error: `Insufficient stock for listing ${item.listingId}` };
      }

      // Use server-side price, not client-submitted price
      item.pricePerKg = listing.price_per_kg;
    }

    // Calculate total price from verified prices
    const totalPrice = input.items.reduce(
      (sum, item) => sum + item.quantityKg * item.pricePerKg,
      0,
    );

    // Create the order
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert({
        consumer_id: DEMO_CONSUMER_ID,
        status: OrderStatus.Pending,
        delivery_address: input.deliveryAddress,
        delivery_location: pointToWkt(input.deliveryLng, input.deliveryLat),
        total_price: Math.round(totalPrice * 100) / 100,
        delivery_fee: 0,
        payment_method: "cash",
        payment_status: "pending",
      })
      .select("id")
      .single();

    if (orderError) {
      console.error("placeOrder: failed to create order:", orderError);
      return { error: orderError.message };
    }

    // Create order items using verified server-side data
    const orderItems = input.items.map((item) => {
      const listing = listingMap.get(item.listingId)!;
      return {
        order_id: order.id,
        listing_id: item.listingId,
        farmer_id: item.farmerId,
        quantity_kg: item.quantityKg,
        price_per_kg: listing.price_per_kg,
        subtotal: Math.round(item.quantityKg * listing.price_per_kg * 100) / 100,
        pickup_location: listing.location ?? null,
      };
    });

    const { error: itemsError } = await supabase
      .from("order_items")
      .insert(orderItems);

    if (itemsError) {
      console.error("placeOrder: failed to create order items:", itemsError);
      const { error: cleanupError } = await supabase.from("orders").delete().eq("id", order.id);
      if (cleanupError) {
        console.error("placeOrder: cleanup failed for order:", order.id, cleanupError);
      }
      return { error: itemsError.message };
    }

    // Notify each farmer about the new order (fire-and-forget)
    const farmerNotifications = new Map<string, { name: string; qty: number }>();
    for (const item of input.items) {
      const listing = listingMap.get(item.listingId)!;
      const existing = farmerNotifications.get(item.farmerId);
      if (existing) {
        existing.qty += item.quantityKg;
      } else {
        // Use listing name from the query result set (not available directly
        // since we only selected price/qty fields — use a placeholder)
        farmerNotifications.set(item.farmerId, {
          name: "produce",
          qty: item.quantityKg,
        });
      }
    }
    for (const [farmerId, info] of farmerNotifications) {
      notifyFarmerNewOrder(farmerId, order.id, info.name, info.qty).catch(
        (err) => console.error("Notification error (farmer new order):", err),
      );
    }

    return { data: { orderId: order.id } };
  } catch (err) {
    console.error("placeOrder unexpected error:", err);
    return { error: "Failed to place order" };
  }
}

/**
 * List orders for the current user, filtered by role.
 */
export async function listOrders(
  statusFilter?: OrderStatus,
): Promise<ActionResult<OrderWithDetails[]>> {
  try {
    const supabase = createServiceRoleClient();

    let query = supabase
      .from("orders")
      .select(
        `
        *,
        items:order_items(
          *,
          listing:produce_listings!order_items_listing_id_fkey(name_en, name_ne, photos),
          farmer:users!order_items_farmer_id_fkey(id, name, avatar_url)
        )
      `,
      )
      .eq("consumer_id", DEMO_CONSUMER_ID)
      .order("created_at", { ascending: false });

    if (statusFilter) {
      query = query.eq("status", statusFilter);
    }

    const { data, error } = await query;

    if (error) {
      console.error("listOrders error:", error);
      return { error: error.message };
    }

    // Normalize joined data
    const orders: OrderWithDetails[] = (data ?? []).map((row) =>
      normalizeOrderRow(row),
    );

    return { data: orders };
  } catch (err) {
    console.error("listOrders unexpected error:", err);
    return { error: "Failed to list orders" };
  }
}

/**
 * Get a single order by ID with full details.
 */
export async function getOrder(
  orderId: string,
): Promise<ActionResult<OrderWithDetails>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("orders")
      .select(
        `
        *,
        items:order_items(
          *,
          listing:produce_listings!order_items_listing_id_fkey(name_en, name_ne, photos),
          farmer:users!order_items_farmer_id_fkey(id, name, avatar_url)
        ),
        rider:users!orders_rider_id_fkey(id, name, avatar_url, phone, rating_avg),
        trip:rider_trips!orders_rider_trip_id_fkey(id, origin_name, destination_name, departure_at)
      `,
      )
      .eq("id", orderId)
      .single();

    if (error) {
      console.error("getOrder error:", error);
      return { error: error.message };
    }

    return { data: normalizeOrderRow(data) };
  } catch (err) {
    console.error("getOrder unexpected error:", err);
    return { error: "Failed to get order" };
  }
}

/**
 * Cancel an order (consumer action). Only pending or matched orders can be cancelled.
 */
export async function cancelOrder(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("orders")
      .select("status, consumer_id")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Order not found" };
    }

    if (existing.consumer_id !== DEMO_CONSUMER_ID) {
      return { error: "You can only cancel your own orders" };
    }

    const cancellable: OrderStatus[] = [
      OrderStatus.Pending,
      OrderStatus.Matched,
    ];
    if (!cancellable.includes(existing.status as OrderStatus)) {
      return {
        error: "Only pending or matched orders can be cancelled",
      };
    }

    const { error } = await supabase
      .from("orders")
      .update({ status: OrderStatus.Cancelled })
      .eq("id", orderId);

    if (error) {
      console.error("cancelOrder error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("cancelOrder unexpected error:", err);
    return { error: "Failed to cancel order" };
  }
}

/**
 * Consumer confirms delivery receipt.
 */
export async function confirmDelivery(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("orders")
      .select("status, consumer_id, rider_id")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Order not found" };
    }

    if (existing.consumer_id !== DEMO_CONSUMER_ID) {
      return { error: "You can only confirm your own orders" };
    }

    if (existing.status !== OrderStatus.InTransit) {
      return { error: "Only in-transit orders can be confirmed as delivered" };
    }

    const { error } = await supabase
      .from("orders")
      .update({
        status: OrderStatus.Delivered,
        payment_status: "collected",
      })
      .eq("id", orderId);

    if (error) {
      console.error("confirmDelivery error:", error);
      return { error: error.message };
    }

    // Notify rider that delivery was confirmed
    if (existing.rider_id) {
      notifyRiderDeliveryConfirmed(existing.rider_id, orderId).catch(
        (err) => console.error("Notification error (delivery confirmed):", err),
      );
    }

    return {};
  } catch (err) {
    console.error("confirmDelivery unexpected error:", err);
    return { error: "Failed to confirm delivery" };
  }
}

/**
 * Rider confirms pickup of an order (sets status to picked_up).
 */
export async function confirmPickup(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("orders")
      .select("status, rider_id")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Order not found" };
    }

    if (existing.rider_id !== DEMO_RIDER_ID) {
      return { error: "You are not assigned to this order" };
    }

    if (existing.status !== OrderStatus.Matched) {
      return { error: "Only matched orders can be picked up" };
    }

    const { error } = await supabase
      .from("orders")
      .update({ status: OrderStatus.PickedUp })
      .eq("id", orderId);

    if (error) {
      console.error("confirmPickup error:", error);
      return { error: error.message };
    }

    // Fetch consumer_id to notify them
    const { data: orderData } = await supabase
      .from("orders")
      .select("consumer_id")
      .eq("id", orderId)
      .single();

    if (orderData) {
      notifyRiderPickedUp(orderData.consumer_id, orderId).catch(
        (err) => console.error("Notification error (rider picked up):", err),
      );
    }

    return {};
  } catch (err) {
    console.error("confirmPickup unexpected error:", err);
    return { error: "Failed to confirm pickup" };
  }
}

/**
 * Rider marks order as in transit after all pickups done.
 */
export async function startDelivery(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("orders")
      .select("status, rider_id")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Order not found" };
    }

    if (existing.rider_id !== DEMO_RIDER_ID) {
      return { error: "You are not assigned to this order" };
    }

    if (existing.status !== OrderStatus.PickedUp) {
      return { error: "Only picked-up orders can be marked as in transit" };
    }

    const { error } = await supabase
      .from("orders")
      .update({ status: OrderStatus.InTransit })
      .eq("id", orderId);

    if (error) {
      console.error("startDelivery error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("startDelivery unexpected error:", err);
    return { error: "Failed to start delivery" };
  }
}

/**
 * List orders matched to a specific rider trip.
 */
export async function listOrdersByTrip(
  tripId: string,
): Promise<ActionResult<OrderWithDetails[]>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("orders")
      .select(
        `
        *,
        items:order_items(
          *,
          listing:produce_listings!order_items_listing_id_fkey(name_en, name_ne, photos),
          farmer:users!order_items_farmer_id_fkey(id, name, avatar_url)
        )
      `,
      )
      .eq("rider_trip_id", tripId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("listOrdersByTrip error:", error);
      return { error: error.message };
    }

    const orders: OrderWithDetails[] = (data ?? []).map((row) =>
      normalizeOrderRow(row),
    );

    return { data: orders };
  } catch (err) {
    console.error("listOrdersByTrip unexpected error:", err);
    return { error: "Failed to list trip orders" };
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function normalizeOrderRow(row: any): OrderWithDetails {
  const items: OrderItemWithDetails[] = (row.items ?? []).map(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (item: any) => ({
      ...item,
      listing: Array.isArray(item.listing) ? item.listing[0] : item.listing,
      farmer: Array.isArray(item.farmer) ? item.farmer[0] : item.farmer,
    }),
  );

  return {
    ...row,
    items,
    rider: row.rider
      ? Array.isArray(row.rider)
        ? row.rider[0]
        : row.rider
      : null,
    trip: row.trip
      ? Array.isArray(row.trip)
        ? row.trip[0]
        : row.trip
      : null,
  };
}
