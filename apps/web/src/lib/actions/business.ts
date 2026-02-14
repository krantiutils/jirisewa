"use server";

import { BulkOrderStatus, BulkItemStatus } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import type {
  BusinessProfile,
  BulkOrderWithDetails,
  BulkOrderItemWithDetails,
  CreateBusinessProfileInput,
  CreateBulkOrderInput,
} from "@/lib/types/business";

// TODO: Replace with authenticated user when auth is fully implemented
const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";

// ---------------------------------------------------------------------------
// Business Profile
// ---------------------------------------------------------------------------

export async function getBusinessProfile(): Promise<ActionResult<BusinessProfile | null>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("business_profiles")
      .select("*")
      .eq("user_id", DEMO_CONSUMER_ID)
      .maybeSingle();

    if (error) {
      console.error("getBusinessProfile error:", error);
      return { error: error.message };
    }

    return { data: data as BusinessProfile | null };
  } catch (err) {
    console.error("getBusinessProfile unexpected error:", err);
    return { error: "Failed to get business profile" };
  }
}

export async function createBusinessProfile(
  input: CreateBusinessProfileInput,
): Promise<ActionResult<BusinessProfile>> {
  try {
    if (!input.business_name || input.business_name.trim().length === 0) {
      return { error: "Business name is required" };
    }
    if (!input.address || input.address.trim().length === 0) {
      return { error: "Address is required" };
    }

    const validTypes = ["restaurant", "hotel", "canteen", "other"] as const;
    if (!validTypes.includes(input.business_type)) {
      return { error: "Invalid business type" };
    }

    const supabase = createServiceRoleClient();

    // Check if profile already exists
    const { data: existing } = await supabase
      .from("business_profiles")
      .select("id")
      .eq("user_id", DEMO_CONSUMER_ID)
      .maybeSingle();

    if (existing) {
      return { error: "Business profile already exists. Use update instead." };
    }

    const { data, error } = await supabase
      .from("business_profiles")
      .insert({
        user_id: DEMO_CONSUMER_ID,
        business_name: input.business_name.trim(),
        business_type: input.business_type,
        registration_number: input.registration_number?.trim() || null,
        address: input.address.trim(),
        phone: input.phone?.trim() || null,
        contact_person: input.contact_person?.trim() || null,
      })
      .select("*")
      .single();

    if (error) {
      console.error("createBusinessProfile error:", error);
      return { error: error.message };
    }

    return { data: data as BusinessProfile };
  } catch (err) {
    console.error("createBusinessProfile unexpected error:", err);
    return { error: "Failed to create business profile" };
  }
}

export async function updateBusinessProfile(
  input: Partial<CreateBusinessProfileInput>,
): Promise<ActionResult<BusinessProfile>> {
  try {
    const supabase = createServiceRoleClient();

    const updateData: Record<string, unknown> = {};
    if (input.business_name !== undefined) updateData.business_name = input.business_name.trim();
    if (input.business_type !== undefined) updateData.business_type = input.business_type;
    if (input.registration_number !== undefined) updateData.registration_number = input.registration_number?.trim() || null;
    if (input.address !== undefined) updateData.address = input.address.trim();
    if (input.phone !== undefined) updateData.phone = input.phone?.trim() || null;
    if (input.contact_person !== undefined) updateData.contact_person = input.contact_person?.trim() || null;

    const { data, error } = await supabase
      .from("business_profiles")
      .update(updateData)
      .eq("user_id", DEMO_CONSUMER_ID)
      .select("*")
      .single();

    if (error) {
      console.error("updateBusinessProfile error:", error);
      return { error: error.message };
    }

    return { data: data as BusinessProfile };
  } catch (err) {
    console.error("updateBusinessProfile unexpected error:", err);
    return { error: "Failed to update business profile" };
  }
}

// ---------------------------------------------------------------------------
// Bulk Orders
// ---------------------------------------------------------------------------

