"use server";

import { OrderStatus, OrderItemStatus, PaymentStatus, PayoutStatus, PingStatus } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import { buildPaymentFormData, generateTransactionUuid } from "@/lib/esewa";
import { findAndPingRiders } from "@/lib/actions/pings";
import type { ActionResult } from "@/lib/types/action";
import type {
  PlaceOrderInput,
  OrderWithDetails,
  OrderItemWithDetails,
  EsewaPaymentFormData,
  FarmerItemGroup,
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Group order items by farmer, computing per-group totals and pickup state.
 * Groups are sorted by pickup_sequence ascending.
 */
function groupItemsByFarmer(
  items: OrderItemWithDetails[],
): FarmerItemGroup[] {
  const groups = new Map<string, FarmerItemGroup>();

  for (const item of items) {
    const farmerId = item.farmer_id;
    let group = groups.get(farmerId);

    if (!group) {
      group = {
        farmerId,
        farmerName: item.farmer?.name ?? "Unknown",
        farmerAvatar: item.farmer?.avatar_url ?? null,
        pickupSequence: item.pickup_sequence ?? 0,
        pickupStatus: item.pickup_status ?? OrderItemStatus.PendingPickup,
        pickupConfirmedAt: item.pickup_confirmed_at ?? null,
        items: [],
        subtotal: 0,
        totalKg: 0,
      };
      groups.set(farmerId, group);
    }

    group.items.push(item);
    group.subtotal += Number(item.subtotal);
    group.totalKg += Number(item.quantity_kg);
  }

  // Sort by pickup sequence
  return [...groups.values()].sort((a, b) => a.pickupSequence - b.pickupSequence);
}

// ---------------------------------------------------------------------------
// Place order (multi-farmer aware)
// ---------------------------------------------------------------------------

/**
 * Place a new order from cart items.
 *
 * Multi-farmer support:
 * - Items are grouped by farmer_id.
 * - Each group gets a pickup_sequence (input order for now, route-based when matched).
 * - A farmer_payouts record is created per farmer tracking their share.
 * - Delivery fee is passed from the client (calculated via calculateDeliveryFee action).
 */
export async function placeOrder(
  input: PlaceOrderInput,
): Promise<ActionResult<{ orderId: string; esewaForm?: EsewaPaymentFormData }>> {
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
      .select("id, farmer_id, price_per_kg, available_qty_kg, location, name_en")
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

    const validPaymentMethods = ["cash", "esewa"] as const;
    const paymentMethod = validPaymentMethods.includes(input.paymentMethod as typeof validPaymentMethods[number])
      ? input.paymentMethod
      : "cash";

    // Group items by farmer to assign pickup sequences
    const farmerItemMap = new Map<string, typeof input.items>();
    for (const item of input.items) {
      const group = farmerItemMap.get(item.farmerId) ?? [];
      group.push(item);
      farmerItemMap.set(item.farmerId, group);
    }
    const farmerIds = [...farmerItemMap.keys()];

    // Create the order
    const deliveryFee = Math.max(0, Math.round((input.deliveryFee ?? 0) * 100) / 100);
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert({
        consumer_id: DEMO_CONSUMER_ID,
        status: OrderStatus.Pending,
        delivery_address: input.deliveryAddress,
        delivery_location: pointToWkt(input.deliveryLng, input.deliveryLat),
        total_price: Math.round(totalPrice * 100) / 100,
        delivery_fee: deliveryFee,
        delivery_fee_base: Math.round((input.deliveryFeeBase ?? 0) * 100) / 100,
        delivery_fee_distance: Math.round((input.deliveryFeeDistance ?? 0) * 100) / 100,
        delivery_fee_weight: Math.round((input.deliveryFeeWeight ?? 0) * 100) / 100,
        delivery_distance_km: input.deliveryDistanceKm ?? null,
        payment_method: paymentMethod,
        payment_status: "pending",
      })
      .select("id")
      .single();

    if (orderError) {
      console.error("placeOrder: failed to create order:", orderError);
      return { error: orderError.message };
    }

    // Create order items with pickup_sequence per farmer group
    const orderItems = input.items.map((item) => {
      const listing = listingMap.get(item.listingId)!;
      const farmerSequence = farmerIds.indexOf(item.farmerId) + 1;
      return {
        order_id: order.id,
        listing_id: item.listingId,
        farmer_id: item.farmerId,
        quantity_kg: item.quantityKg,
        price_per_kg: listing.price_per_kg,
        subtotal: Math.round(item.quantityKg * listing.price_per_kg * 100) / 100,
        pickup_location: listing.location ?? null,
        pickup_sequence: farmerSequence,
        pickup_status: OrderItemStatus.PendingPickup,
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
        farmerNotifications.set(item.farmerId, {
          name: listing.name_en,
          qty: item.quantityKg,
        });
      }
    }
    for (const [farmerId, info] of farmerNotifications) {
      notifyFarmerNewOrder(farmerId, order.id, info.name, info.qty).catch(
        (err) => console.error("Notification error (farmer new order):", err),
      );
    }

    // Create farmer_payouts records — one per farmer, amount = sum of their items' subtotals
    const payoutRecords = farmerIds.map((farmerId) => {
      const farmerItems = farmerItemMap.get(farmerId)!;
      const amount = farmerItems.reduce((sum, item) => {
        const listing = listingMap.get(item.listingId)!;
        return sum + item.quantityKg * listing.price_per_kg;
      }, 0);
      return {
        order_id: order.id,
        farmer_id: farmerId,
        amount: Math.round(amount * 100) / 100,
        status: PayoutStatus.Pending,
      };
    });

    const { error: payoutError } = await supabase
      .from("farmer_payouts")
      .insert(payoutRecords);

    if (payoutError) {
      console.error("placeOrder: failed to create farmer payouts:", payoutError);
      // Non-fatal: order was created, payouts can be reconciled later
    }

    // For eSewa payments, create transaction record and return form data for redirect
    if (paymentMethod === "esewa") {
      const roundedTotal = Math.round(totalPrice * 100) / 100;
      const transactionUuid = generateTransactionUuid(order.id);

      const { error: txnError } = await supabase
        .from("esewa_transactions")
        .insert({
          order_id: order.id,
          transaction_uuid: transactionUuid,
          product_code: process.env.ESEWA_PRODUCT_CODE ?? "EPAYTEST",
          amount: roundedTotal,
          tax_amount: 0,
          service_charge: 0,
          delivery_charge: deliveryFee,
          total_amount: roundedTotal + deliveryFee,
          status: "PENDING",
        });

      if (txnError) {
        console.error("placeOrder: failed to create eSewa transaction:", txnError);
        await supabase.from("farmer_payouts").delete().eq("order_id", order.id);
        await supabase.from("order_items").delete().eq("order_id", order.id);
        await supabase.from("orders").delete().eq("id", order.id);
        return { error: "Failed to initiate eSewa payment" };
      }

      const esewaForm = buildPaymentFormData({
        orderId: order.id,
        amount: roundedTotal,
        deliveryCharge: deliveryFee,
        transactionUuid,
      });

      // Trigger rider matching (non-fatal — order exists regardless)
      try {
        await findAndPingRiders(order.id);
      } catch (pingErr) {
        console.error("placeOrder: rider ping failed (non-fatal):", pingErr);
      }

      return {
        data: {
          orderId: order.id,
          esewaForm: {
            orderId: order.id,
            url: esewaForm.url,
            fields: esewaForm.fields,
          },
        },
      };
    }

    // Trigger rider matching for cash orders (non-fatal — order exists regardless)
    try {
      await findAndPingRiders(order.id);
    } catch (pingErr) {
      console.error("placeOrder: rider ping failed (non-fatal):", pingErr);
    }

    return { data: { orderId: order.id } };
  } catch (err) {
    console.error("placeOrder unexpected error:", err);
    return { error: "Failed to place order" };
  }
}

// ---------------------------------------------------------------------------
// Per-farmer pickup confirmation (rider action)
// ---------------------------------------------------------------------------

/**
 * Rider confirms pickup of items from a specific farmer within an order.
 *
 * Updates all order_items for this (order, farmer) to pickup_status = 'picked_up'.
 * When ALL farmers' items are picked up (or unavailable), the order transitions
 * from 'matched' to 'picked_up'.
 */
export async function confirmFarmerPickup(
  orderId: string,
  farmerId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    // Verify order exists and rider is assigned
    const { data: order, error: fetchError } = await supabase
      .from("orders")
      .select("status, rider_id")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Order not found" };
    }

    if (order.rider_id !== DEMO_RIDER_ID) {
      return { error: "You are not assigned to this order" };
    }

    if (order.status !== OrderStatus.Matched && order.status !== OrderStatus.PickedUp) {
      return { error: "Order is not in a pickupable state" };
    }

    // Verify there are pending items from this farmer
    const { data: farmerItems, error: itemsError } = await supabase
      .from("order_items")
      .select("id, pickup_status")
      .eq("order_id", orderId)
      .eq("farmer_id", farmerId);

    if (itemsError) {
      return { error: "Failed to fetch order items" };
    }

    if (!farmerItems || farmerItems.length === 0) {
      return { error: "No items from this farmer in this order" };
    }

    const pendingItems = farmerItems.filter(
      (i) => i.pickup_status === OrderItemStatus.PendingPickup,
    );

    if (pendingItems.length === 0) {
      return { error: "All items from this farmer are already processed" };
    }

    // Mark items as picked up
    const now = new Date().toISOString();
    const pendingIds = pendingItems.map((i) => i.id);
    const { error: updateError } = await supabase
      .from("order_items")
      .update({
        pickup_status: OrderItemStatus.PickedUp,
        pickup_confirmed: true,
        pickup_confirmed_at: now,
      })
      .in("id", pendingIds);

    if (updateError) {
      console.error("confirmFarmerPickup: update error:", updateError);
      return { error: "Failed to confirm pickup" };
    }

    // Check if all items in the order are now non-pending
    const { data: allItems, error: allItemsError } = await supabase
      .from("order_items")
      .select("pickup_status")
      .eq("order_id", orderId);

    if (allItemsError) {
      return { error: "Failed to check order item status" };
    }

    const stillPending = (allItems ?? []).some(
      (i) => i.pickup_status === OrderItemStatus.PendingPickup,
    );

    // If all items processed (picked up or unavailable), transition order to picked_up
    if (!stillPending && order.status === OrderStatus.Matched) {
      const { error: orderUpdateError } = await supabase
        .from("orders")
        .update({ status: OrderStatus.PickedUp })
        .eq("id", orderId);

      if (orderUpdateError) {
        console.error("confirmFarmerPickup: order status update error:", orderUpdateError);
      }
    }

    return {};
  } catch (err) {
    console.error("confirmFarmerPickup unexpected error:", err);
    return { error: "Failed to confirm farmer pickup" };
  }
}

