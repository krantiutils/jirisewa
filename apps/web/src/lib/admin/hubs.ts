"use server";

import { createSupabaseServerClient, createServiceRoleClient } from "@/lib/supabase/server";
import { requireAdmin } from "./auth";
import { revalidatePath } from "next/cache";

export type HubType = "origin" | "destination" | "transit";

export interface HubRow {
  id: string;
  name_en: string;
  name_ne: string;
  address: string;
  hub_type: HubType;
  is_active: boolean;
  operator_id: string | null;
  operator_name: string | null;
  municipality_id: string | null;
  municipality_name: string | null;
  lat: number;
  lng: number;
  created_at: string;
}

interface RawHub {
  id: string;
  name_en: string;
  name_ne: string;
  address: string;
  hub_type: HubType;
  is_active: boolean;
  operator_id: string | null;
  municipality_id: string | null;
  location: string | null;
  created_at: string;
  operator: { name: string } | null;
  municipality: { name_en: string } | null;
}

function parsePoint(value: string | null): { lat: number; lng: number } {
  if (!value) return { lat: 0, lng: 0 };
  const wkt = value.match(/POINT\(([-\d.]+)\s+([-\d.]+)\)/);
  if (wkt) return { lng: parseFloat(wkt[1]), lat: parseFloat(wkt[2]) };
  if (/^[0-9a-fA-F]+$/.test(value) && value.length >= 50) {
    const buf = Buffer.from(value, "hex");
    const lng = buf.readDoubleLE(9);
    const lat = buf.readDoubleLE(17);
    return { lat, lng };
  }
  return { lat: 0, lng: 0 };
}

export async function listHubs(locale: string): Promise<HubRow[]> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const { data } = await supabase
    .from("pickup_hubs")
    .select(
      "id, name_en, name_ne, address, hub_type, is_active, operator_id, municipality_id, location, created_at, operator:users!pickup_hubs_operator_id_fkey(name), municipality:municipalities!pickup_hubs_municipality_id_fkey(name_en)",
    )
    .order("created_at", { ascending: false });

  return ((data ?? []) as unknown as RawHub[]).map((h) => {
    const { lat, lng } = parsePoint(h.location);
    return {
      id: h.id,
      name_en: h.name_en,
      name_ne: h.name_ne,
      address: h.address,
      hub_type: h.hub_type,
      is_active: h.is_active,
      operator_id: h.operator_id,
      operator_name: h.operator?.name ?? null,
      municipality_id: h.municipality_id,
      municipality_name: h.municipality?.name_en ?? null,
      lat,
      lng,
      created_at: h.created_at,
    };
  });
}

export async function getHub(locale: string, id: string): Promise<HubRow | null> {
  await requireAdmin(locale);
  const all = await listHubs(locale);
  return all.find((h) => h.id === id) ?? null;
}

export interface HubUpsertInput {
  name_en: string;
  name_ne: string;
  address: string;
  hub_type: HubType;
  lat: number;
  lng: number;
  operator_id: string | null;
  municipality_id: string | null;
  is_active: boolean;
}

export async function createHub(
  locale: string,
  input: HubUpsertInput,
): Promise<{ id: string } | { error: string }> {
  await requireAdmin(locale);
  const svc = createServiceRoleClient();

  const { data, error } = await svc
    .from("pickup_hubs")
    .insert({
      name_en: input.name_en,
      name_ne: input.name_ne,
      address: input.address,
      hub_type: input.hub_type,
      operator_id: input.operator_id,
      municipality_id: input.municipality_id,
      is_active: input.is_active,
      location: `POINT(${input.lng} ${input.lat})`,
    })
    .select("id")
    .single();

  if (error || !data) return { error: error?.message ?? "Failed to create hub" };
  revalidatePath(`/${locale}/admin/hubs`);
  return { id: data.id };
}

export async function updateHub(
  locale: string,
  id: string,
  input: HubUpsertInput,
): Promise<{ ok: true } | { error: string }> {
  await requireAdmin(locale);
  const svc = createServiceRoleClient();

  const { error } = await svc
    .from("pickup_hubs")
    .update({
      name_en: input.name_en,
      name_ne: input.name_ne,
      address: input.address,
      hub_type: input.hub_type,
      operator_id: input.operator_id,
      municipality_id: input.municipality_id,
      is_active: input.is_active,
      location: `POINT(${input.lng} ${input.lat})`,
    })
    .eq("id", id);

  if (error) return { error: error.message };
  revalidatePath(`/${locale}/admin/hubs`);
  revalidatePath(`/${locale}/admin/hubs/${id}`);
  return { ok: true };
}

export async function disableHub(
  locale: string,
  id: string,
): Promise<{ ok: true } | { error: string }> {
  await requireAdmin(locale);
  const svc = createServiceRoleClient();
  const { error } = await svc.from("pickup_hubs").update({ is_active: false }).eq("id", id);
  if (error) return { error: error.message };
  revalidatePath(`/${locale}/admin/hubs`);
  return { ok: true };
}

export async function listHubOperators(): Promise<{ id: string; name: string }[]> {
  const svc = createServiceRoleClient();
  const { data } = await svc
    .from("user_roles")
    .select("user_id, users!user_roles_user_id_fkey(id, name)")
    .eq("role", "hub_operator");
  type Row = { user_id: string; users: { id: string; name: string } | null };
  const seen = new Set<string>();
  const out: { id: string; name: string }[] = [];
  for (const r of (data ?? []) as unknown as Row[]) {
    if (r.users && !seen.has(r.users.id)) {
      seen.add(r.users.id);
      out.push({ id: r.users.id, name: r.users.name });
    }
  }
  return out;
}

export async function listMunicipalitiesForHub(): Promise<{ id: string; name: string }[]> {
  const svc = createServiceRoleClient();
  const { data } = await svc
    .from("municipalities")
    .select("id, name_en, district")
    .order("name_en", { ascending: true })
    .limit(500);
  return (data ?? []).map((m) => ({
    id: m.id,
    name: `${m.name_en} (${m.district})`,
  }));
}