export async function createBulkOrder(
  input: CreateBulkOrderInput,
): Promise<ActionResult<{ orderId: string }>> {
  try {
    if (input.items.length === 0) {
      return { error: "At least one item is required" };
    }

    if (!input.delivery_address || input.delivery_address.trim().length === 0) {
      return { error: "Delivery address is required" };
    }

    const supabase = createServiceRoleClient();

    // Get business profile
    const { data: profile, error: profileError } = await supabase
      .from("business_profiles")
      .select("id")
      .eq("user_id", DEMO_CONSUMER_ID)
      .single();

    if (profileError || !profile) {
      return { error: "Business profile not found. Please register first." };
    }

    // Validate listings exist and are active
    const listingIds = input.items.map((i) => i.listingId);
    const { data: listings, error: listingError } = await supabase
      .from("produce_listings")
      .select("id, farmer_id, price_per_kg, available_qty_kg, name_en")
      .in("id", listingIds)
      .eq("is_active", true);

    if (listingError) {
      console.error("createBulkOrder: listing fetch error:", listingError);
      return { error: "Failed to verify produce listings" };
    }

    if (!listings || listings.length !== listingIds.length) {
      return { error: "One or more produce items are no longer available" };
    }

    const listingMap = new Map(listings.map((l) => [l.id, l]));

    // Validate items
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
    }

    // Calculate total from server-side prices
    const totalAmount = input.items.reduce((sum, item) => {
      const listing = listingMap.get(item.listingId)!;
      return sum + item.quantityKg * listing.price_per_kg;
    }, 0);

    // Build delivery location WKT if coordinates provided
    let deliveryLocation: string | null = null;
    if (
      input.delivery_lat !== undefined &&
      input.delivery_lng !== undefined &&
      input.delivery_lat >= -90 && input.delivery_lat <= 90 &&
      input.delivery_lng >= -180 && input.delivery_lng <= 180
    ) {
      deliveryLocation = `POINT(${input.delivery_lng} ${input.delivery_lat})`;
    }

    // Create the bulk order
    const { data: order, error: orderError } = await supabase
      .from("bulk_orders")
      .insert({
        business_id: profile.id,
        status: BulkOrderStatus.Submitted,
        delivery_address: input.delivery_address.trim(),
        delivery_location: deliveryLocation,
        delivery_frequency: input.delivery_frequency,
        delivery_schedule: input.delivery_schedule ?? null,
        total_amount: Math.round(totalAmount * 100) / 100,
        notes: input.notes?.trim() || null,
      })
      .select("id")
      .single();

    if (orderError) {
      console.error("createBulkOrder: order insert error:", orderError);
      return { error: orderError.message };
    }

    // Create order items
    const orderItems = input.items.map((item) => {
      const listing = listingMap.get(item.listingId)!;
      return {
        bulk_order_id: order.id,
        produce_listing_id: item.listingId,
        farmer_id: item.farmerId,
        quantity_kg: item.quantityKg,
        price_per_kg: listing.price_per_kg,
        status: BulkItemStatus.Pending,
      };
    });

    const { error: itemsError } = await supabase
      .from("bulk_order_items")
      .insert(orderItems);

    if (itemsError) {
      console.error("createBulkOrder: items insert error:", itemsError);
      // Cleanup order on failure
      await supabase.from("bulk_orders").delete().eq("id", order.id);
      return { error: itemsError.message };
    }

    return { data: { orderId: order.id } };
  } catch (err) {
    console.error("createBulkOrder unexpected error:", err);
    return { error: "Failed to create bulk order" };
  }
}

export async function listBulkOrders(
  statusFilter?: string,
): Promise<ActionResult<BulkOrderWithDetails[]>> {
  try {
    const supabase = createServiceRoleClient();

    // Get business profile
    const { data: profile } = await supabase
      .from("business_profiles")
      .select("id")
      .eq("user_id", DEMO_CONSUMER_ID)
      .maybeSingle();

    if (!profile) {
      return { data: [] };
    }

    let query = supabase
      .from("bulk_orders")
      .select(
        `
        *,
        items:bulk_order_items(
          *,
          listing:produce_listings!bulk_order_items_produce_listing_id_fkey(name_en, name_ne, photos),
          farmer:users!bulk_order_items_farmer_id_fkey(id, name, avatar_url)
        )
      `,
      )
      .eq("business_id", profile.id)
      .order("created_at", { ascending: false });

    if (statusFilter) {
      query = query.eq("status", statusFilter);
    }

    const { data, error } = await query;

    if (error) {
      console.error("listBulkOrders error:", error);
      return { error: error.message };
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const orders: BulkOrderWithDetails[] = (data ?? []).map((row: any) => ({
      ...row,
      items: (row.items ?? []).map(normalizeBulkItem),
    }));

    return { data: orders };
  } catch (err) {
    console.error("listBulkOrders unexpected error:", err);
    return { error: "Failed to list bulk orders" };
  }
}

export async function getBulkOrder(
  orderId: string,
): Promise<ActionResult<BulkOrderWithDetails>> {
  try {
    const supabase = createServiceRoleClient();

    const { data, error } = await supabase
      .from("bulk_orders")
      .select(
        `
        *,
        items:bulk_order_items(
          *,
          listing:produce_listings!bulk_order_items_produce_listing_id_fkey(name_en, name_ne, photos),
          farmer:users!bulk_order_items_farmer_id_fkey(id, name, avatar_url)
        ),
        business:business_profiles!bulk_orders_business_id_fkey(*)
      `,
      )
      .eq("id", orderId)
      .single();

    if (error) {
      console.error("getBulkOrder error:", error);
      return { error: error.message };
    }

    const order: BulkOrderWithDetails = {
      ...data,
      items: (data.items ?? []).map(normalizeBulkItem),
      business: Array.isArray(data.business) ? data.business[0] : data.business,
    };

    return { data: order };
  } catch (err) {
    console.error("getBulkOrder unexpected error:", err);
    return { error: "Failed to get bulk order" };
  }
}

export async function cancelBulkOrder(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: order, error: fetchError } = await supabase
      .from("bulk_orders")
      .select("status, business_id")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Bulk order not found" };
    }

    // Verify ownership
    const { data: profile } = await supabase
      .from("business_profiles")
      .select("id")
      .eq("user_id", DEMO_CONSUMER_ID)
      .single();

    if (!profile || order.business_id !== profile.id) {
      return { error: "Not authorized to cancel this order" };
    }

    const cancellable = [
      BulkOrderStatus.Draft,
      BulkOrderStatus.Submitted,
      BulkOrderStatus.Quoted,
    ];
    if (!cancellable.includes(order.status as BulkOrderStatus)) {
      return { error: "This order cannot be cancelled in its current state" };
    }

    const { error } = await supabase
      .from("bulk_orders")
      .update({ status: BulkOrderStatus.Cancelled })
      .eq("id", orderId);

    if (error) {
      console.error("cancelBulkOrder error:", error);
      return { error: error.message };
    }

    // Cancel all pending items
    await supabase
      .from("bulk_order_items")
      .update({ status: BulkItemStatus.Cancelled })
      .eq("bulk_order_id", orderId)
      .in("status", [BulkItemStatus.Pending, BulkItemStatus.Quoted]);

    return {};
  } catch (err) {
    console.error("cancelBulkOrder unexpected error:", err);
    return { error: "Failed to cancel bulk order" };
  }
}