// ---------------------------------------------------------------------------
// Mark items as unavailable (partial delivery handling)
// ---------------------------------------------------------------------------

/**
 * Mark items from a specific farmer as unavailable.
 * This handles the case where a farmer can't fulfill their items.
 *
 * If ALL items in the order become unavailable, the order is cancelled.
 * Otherwise, the farmer's payout is adjusted to 0 for unavailable items.
 */
export async function markItemsUnavailable(
  orderId: string,
  farmerId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    // Verify order
    const { data: order, error: fetchError } = await supabase
      .from("orders")
      .select("status, rider_id, total_price")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Order not found" };
    }

    // Only rider or the farmer themselves can mark items unavailable
    const isRider = order.rider_id === DEMO_RIDER_ID;
    // TODO: check if current user is the farmer when auth is implemented
    if (!isRider) {
      return { error: "Not authorized to mark items unavailable" };
    }

    const validStatuses = [OrderStatus.Matched, OrderStatus.PickedUp];
    if (!validStatuses.includes(order.status as OrderStatus)) {
      return { error: "Order is not in a state where items can be marked unavailable" };
    }

    // Get pending items from this farmer
    const { data: farmerItems, error: itemsError } = await supabase
      .from("order_items")
      .select("id, subtotal, pickup_status")
      .eq("order_id", orderId)
      .eq("farmer_id", farmerId);

    if (itemsError || !farmerItems) {
      return { error: "Failed to fetch farmer items" };
    }

    const pendingItems = farmerItems.filter(
      (i) => i.pickup_status === OrderItemStatus.PendingPickup,
    );

    if (pendingItems.length === 0) {
      return { error: "No pending items from this farmer" };
    }

    // Mark items as unavailable
    const { error: updateError } = await supabase
      .from("order_items")
      .update({ pickup_status: OrderItemStatus.Unavailable })
      .in("id", pendingItems.map((i) => i.id));

    if (updateError) {
      return { error: "Failed to mark items as unavailable" };
    }

    // Set farmer payout to 0 for this farmer (refund their portion)
    const { error: payoutError } = await supabase
      .from("farmer_payouts")
      .update({
        amount: 0,
        status: PayoutStatus.Refunded,
      })
      .eq("order_id", orderId)
      .eq("farmer_id", farmerId);

    if (payoutError) {
      console.error("markItemsUnavailable: payout update error:", payoutError);
    }

    // Recalculate order total: subtract unavailable items
    const unavailableSubtotal = pendingItems.reduce(
      (sum, i) => sum + Number(i.subtotal),
      0,
    );
    const newTotal = Math.max(0, Number(order.total_price) - unavailableSubtotal);

    // Check if ALL items in the order are now unavailable
    const { data: allItems } = await supabase
      .from("order_items")
      .select("pickup_status")
      .eq("order_id", orderId);

    const allUnavailable = (allItems ?? []).every(
      (i) => i.pickup_status === OrderItemStatus.Unavailable,
    );

    if (allUnavailable) {
      // Cancel the order entirely
      const { error: cancelError } = await supabase
        .from("orders")
        .update({
          status: OrderStatus.Cancelled,
          total_price: 0,
        })
        .eq("id", orderId);

      if (cancelError) {
        console.error("markItemsUnavailable: cancel error:", cancelError);
      }
    } else {
      // Update total price
      const { error: totalError } = await supabase
        .from("orders")
        .update({ total_price: Math.round(newTotal * 100) / 100 })
        .eq("id", orderId);

      if (totalError) {
        console.error("markItemsUnavailable: total update error:", totalError);
      }

      // Check if all remaining items are processed (no more pending)
      const stillPending = (allItems ?? []).some(
        (i) => i.pickup_status === OrderItemStatus.PendingPickup,
      );

      if (!stillPending && order.status === OrderStatus.Matched) {
        await supabase
          .from("orders")
          .update({ status: OrderStatus.PickedUp })
          .eq("id", orderId);
      }
    }

    return {};
  } catch (err) {
    console.error("markItemsUnavailable unexpected error:", err);
    return { error: "Failed to mark items unavailable" };
  }
}

