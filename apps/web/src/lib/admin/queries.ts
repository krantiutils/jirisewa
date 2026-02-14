"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireAdmin } from "./auth";

// ── Platform Stats ──────────────────────────────────────────

export interface PlatformStats {
  totalUsers: number;
  totalFarmers: number;
  totalConsumers: number;
  totalRiders: number;
  totalOrders: number;
  totalRevenue: number;
  activeListings: number;
  pendingDisputes: number;
  unverifiedFarmers: number;
}

export async function getPlatformStats(
  locale: string,
): Promise<PlatformStats> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const [
    usersResult,
    farmersResult,
    consumersResult,
    ridersResult,
    ordersResult,
    revenueResult,
    listingsResult,
    disputesResult,
    unverifiedResult,
  ] = await Promise.all([
    supabase.from("users").select("id", { count: "exact", head: true }),
    supabase
      .from("user_roles")
      .select("id", { count: "exact", head: true })
      .eq("role", "farmer"),
    supabase
      .from("user_roles")
      .select("id", { count: "exact", head: true })
      .eq("role", "consumer"),
    supabase
      .from("user_roles")
      .select("id", { count: "exact", head: true })
      .eq("role", "rider"),
    supabase.from("orders").select("id", { count: "exact", head: true }),
    supabase.from("orders").select("delivery_fee"),
    supabase
      .from("produce_listings")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true),
    supabase
      .from("orders")
      .select("id", { count: "exact", head: true })
      .eq("status", "disputed"),
    supabase
      .from("user_roles")
      .select("id", { count: "exact", head: true })
      .eq("role", "farmer")
      .eq("verified", false),
  ]);

  const totalRevenue =
    revenueResult.data?.reduce(
      (sum, o) => sum + (Number(o.delivery_fee) || 0),
      0,
    ) ?? 0;

  return {
    totalUsers: usersResult.count ?? 0,
    totalFarmers: farmersResult.count ?? 0,
    totalConsumers: consumersResult.count ?? 0,
    totalRiders: ridersResult.count ?? 0,
    totalOrders: ordersResult.count ?? 0,
    totalRevenue,
    activeListings: listingsResult.count ?? 0,
    pendingDisputes: disputesResult.count ?? 0,
    unverifiedFarmers: unverifiedResult.count ?? 0,
  };
}

// ── Users ───────────────────────────────────────────────────

export interface AdminUser {
  id: string;
  phone: string;
  name: string;
  role: "farmer" | "consumer" | "rider";
  avatar_url: string | null;
  address: string | null;
  municipality: string | null;
  rating_avg: number;
  rating_count: number;
  is_admin: boolean;
  created_at: string;
}

export interface AdminUserRole {
  id: string;
  role: "farmer" | "consumer" | "rider";
  farm_name: string | null;
  vehicle_type: string | null;
  vehicle_capacity_kg: number | null;
  verified: boolean;
}

export async function getUsers(
  locale: string,
  opts: {
    page?: number;
    limit?: number;
    search?: string;
    role?: string;
  } = {},
): Promise<{ users: AdminUser[]; total: number }> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const page = opts.page ?? 1;
  const limit = opts.limit ?? 20;
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let query = supabase
    .from("users")
    .select(
      "id, phone, name, role, avatar_url, address, municipality, rating_avg, rating_count, is_admin, created_at",
      { count: "exact" },
    )
    .order("created_at", { ascending: false })
    .range(from, to);

  if (opts.search) {
    query = query.or(
      `name.ilike.%${opts.search}%,phone.ilike.%${opts.search}%`,
    );
  }

  if (opts.role && opts.role !== "all") {
    query = query.eq(
      "role",
      opts.role as "farmer" | "consumer" | "rider",
    );
  }

  const { data, count, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch users: ${error.message}`);
  }

  return { users: data ?? [], total: count ?? 0 };
}

export async function getUserRoles(
  locale: string,
  userId: string,
): Promise<AdminUserRole[]> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("user_roles")
    .select(
      "id, role, farm_name, vehicle_type, vehicle_capacity_kg, verified",
    )
    .eq("user_id", userId);

  if (error) {
    throw new Error(`Failed to fetch user roles: ${error.message}`);
  }

  return data ?? [];
}

// ── Orders ──────────────────────────────────────────────────

export interface AdminOrder {
  id: string;
  status: string;
  delivery_address: string;
  total_price: number;
  delivery_fee: number;
  payment_method: string;
  payment_status: string;
  created_at: string;
  consumer: { id: string; name: string; phone: string } | null;
  rider: { id: string; name: string; phone: string } | null;
}

export async function getOrders(
  locale: string,
  opts: {
    page?: number;
    limit?: number;
    status?: string;
    search?: string;
  } = {},
): Promise<{ orders: AdminOrder[]; total: number }> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const page = opts.page ?? 1;
  const limit = opts.limit ?? 20;
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let query = supabase
    .from("orders")
    .select(
      "id, status, delivery_address, total_price, delivery_fee, payment_method, payment_status, created_at, consumer:users!orders_consumer_id_fkey(id, name, phone), rider:users!orders_rider_id_fkey(id, name, phone)",
      { count: "exact" },
    )
    .order("created_at", { ascending: false })
    .range(from, to);

  if (opts.status && opts.status !== "all") {
    query = query.eq(
      "status",
      opts.status as
        | "pending"
        | "matched"
        | "picked_up"
        | "in_transit"
        | "delivered"
        | "cancelled"
        | "disputed",
    );
  }

  const { data, count, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch orders: ${error.message}`);
  }

  return { orders: (data as unknown as AdminOrder[]) ?? [], total: count ?? 0 };
}