// ---------------------------------------------------------------------------
// Farmer actions on bulk orders
// ---------------------------------------------------------------------------

export async function listFarmerBulkOrders(): Promise<ActionResult<BulkOrderWithDetails[]>> {
  try {
    const supabase = createServiceRoleClient();

    // For demo, use farmer ID directly
    const DEMO_FARMER_ID = "00000000-0000-0000-0000-000000000002";

    const { data: itemRows, error: itemsError } = await supabase
      .from("bulk_order_items")
      .select("bulk_order_id")
      .eq("farmer_id", DEMO_FARMER_ID);

    if (itemsError) {
      console.error("listFarmerBulkOrders: items error:", itemsError);
      return { error: itemsError.message };
    }

    if (!itemRows || itemRows.length === 0) {
      return { data: [] };
    }

    const orderIds = [...new Set(itemRows.map((r) => r.bulk_order_id))];

    const { data, error } = await supabase
      .from("bulk_orders")
      .select(
        `
        *,
        items:bulk_order_items(
          *,
          listing:produce_listings!bulk_order_items_produce_listing_id_fkey(name_en, name_ne, photos),
          farmer:users!bulk_order_items_farmer_id_fkey(id, name, avatar_url)
        ),
        business:business_profiles!bulk_orders_business_id_fkey(*)
      `,
      )
      .in("id", orderIds)
      .neq("status", BulkOrderStatus.Draft)
      .neq("status", BulkOrderStatus.Cancelled)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("listFarmerBulkOrders error:", error);
      return { error: error.message };
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const orders: BulkOrderWithDetails[] = (data ?? []).map((row: any) => ({
      ...row,
      items: (row.items ?? []).map(normalizeBulkItem),
      business: Array.isArray(row.business) ? row.business[0] : row.business,
    }));

    return { data: orders };
  } catch (err) {
    console.error("listFarmerBulkOrders unexpected error:", err);
    return { error: "Failed to list farmer bulk orders" };
  }
}

export async function quoteBulkOrderItem(
  itemId: string,
  quotedPricePerKg: number,
  farmerNotes?: string,
): Promise<ActionResult> {
  try {
    if (quotedPricePerKg <= 0) {
      return { error: "Quoted price must be greater than 0" };
    }

    const supabase = createServiceRoleClient();
    const DEMO_FARMER_ID = "00000000-0000-0000-0000-000000000002";

    const { data: item, error: fetchError } = await supabase
      .from("bulk_order_items")
      .select("id, farmer_id, status, bulk_order_id")
      .eq("id", itemId)
      .single();

    if (fetchError || !item) {
      return { error: "Item not found" };
    }

    if (item.farmer_id !== DEMO_FARMER_ID) {
      return { error: "Not authorized to quote this item" };
    }

    if (item.status !== BulkItemStatus.Pending) {
      return { error: "This item is not in a quotable state" };
    }

    const { error } = await supabase
      .from("bulk_order_items")
      .update({
        quoted_price_per_kg: Math.round(quotedPricePerKg * 100) / 100,
        status: BulkItemStatus.Quoted,
        farmer_notes: farmerNotes?.trim() || null,
      })
      .eq("id", itemId);

    if (error) {
      console.error("quoteBulkOrderItem error:", error);
      return { error: error.message };
    }

    // Check if all items in the order are now quoted or rejected
    const { data: allItems } = await supabase
      .from("bulk_order_items")
      .select("status")
      .eq("bulk_order_id", item.bulk_order_id);

    const allResponded = (allItems ?? []).every(
      (i) => i.status !== BulkItemStatus.Pending,
    );

    if (allResponded) {
      await supabase
        .from("bulk_orders")
        .update({ status: BulkOrderStatus.Quoted })
        .eq("id", item.bulk_order_id)
        .eq("status", BulkOrderStatus.Submitted);
    }

    return {};
  } catch (err) {
    console.error("quoteBulkOrderItem unexpected error:", err);
    return { error: "Failed to quote item" };
  }
}

