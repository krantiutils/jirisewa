"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

/**
 * Get estimated delivery minutes for a batch of listings to a delivery point.
 * Uses PostGIS ST_Distance + configurable speed assumptions.
 */
export async function getBatchDeliveryETAs(input: {
  listingIds: string[];
  deliveryLat: number;
  deliveryLng: number;
}): Promise<ActionResult<Record<string, number>>> {
  if (input.listingIds.length === 0) return { data: {} };

  const supabase = createServiceRoleClient();
  const deliveryPoint = `POINT(${input.deliveryLng} ${input.deliveryLat})`;

  const { data: distances, error } = await supabase.rpc(
    "batch_delivery_etas",
    {
      p_listing_ids: input.listingIds,
      p_delivery_point: deliveryPoint,
      p_avg_speed_kmh: 30,
      p_pickup_buffer_min: 15,
    },
  );

  if (error) {
    // Graceful fallback if RPC doesn't exist yet
    return { data: {} };
  }

  const result: Record<string, number> = {};
  for (const row of distances ?? []) {
    result[row.listing_id] = row.eta_minutes;
  }
  return { data: result };
}
