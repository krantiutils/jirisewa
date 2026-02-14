"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireAdmin } from "./auth";
import { revalidatePath } from "next/cache";

type ActionResult =
  | { success: true }
  | { success: false; error: string };

// ── User Actions ────────────────────────────────────────────

export async function updateOrderStatus(
  locale: string,
  orderId: string,
  status: string,
): Promise<ActionResult> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const validStatuses = [
    "pending",
    "matched",
    "picked_up",
    "in_transit",
    "delivered",
    "cancelled",
    "disputed",
  ];

  if (!validStatuses.includes(status)) {
    return { success: false, error: `Invalid status: ${status}` };
  }

  const { error } = await supabase
    .from("orders")
    .update({ status: status as never })
    .eq("id", orderId);

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath(`/${locale}/admin/orders`);
  revalidatePath(`/${locale}/admin/orders/${orderId}`);
  return { success: true };
}

export async function forceResolveOrder(
  locale: string,
  orderId: string,
): Promise<ActionResult> {
  return updateOrderStatus(locale, orderId, "delivered");
}

export async function cancelOrder(
  locale: string,
  orderId: string,
): Promise<ActionResult> {
  return updateOrderStatus(locale, orderId, "cancelled");
}

export async function verifyFarmer(
  locale: string,
  roleId: string,
): Promise<ActionResult> {
  const adminId = await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  // Verify that documents have been submitted
  const { data: docs } = await supabase
    .from("verification_documents")
    .select("id")
    .eq("user_role_id", roleId)
    .limit(1);

  if (!docs || docs.length === 0) {
    return { success: false, error: "Cannot approve: no documents submitted" };
  }

  const { error } = await supabase
    .from("user_roles")
    .update({
      verified: true,
      verification_status: "approved" as const,
    })
    .eq("id", roleId);

  if (error) {
    return { success: false, error: error.message };
  }

  // Mark the verification document as reviewed
  await supabase
    .from("verification_documents")
    .update({
      reviewed_by: adminId,
      reviewed_at: new Date().toISOString(),
    })
    .eq("user_role_id", roleId)
    .order("created_at", { ascending: false })
    .limit(1);

  revalidatePath(`/${locale}/admin/farmers`);
  revalidatePath(`/${locale}/admin`);
  return { success: true };
}

export async function rejectFarmerVerification(
  locale: string,
  roleId: string,
  notes?: string,
): Promise<ActionResult> {
  const adminId = await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  // Set verification_status to rejected
  const { error } = await supabase
    .from("user_roles")
    .update({
      verified: false,
      verification_status: "rejected" as const,
    })
    .eq("id", roleId);

  if (error) {
    return { success: false, error: error.message };
  }

  // Mark the verification document as reviewed with notes
  await supabase
    .from("verification_documents")
    .update({
      admin_notes: notes ?? null,
      reviewed_by: adminId,
      reviewed_at: new Date().toISOString(),
    })
    .eq("user_role_id", roleId)
    .order("created_at", { ascending: false })
    .limit(1);

  revalidatePath(`/${locale}/admin/farmers`);
  revalidatePath(`/${locale}/admin`);
  return { success: true };
}

export async function deactivateListing(
  locale: string,
  listingId: string,
): Promise<ActionResult> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const { error } = await supabase
    .from("produce_listings")
    .update({ is_active: false })
    .eq("id", listingId);

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath(`/${locale}/admin`);
  return { success: true };
}