export async function rejectBulkOrderItem(
  itemId: string,
  farmerNotes?: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();
    const DEMO_FARMER_ID = "00000000-0000-0000-0000-000000000002";

    const { data: item, error: fetchError } = await supabase
      .from("bulk_order_items")
      .select("id, farmer_id, status, bulk_order_id")
      .eq("id", itemId)
      .single();

    if (fetchError || !item) {
      return { error: "Item not found" };
    }

    if (item.farmer_id !== DEMO_FARMER_ID) {
      return { error: "Not authorized to reject this item" };
    }

    if (item.status !== BulkItemStatus.Pending) {
      return { error: "This item is not in a rejectable state" };
    }

    const { error } = await supabase
      .from("bulk_order_items")
      .update({
        status: BulkItemStatus.Rejected,
        farmer_notes: farmerNotes?.trim() || null,
      })
      .eq("id", itemId);

    if (error) {
      console.error("rejectBulkOrderItem error:", error);
      return { error: error.message };
    }

    // Check if all items in the order are now responded (quoted or rejected)
    const { data: allItems } = await supabase
      .from("bulk_order_items")
      .select("status")
      .eq("bulk_order_id", item.bulk_order_id);

    const allResponded = (allItems ?? []).every(
      (i) => i.status !== BulkItemStatus.Pending,
    );

    if (allResponded) {
      await supabase
        .from("bulk_orders")
        .update({ status: BulkOrderStatus.Quoted })
        .eq("id", item.bulk_order_id)
        .eq("status", BulkOrderStatus.Submitted);
    }

    return {};
  } catch (err) {
    console.error("rejectBulkOrderItem unexpected error:", err);
    return { error: "Failed to reject item" };
  }
}

// Business accepts the quoted prices
export async function acceptBulkOrder(
  orderId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();

    const { data: order, error: fetchError } = await supabase
      .from("bulk_orders")
      .select("status, business_id")
      .eq("id", orderId)
      .single();

    if (fetchError) {
      return { error: "Bulk order not found" };
    }

    const { data: profile } = await supabase
      .from("business_profiles")
      .select("id")
      .eq("user_id", DEMO_CONSUMER_ID)
      .single();

    if (!profile || order.business_id !== profile.id) {
      return { error: "Not authorized" };
    }

    if (order.status !== BulkOrderStatus.Quoted) {
      return { error: "Order must be in quoted state to accept" };
    }

    // Accept all quoted items
    const { error: itemsError } = await supabase
      .from("bulk_order_items")
      .update({ status: BulkItemStatus.Accepted })
      .eq("bulk_order_id", orderId)
      .eq("status", BulkItemStatus.Quoted);

    if (itemsError) {
      console.error("acceptBulkOrder: items update error:", itemsError);
      return { error: "Failed to accept items" };
    }

    // Recalculate total based on quoted prices
    const { data: acceptedItems } = await supabase
      .from("bulk_order_items")
      .select("quantity_kg, quoted_price_per_kg")
      .eq("bulk_order_id", orderId)
      .eq("status", BulkItemStatus.Accepted);

    const newTotal = (acceptedItems ?? []).reduce(
      (sum, item) => sum + item.quantity_kg * (item.quoted_price_per_kg ?? 0),
      0,
    );

    const { error } = await supabase
      .from("bulk_orders")
      .update({
        status: BulkOrderStatus.Accepted,
        total_amount: Math.round(newTotal * 100) / 100,
      })
      .eq("id", orderId);

    if (error) {
      console.error("acceptBulkOrder error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("acceptBulkOrder unexpected error:", err);
    return { error: "Failed to accept bulk order" };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function normalizeBulkItem(item: any): BulkOrderItemWithDetails {
  return {
    ...item,
    listing: Array.isArray(item.listing) ? item.listing[0] : item.listing,
    farmer: Array.isArray(item.farmer) ? item.farmer[0] : item.farmer,
  };
}