// ---------------------------------------------------------------------------
// Standard order actions (updated for multi-farmer)
// ---------------------------------------------------------------------------

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
        ),
        farmerPayouts:farmer_payouts(*)
      `,
      )
      .eq("consumer_id", DEMO_CONSUMER_ID)
      .is("parent_order_id", null)
      .order("created_at", { ascending: false });

    if (statusFilter) {
      query = query.eq("status", statusFilter);
    }

    const { data, error } = await query;

    if (error) {
      console.error("listOrders error:", error);
      return { error: error.message };
    }

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
 * Includes farmer payouts and sub-orders if this is a parent order.
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
        trip:rider_trips!orders_rider_trip_id_fkey(id, origin_name, destination_name, departure_at),
        farmerPayouts:farmer_payouts(*)
      `,
      )
      .eq("id", orderId)
      .single();

    if (error) {
      console.error("getOrder error:", error);
      return { error: error.message };
    }

    const result = normalizeOrderRow(data);

    // If this is a parent order, fetch sub-orders
    const { data: subOrders } = await supabase
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
        trip:rider_trips!orders_rider_trip_id_fkey(id, origin_name, destination_name, departure_at),
        farmerPayouts:farmer_payouts(*)
      `,
      )
      .eq("parent_order_id", orderId);

    if (subOrders && subOrders.length > 0) {
      result.subOrders = subOrders.map((row) => normalizeOrderRow(row));
    }

    return { data: result };
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
      .select("status, consumer_id, payment_method, payment_status")
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

    // For eSewa orders that have been paid (escrowed), mark as refunded
    let newPaymentStatus = existing.payment_status;
    if (
      existing.payment_method === "esewa" &&
      existing.payment_status === PaymentStatus.Escrowed
    ) {
      newPaymentStatus = PaymentStatus.Refunded;

      const { error: txnError } = await supabase
        .from("esewa_transactions")
        .update({
          status: "REFUNDED",
          refunded_at: new Date().toISOString(),
        })
        .eq("order_id", orderId)
        .eq("status", "COMPLETE");

      if (txnError) {
        console.error("cancelOrder: failed to update eSewa transaction:", txnError);
      }
    }

    const { error } = await supabase
      .from("orders")
      .update({
        status: OrderStatus.Cancelled,
        payment_status: newPaymentStatus,
      })
      .eq("id", orderId);

    if (error) {
      console.error("cancelOrder error:", error);
      return { error: error.message };
    }

    // Mark all farmer payouts as refunded
    const { error: payoutError } = await supabase
      .from("farmer_payouts")
      .update({
        status: PayoutStatus.Refunded,
      })
      .eq("order_id", orderId)
      .eq("status", PayoutStatus.Pending);

    if (payoutError) {
      console.error("cancelOrder: payout refund error:", payoutError);
    }

    // Expire all pending pings for this order
    const { error: pingError } = await supabase
      .from("order_pings")
      .update({ status: PingStatus.Expired })
      .eq("order_id", orderId)
      .eq("status", PingStatus.Pending);

    if (pingError) {
      console.error("cancelOrder: failed to expire pings (non-fatal):", pingError);
    }

    return {};
  } catch (err) {
    console.error("cancelOrder unexpected error:", err);
    return { error: "Failed to cancel order" };
  }
}

/**
 * Consumer confirms delivery receipt.
 * Settles farmer payouts on delivery confirmation.
 */
export async function confirmDelivery(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("orders")
      .select("status, consumer_id, rider_id, payment_method, payment_status")
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

    let newPaymentStatus: string;
    if (existing.payment_method === "esewa" && existing.payment_status === PaymentStatus.Escrowed) {
      newPaymentStatus = PaymentStatus.Settled;

      const { error: txnError } = await supabase
        .from("esewa_transactions")
        .update({
          escrow_released_at: new Date().toISOString(),
          status: "SETTLED",
        })
        .eq("order_id", orderId)
        .eq("status", "COMPLETE");

      if (txnError) {
        console.error("confirmDelivery: failed to update eSewa transaction:", txnError);
      }
    } else {
      newPaymentStatus = PaymentStatus.Collected;
    }

    const { error } = await supabase
      .from("orders")
      .update({
        status: OrderStatus.Delivered,
        payment_status: newPaymentStatus,
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

    // Mark all delivery_confirmed on items
    await supabase
      .from("order_items")
      .update({ delivery_confirmed: true })
      .eq("order_id", orderId)
      .neq("pickup_status", OrderItemStatus.Unavailable);

    // Settle farmer payouts (only those still pending — unavailable ones are already refunded)
    const now = new Date().toISOString();
    const { error: payoutError } = await supabase
      .from("farmer_payouts")
      .update({
        status: PayoutStatus.Settled,
        settled_at: now,
      })
      .eq("order_id", orderId)
      .eq("status", PayoutStatus.Pending);

    if (payoutError) {
      console.error("confirmDelivery: payout settlement error:", payoutError);
    }

    return {};
  } catch (err) {
    console.error("confirmDelivery unexpected error:", err);
    return { error: "Failed to confirm delivery" };
  }
}

/**
 * Rider confirms pickup of an order.
 *
 * Legacy single-farmer support: marks all items as picked up.
 * For multi-farmer, prefer confirmFarmerPickup instead.
 */
export async function confirmPickup(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: existing, error: fetchError } = await supabase
      .from("orders")
      .select("status, rider_id, consumer_id")
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

    // Mark ALL items as picked up
    const now = new Date().toISOString();
    await supabase
      .from("order_items")
      .update({
        pickup_status: OrderItemStatus.PickedUp,
        pickup_confirmed: true,
        pickup_confirmed_at: now,
      })
      .eq("order_id", orderId)
      .eq("pickup_status", OrderItemStatus.PendingPickup);

    const { error } = await supabase
      .from("orders")
      .update({ status: OrderStatus.PickedUp })
      .eq("id", orderId);

    if (error) {
      console.error("confirmPickup error:", error);
      return { error: error.message };
    }

    // Notify consumer that produce was picked up
    notifyRiderPickedUp(existing.consumer_id, orderId).catch(
      (err) => console.error("Notification error (rider picked up):", err),
    );

    return {};
  } catch (err) {
    console.error("confirmPickup unexpected error:", err);
    return { error: "Failed to confirm pickup" };
  }
}

/**
 * Rider marks order as in transit after all pickups done.
 * Validates that all items are either picked_up or unavailable (none pending).
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

    // Verify no items are still pending pickup
    const { data: pendingItems } = await supabase
      .from("order_items")
      .select("id")
      .eq("order_id", orderId)
      .eq("pickup_status", OrderItemStatus.PendingPickup);

    if (pendingItems && pendingItems.length > 0) {
      return { error: "Some items are still pending pickup. Complete all pickups first." };
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
        ),
        farmerPayouts:farmer_payouts(*)
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

/**
 * Get farmer payout summary for a specific farmer.
 * Returns all payouts across orders for this farmer.
 */
export async function getFarmerPayouts(
  farmerId: string,
): Promise<ActionResult<{ pending: number; settled: number; refunded: number; payouts: unknown[] }>> {
  try {
    const supabase = createServiceRoleClient();

    const { data: payouts, error } = await supabase
      .from("farmer_payouts")
      .select("*, order:orders(id, status, created_at)")
      .eq("farmer_id", farmerId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("getFarmerPayouts error:", error);
      return { error: error.message };
    }

    const pending = (payouts ?? [])
      .filter((p) => p.status === PayoutStatus.Pending)
      .reduce((sum, p) => sum + Number(p.amount), 0);
    const settled = (payouts ?? [])
      .filter((p) => p.status === PayoutStatus.Settled)
      .reduce((sum, p) => sum + Number(p.amount), 0);
    const refunded = (payouts ?? [])
      .filter((p) => p.status === PayoutStatus.Refunded)
      .reduce((sum, p) => sum + Number(p.amount), 0);

    return {
      data: {
        pending: Math.round(pending * 100) / 100,
        settled: Math.round(settled * 100) / 100,
        refunded: Math.round(refunded * 100) / 100,
        payouts: payouts ?? [],
      },
    };
  } catch (err) {
    console.error("getFarmerPayouts unexpected error:", err);
    return { error: "Failed to get farmer payouts" };
  }
}

/**
 * Reorder item availability result.
 */
export interface ReorderItemAvailability {
  listingId: string;
  farmerId: string;
  nameEn: string;
  nameNe: string;
  farmerName: string;
  photo: string | null;
  originalQtyKg: number;
  originalPricePerKg: number;
  currentPricePerKg: number | null;
  availableQtyKg: number | null;
  isActive: boolean;
  available: boolean;
}

/**
 * Check availability of items from a previous order for reordering.
 */
export async function checkReorderAvailability(
  orderId: string,
): Promise<ActionResult<ReorderItemAvailability[]>> {
  try {
    const supabase = createServiceRoleClient();

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("consumer_id")
      .eq("id", orderId)
      .single();

    if (orderError) {
      console.error("checkReorderAvailability: order fetch error:", orderError);
      return { error: "Order not found" };
    }

    if (order.consumer_id !== DEMO_CONSUMER_ID) {
      return { error: "You can only reorder your own orders" };
    }

    const { data: items, error: itemsError } = await supabase
      .from("order_items")
      .select(
        `
        listing_id,
        farmer_id,
        quantity_kg,
        price_per_kg,
        listing:produce_listings!order_items_listing_id_fkey(
          name_en, name_ne, photos, price_per_kg, available_qty_kg, is_active
        ),
        farmer:users!order_items_farmer_id_fkey(name)
      `,
      )
      .eq("order_id", orderId);

    if (itemsError) {
      console.error("checkReorderAvailability: items fetch error:", itemsError);
      return { error: "Failed to fetch order items" };
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const result: ReorderItemAvailability[] = (items ?? []).map((item: any) => {
      const listing = Array.isArray(item.listing)
        ? item.listing[0]
        : item.listing;
      const farmer = Array.isArray(item.farmer)
        ? item.farmer[0]
        : item.farmer;

      const isActive = listing?.is_active ?? false;
      const availableQty = listing?.available_qty_kg ?? 0;
      const currentPrice = listing?.price_per_kg ?? null;
      const available = isActive && availableQty > 0;

      return {
        listingId: item.listing_id,
        farmerId: item.farmer_id,
        nameEn: listing?.name_en ?? "",
        nameNe: listing?.name_ne ?? "",
        farmerName: farmer?.name ?? "",
        photo: listing?.photos?.[0] ?? null,
        originalQtyKg: item.quantity_kg,
        originalPricePerKg: item.price_per_kg,
        currentPricePerKg: currentPrice,
        availableQtyKg: availableQty,
        isActive,
        available,
      };
    });

    return { data: result };
  } catch (err) {
    console.error("checkReorderAvailability unexpected error:", err);
    return { error: "Failed to check reorder availability" };
  }
}

// ---------------------------------------------------------------------------
// Normalize Supabase row to OrderWithDetails
// ---------------------------------------------------------------------------

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
    farmerPayouts: row.farmerPayouts ?? row.farmer_payouts ?? undefined,
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
