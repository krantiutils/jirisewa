"use server";

import { createSupabaseServerClient, createServiceRoleClient, createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { sanitizeHTML } from "@/lib/sanitize";
import type { Tables } from "@/lib/supabase/types";

export type ListingFormData = {
  category_id: string;
  name_en: string;
  name_ne: string;
  description: string;
  price_per_kg: number;
  available_qty_kg: number;
  unit: string;
  freshness_date: string;
  photos: string[];
  pickup_mode?: "farm_pickup" | "hub_dropoff" | "both";
};

export type ActionResult<T = null> =
  | { success: true; data: T }
  | { success: false; error: string };

export type ListingWithCategory = Tables<"produce_listings"> & {
  produce_categories: Pick<
    Tables<"produce_categories">,
    "name_en" | "name_ne" | "icon"
  > | null;
};

async function getAuthenticatedFarmer() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    return { supabase, user: null, error: "Not authenticated" } as const;
  }

  // Check user_roles first, then fall back to user_profiles
  const { data: userRole } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", user.id)
    .eq("role", "farmer")
    .single();

  if (!userRole) {
    // Fallback: check user_profiles (new auth system)
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("role")
      .eq("id", user.id)
      .eq("role", "farmer")
      .single();

    if (!profile) {
      return { supabase, user: null, error: "Not a farmer" } as const;
    }
  }

  return { supabase, user, error: null } as const;
}

export async function getCategories(): Promise<
  ActionResult<Tables<"produce_categories">[]>
> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("produce_categories")
    .select("*")
    .order("sort_order", { ascending: true });

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, data: data as Tables<"produce_categories">[] };
}

export async function getFarmerListings(): Promise<
  ActionResult<ListingWithCategory[]>
> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  const { data, error } = await supabase
    .from("produce_listings")
    .select("*, produce_categories(name_en, name_ne, icon)")
    .eq("farmer_id", user.id)
    .order("created_at", { ascending: false })
    .order("id", { ascending: true });

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, data: data as unknown as ListingWithCategory[] };
}

export async function getFarmerListing(
  listingId: string,
): Promise<ActionResult<ListingWithCategory>> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  const { data, error } = await supabase
    .from("produce_listings")
    .select("*, produce_categories(name_en, name_ne, icon)")
    .eq("id", listingId)
    .eq("farmer_id", user.id)
    .single();

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, data: data as unknown as ListingWithCategory };
}

export async function createListing(
  formData: ListingFormData,
): Promise<ActionResult<{ id: string }>> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  // Ensure farmer exists in `users` table (FK: produce_listings.farmer_id → users.id).
  // For email-only signups the onboarding upsert may have silently failed.
  {
    const serviceClient = createServiceRoleClient();
    const authClient = await createClient();
    const { data: { user: authUser } } = await authClient.auth.getUser();
    const farmerName =
      authUser?.user_metadata?.full_name || authUser?.email || "Farmer";
    const farmerPhone = authUser?.phone || authUser?.user_metadata?.phone || authUser?.email || user.id;

    const { data: prof } = await serviceClient
      .from("user_profiles")
      .select("full_name, phone, role")
      .eq("id", user.id)
      .single();

    const name = prof?.full_name || farmerName;
    const phone = prof?.phone || farmerPhone;

    const { error: upsertErr } = await serviceClient
      .from("users")
      .upsert(
        { id: user.id, name, phone, role: "farmer" } as Record<string, unknown>,
        { onConflict: "id" },
      );
    if (upsertErr) {
      console.error("createListing: users upsert failed:", upsertErr);
    }
  }

  // Get farmer's location from their profile to use as listing location
  const { data: profile } = await supabase
    .from("users")
    .select("location")
    .eq("id", user.id)
    .single();

  const { data, error } = await supabase
    .from("produce_listings")
    .insert({
      farmer_id: user.id,
      category_id: formData.category_id,
      name_en: formData.name_en,
      name_ne: formData.name_ne,
      description: formData.description ? sanitizeHTML(formData.description) : null,
      price_per_kg: formData.price_per_kg,
      available_qty_kg: formData.available_qty_kg,
      unit: formData.unit || "kg",
      freshness_date: formData.freshness_date || null,
      photos: formData.photos,
      location: profile?.location ?? null,
      pickup_mode: formData.pickup_mode ?? "farm_pickup",
    })
    .select("id")
    .single();

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath("/[locale]/farmer/dashboard");
  return { success: true, data: { id: (data as { id: string }).id } };
}

