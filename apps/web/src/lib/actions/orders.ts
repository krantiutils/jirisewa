"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Tables } from "@/lib/supabase/types";

export type ActionResult<T = null> =
  | { success: true; data: T }
  | { success: false; error: string };

export type OrderWithDetails = Tables<"orders"> & {
  order_items: (Tables<"order_items"> & {
    produce_listings: Pick<Tables<"produce_listings">, "name_en" | "name_ne"> | null;
  })[];
  rider: Pick<Tables<"users">, "id" | "name" | "avatar_url" | "rating_avg" | "rating_count"> | null;
};

/**
 * Fetch orders for the currently authenticated user.
 * Returns orders where the user is the consumer, rider, or farmer (via order_items).
 * RLS ensures only orders the user is a party to are returned.
 */
export async function getMyOrders(): Promise<ActionResult<OrderWithDetails[]>> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return { success: false, error: "Not authenticated" };
  }

  const { data, error } = await supabase
    .from("orders")
    .select("*, order_items(*, produce_listings(name_en, name_ne))")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("getMyOrders error:", error);
    return { success: false, error: "Failed to fetch orders" };
  }

  const orders = (data ?? []) as unknown as (Tables<"orders"> & {
    order_items: (Tables<"order_items"> & {
      produce_listings: Pick<Tables<"produce_listings">, "name_en" | "name_ne"> | null;
    })[];
  })[];

  // Fetch rider info for orders that have a rider_id
  const riderIds = [...new Set(orders.map((o) => o.rider_id).filter(Boolean))] as string[];
  let riderMap = new Map<string, Pick<Tables<"users">, "id" | "name" | "avatar_url" | "rating_avg" | "rating_count">>();

  if (riderIds.length > 0) {
    const { data: riders } = await supabase
      .from("users")
      .select("id, name, avatar_url, rating_avg, rating_count")
      .in("id", riderIds);

    if (riders) {
      riderMap = new Map(riders.map((r) => [r.id, r]));
    }
  }

  const ordersWithRider: OrderWithDetails[] = orders.map((order) => ({
    ...order,
    rider: order.rider_id ? (riderMap.get(order.rider_id) ?? null) : null,
  }));

  return { success: true, data: ordersWithRider };
}
