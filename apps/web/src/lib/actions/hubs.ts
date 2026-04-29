"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

type ActionResult<T = null> = { success: true; data: T } | { success: false; error: string };

export interface HubChoice {
  id: string;
  name_en: string;
  address: string;
  hub_type: string;
}

export interface DropoffRow {
  id: string;
  hub_id: string;
  hub_name: string;
  listing_id: string;
  listing_name: string;
  farmer_id: string;
  farmer_name: string;
  quantity_kg: number;
  lot_code: string;
  status: string;
  dropped_at: string;
  received_at: string | null;
  dispatched_at: string | null;
  expires_at: string;
  notes: string | null;
}

export async function listOriginHubs(): Promise<HubChoice[]> {
  // Authenticated reads only — RLS policy pickup_hubs_select_active gates this.
  // Unauthenticated calls return [].
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];
  const { data } = await supabase
    .from("pickup_hubs")
    .select("id, name_en, address, hub_type")
    .eq("is_active", true)
    .in("hub_type", ["origin", "transit"])
    .order("name_en");
  return (data ?? []) as HubChoice[];
}

export async function listMyDropoffs(): Promise<DropoffRow[]> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];

  const { data } = await supabase
    .from("hub_dropoffs")
    .select(
      "id, hub_id, listing_id, farmer_id, quantity_kg, lot_code, status, dropped_at, received_at, dispatched_at, expires_at, notes, hub:pickup_hubs!hub_dropoffs_hub_id_fkey(name_en), listing:produce_listings!hub_dropoffs_listing_id_fkey(name_en), farmer:users!hub_dropoffs_farmer_id_fkey(name)",
    )
    .eq("farmer_id", user.id)
    .order("dropped_at", { ascending: false })
    .limit(50);

  type Raw = DropoffRow & {
    hub: { name_en: string } | null;
    listing: { name_en: string } | null;
    farmer: { name: string } | null;
  };
  return ((data ?? []) as unknown as Raw[]).map((d) => ({
    id: d.id,
    hub_id: d.hub_id,
    hub_name: d.hub?.name_en ?? "",
    listing_id: d.listing_id,
    listing_name: d.listing?.name_en ?? "",
    farmer_id: d.farmer_id,
    farmer_name: d.farmer?.name ?? "",
    quantity_kg: d.quantity_kg,
    lot_code: d.lot_code,
    status: d.status,
    dropped_at: d.dropped_at,
    received_at: d.received_at,
    dispatched_at: d.dispatched_at,
    expires_at: d.expires_at,
    notes: d.notes,
  }));
}

export async function recordHubDropoff(input: {
  hub_id: string;
  listing_id: string;
  quantity_kg: number;
}): Promise<
  ActionResult<{ dropoff_id: string; lot_code: string; expires_at: string }>
> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { success: false, error: "Not authenticated" };

  const { data, error } = await supabase.rpc("record_hub_dropoff_v1", {
    p_hub_id: input.hub_id,
    p_listing_id: input.listing_id,
    p_quantity_kg: input.quantity_kg,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { dropoff_id: string; lot_code: string; expires_at: string };

  revalidatePath("/[locale]/farmer/hubs");
  return { success: true, data: result };
}

export async function listFarmerActiveListings(): Promise<
  { id: string; name_en: string; pickup_mode: string }[]
> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];

  const { data } = await supabase
    .from("produce_listings")
    .select("id, name_en, pickup_mode")
    .eq("farmer_id", user.id)
    .eq("is_active", true)
    .order("name_en");
  return (data ?? []) as { id: string; name_en: string; pickup_mode: string }[];
}

// ── Operator side ───────────────────────────────────────────

export async function getMyOperatedHub(): Promise<{
  id: string;
  name_en: string;
  address: string;
} | null> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("pickup_hubs")
    .select("id, name_en, address")
    .eq("operator_id", user.id)
    .eq("is_active", true)
    .order("created_at")
    .limit(1)
    .maybeSingle();
  return data;
}

export async function listHubInventory(hubId: string): Promise<DropoffRow[]> {
  const supabase = await createSupabaseServerClient();

  const { data } = await supabase
    .from("hub_dropoffs")
    .select(
      "id, hub_id, listing_id, farmer_id, quantity_kg, lot_code, status, dropped_at, received_at, dispatched_at, expires_at, notes, hub:pickup_hubs!hub_dropoffs_hub_id_fkey(name_en), listing:produce_listings!hub_dropoffs_listing_id_fkey(name_en), farmer:users!hub_dropoffs_farmer_id_fkey(name)",
    )
    .eq("hub_id", hubId)
    .order("dropped_at", { ascending: false })
    .limit(200);

  type Raw = DropoffRow & {
    hub: { name_en: string } | null;
    listing: { name_en: string } | null;
    farmer: { name: string } | null;
  };
  return ((data ?? []) as unknown as Raw[]).map((d) => ({
    id: d.id,
    hub_id: d.hub_id,
    hub_name: d.hub?.name_en ?? "",
    listing_id: d.listing_id,
    listing_name: d.listing?.name_en ?? "",
    farmer_id: d.farmer_id,
    farmer_name: d.farmer?.name ?? "",
    quantity_kg: d.quantity_kg,
    lot_code: d.lot_code,
    status: d.status,
    dropped_at: d.dropped_at,
    received_at: d.received_at,
    dispatched_at: d.dispatched_at,
    expires_at: d.expires_at,
    notes: d.notes,
  }));
}

export async function markDropoffReceived(
  dropoffId: string,
): Promise<ActionResult<{ dropoff_id: string; status: string }>> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("mark_dropoff_received_v1", {
    p_dropoff_id: dropoffId,
  });
  if (error) return { success: false, error: error.message };
  revalidatePath("/[locale]/hub");
  return { success: true, data: data as { dropoff_id: string; status: string } };
}

export async function markDropoffSpoiled(
  dropoffId: string,
  notes?: string,
): Promise<ActionResult<{ dropoff_id: string; status: string }>> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("mark_dropoff_spoiled_v1", {
    p_dropoff_id: dropoffId,
    p_notes: notes ?? null,
  });
  if (error) return { success: false, error: error.message };
  revalidatePath("/[locale]/hub");
  return { success: true, data: data as { dropoff_id: string; status: string } };
}

export async function dispatchDropoff(
  dropoffId: string,
  riderTripId: string,
): Promise<ActionResult<{ dropoff_id: string; status: string }>> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("dispatch_dropoff_v1", {
    p_dropoff_id: dropoffId,
    p_rider_trip_id: riderTripId,
  });
  if (error) return { success: false, error: error.message };
  revalidatePath("/[locale]/hub");
  return { success: true, data: data as { dropoff_id: string; status: string } };
}