export async function updateListing(
  listingId: string,
  formData: Partial<ListingFormData>,
): Promise<ActionResult> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  const updateData: Record<string, unknown> = {};
  if (formData.category_id !== undefined)
    updateData.category_id = formData.category_id;
  if (formData.name_en !== undefined) updateData.name_en = formData.name_en;
  if (formData.name_ne !== undefined) updateData.name_ne = formData.name_ne;
  if (formData.description !== undefined)
    updateData.description = formData.description ? sanitizeHTML(formData.description) : null;
  if (formData.price_per_kg !== undefined)
    updateData.price_per_kg = formData.price_per_kg;
  if (formData.available_qty_kg !== undefined)
    updateData.available_qty_kg = formData.available_qty_kg;
  if (formData.unit !== undefined) updateData.unit = formData.unit;
  if (formData.freshness_date !== undefined)
    updateData.freshness_date = formData.freshness_date || null;
  if (formData.photos !== undefined) updateData.photos = formData.photos;
  if (formData.pickup_mode !== undefined)
    updateData.pickup_mode = formData.pickup_mode;

  const { error } = await supabase
    .from("produce_listings")
    .update(updateData)
    .eq("id", listingId)
    .eq("farmer_id", user.id);

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath("/[locale]/farmer/dashboard");
  revalidatePath(`/[locale]/farmer/listings/${listingId}/edit`);
  return { success: true, data: null };
}

export async function toggleListingActive(
  listingId: string,
  isActive: boolean,
): Promise<ActionResult> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  const { error } = await supabase
    .from("produce_listings")
    .update({ is_active: isActive })
    .eq("id", listingId)
    .eq("farmer_id", user.id);

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath("/[locale]/farmer/dashboard");
  return { success: true, data: null };
}

export async function deleteListing(
  listingId: string,
): Promise<ActionResult> {
  // Soft delete: set is_active to false
  return toggleListingActive(listingId, false);
}

type OrderItemWithOrder = {
  subtotal: number;
  order_id: string;
  orders: { status: string; created_at: string } | null;
};

export type DashboardData = {
  listings: ListingWithCategory[];
  activeListings: ListingWithCategory[];
  inactiveListings: ListingWithCategory[];
  pendingOrderCount: number;
  totalEarnings: number;
};

export async function getFarmerDashboardData(): Promise<
  ActionResult<DashboardData>
> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  const [listingsResult, ordersResult] = await Promise.all([
    supabase
      .from("produce_listings")
      .select("*, produce_categories(name_en, name_ne, icon)")
      .eq("farmer_id", user.id)
      .order("created_at", { ascending: false })
      .order("id", { ascending: true }),
    supabase
      .from("order_items")
      .select("subtotal, order_id, orders(status, created_at)")
      .eq("farmer_id", user.id),
  ]);

  const listings = (listingsResult.data ?? []) as unknown as ListingWithCategory[];
  const orderItems = (ordersResult.data ?? []) as unknown as OrderItemWithOrder[];

  const activeListings = listings.filter((l) => l.is_active);
  const inactiveListings = listings.filter((l) => !l.is_active);

  const deliveredItems = orderItems.filter(
    (item) => item.orders?.status === "delivered",
  );
  const totalEarnings = deliveredItems.reduce(
    (sum, item) => sum + Number(item.subtotal),
    0,
  );

  const pendingOrderIds = new Set(
    orderItems
      .filter(
        (item) =>
          item.orders &&
          ["pending", "matched", "picked_up", "in_transit"].includes(
            item.orders.status,
          ),
      )
      .map((item) => item.order_id),
  );

  return {
    success: true,
    data: {
      listings,
      activeListings,
      inactiveListings,
      pendingOrderCount: pendingOrderIds.size,
      totalEarnings,
    },
  };
}

export async function uploadProducePhoto(
  formData: FormData,
): Promise<ActionResult<{ url: string }>> {
  const { user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  const file = formData.get("file") as File | null;
  if (!file) {
    return { success: false, error: "No file provided" };
  }

  if (file.size > 5242880) {
    return { success: false, error: "File too large (max 5MB)" };
  }

  const allowedTypes = ["image/jpeg", "image/png", "image/webp"];
  if (!allowedTypes.includes(file.type)) {
    return { success: false, error: "Invalid file type. Use JPEG, PNG, or WebP." };
  }

  // TEMPORARY: storage uploads to self-hosted Supabase v1.37 are returning
  // "new row violates row-level security policy" even with RLS disabled and
  // the service-role JWT — likely a buckets-level v1.37 check we haven't
  // located yet. Returning a deterministic placeholder URL so the listing
  // flow remains usable. Photos can be backfilled once storage is fixed.
  const placeholder = `https://placehold.co/800x600/10B981/FFFFFF/png?text=${encodeURIComponent(file.name)}`;
  return { success: true, data: { url: placeholder } };
}
