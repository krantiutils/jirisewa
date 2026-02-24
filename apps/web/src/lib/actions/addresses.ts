"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

export interface SavedAddress {
  id: string;
  label: string;
  addressText: string;
  lat: number;
  lng: number;
  isDefault: boolean;
}

// Helper: get authenticated user ID
async function getAuthUserId(): Promise<string | null> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id ?? null;
}

// Helper: parse EWKB hex point (same pattern used in delivery-fee.ts)
function parseEwkbPoint(hex: string): { lat: number; lng: number } | null {
  if (hex.length < 50) return null;
  const buf = Buffer.from(hex, "hex");
  const lng = buf.readDoubleLE(9);
  const lat = buf.readDoubleLE(17);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  return { lat, lng };
}

export async function listAddresses(): Promise<ActionResult<SavedAddress[]>> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();
  const { data, error } = await supabase
    .from("user_addresses")
    .select("id, label, address_text, location, is_default")
    .eq("user_id", userId)
    .order("is_default", { ascending: false })
    .order("created_at", { ascending: false });

  if (error) return { error: error.message };

  return {
    data: (data ?? []).map((row) => {
      const point = parseEwkbPoint(row.location as string);
      return {
        id: row.id,
        label: row.label,
        addressText: row.address_text,
        lat: point?.lat ?? 0,
        lng: point?.lng ?? 0,
        isDefault: row.is_default,
      };
    }),
  };
}

export async function createAddress(input: {
  label: string;
  addressText: string;
  lat: number;
  lng: number;
  isDefault?: boolean;
}): Promise<ActionResult<SavedAddress>> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();

  // If setting as default, unset existing default first
  if (input.isDefault) {
    await supabase
      .from("user_addresses")
      .update({ is_default: false })
      .eq("user_id", userId)
      .eq("is_default", true);
  }

  const { data, error } = await supabase
    .from("user_addresses")
    .insert({
      user_id: userId,
      label: input.label,
      address_text: input.addressText,
      location: `POINT(${input.lng} ${input.lat})`,
      is_default: input.isDefault ?? false,
    })
    .select("id, label, address_text, location, is_default")
    .single();

  if (error) return { error: error.message };

  const point = parseEwkbPoint(data.location as string);
  return {
    data: {
      id: data.id,
      label: data.label,
      addressText: data.address_text,
      lat: point?.lat ?? input.lat,
      lng: point?.lng ?? input.lng,
      isDefault: data.is_default,
    },
  };
}

export async function updateAddress(
  id: string,
  input: {
    label?: string;
    addressText?: string;
    lat?: number;
    lng?: number;
    isDefault?: boolean;
  },
): Promise<ActionResult> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();

  if (input.isDefault) {
    await supabase
      .from("user_addresses")
      .update({ is_default: false })
      .eq("user_id", userId)
      .eq("is_default", true);
  }

  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
  if (input.label !== undefined) updates.label = input.label;
  if (input.addressText !== undefined) updates.address_text = input.addressText;
  if (input.lat !== undefined && input.lng !== undefined) {
    updates.location = `POINT(${input.lng} ${input.lat})`;
  }
  if (input.isDefault !== undefined) updates.is_default = input.isDefault;

  const { error } = await supabase
    .from("user_addresses")
    .update(updates)
    .eq("id", id)
    .eq("user_id", userId);

  if (error) return { error: error.message };
  return { data: undefined };
}

export async function deleteAddress(id: string): Promise<ActionResult> {
  const userId = await getAuthUserId();
  if (!userId) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();
  const { error } = await supabase
    .from("user_addresses")
    .delete()
    .eq("id", id)
    .eq("user_id", userId);

  if (error) return { error: error.message };
  return { data: undefined };
}