export interface AdminOrderDetail {
  id: string;
  status: string;
  delivery_address: string;
  total_price: number;
  delivery_fee: number;
  payment_method: string;
  payment_status: string;
  created_at: string;
  updated_at: string;
  consumer: { id: string; name: string; phone: string } | null;
  rider: { id: string; name: string; phone: string } | null;
  items: {
    id: string;
    quantity_kg: number;
    price_per_kg: number;
    subtotal: number;
    pickup_confirmed: boolean;
    delivery_confirmed: boolean;
    listing: { name_en: string; name_ne: string } | null;
    farmer: { id: string; name: string } | null;
  }[];
}

export async function getOrderDetail(
  locale: string,
  orderId: string,
): Promise<AdminOrderDetail | null> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select(
      "id, status, delivery_address, total_price, delivery_fee, payment_method, payment_status, created_at, updated_at, consumer:users!orders_consumer_id_fkey(id, name, phone), rider:users!orders_rider_id_fkey(id, name, phone)",
    )
    .eq("id", orderId)
    .single();

  if (orderError || !order) return null;

  const { data: items } = await supabase
    .from("order_items")
    .select(
      "id, quantity_kg, price_per_kg, subtotal, pickup_confirmed, delivery_confirmed, listing:produce_listings(name_en, name_ne), farmer:users!order_items_farmer_id_fkey(id, name)",
    )
    .eq("order_id", orderId);

  return {
    ...(order as unknown as Omit<AdminOrderDetail, "items">),
    items: (items as unknown as AdminOrderDetail["items"]) ?? [],
  };
}

// ── Disputes ────────────────────────────────────────────────

export async function getDisputedOrders(
  locale: string,
  opts: {
    page?: number;
    limit?: number;
  } = {},
): Promise<{ orders: AdminOrder[]; total: number }> {
  return getOrders(locale, { ...opts, status: "disputed" });
}

// ── Farmer Verification ─────────────────────────────────────

export interface FarmerVerificationEntry {
  id: string;
  user_id: string;
  farm_name: string | null;
  verified: boolean;
  created_at: string;
  user: { id: string; name: string; phone: string; address: string | null };
}

export async function getUnverifiedFarmers(
  locale: string,
  opts: {
    page?: number;
    limit?: number;
  } = {},
): Promise<{ farmers: FarmerVerificationEntry[]; total: number }> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const page = opts.page ?? 1;
  const limit = opts.limit ?? 20;
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  const { data, count, error } = await supabase
    .from("user_roles")
    .select(
      "id, user_id, farm_name, verified, created_at, user:users!user_roles_user_id_fkey(id, name, phone, address)",
      { count: "exact" },
    )
    .eq("role", "farmer")
    .eq("verified", false)
    .order("created_at", { ascending: true })
    .range(from, to);

  if (error) {
    throw new Error(`Failed to fetch unverified farmers: ${error.message}`);
  }

  return {
    farmers: (data as unknown as FarmerVerificationEntry[]) ?? [],
    total: count ?? 0,
  };
}
