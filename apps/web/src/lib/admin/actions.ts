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
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  const { error } = await supabase
    .from("user_roles")
    .update({ verified: true })
    .eq("id", roleId);

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath(`/${locale}/admin/farmers`);
  revalidatePath(`/${locale}/admin`);
  return { success: true };
}

export async function rejectFarmerVerification(
  locale: string,
  roleId: string,
): Promise<ActionResult> {
  await requireAdmin(locale);
  const supabase = await createSupabaseServerClient();

  // For rejection we just leave verified=false. The farmer can re-apply.
  // We could also delete the role, but that's more destructive.
  // For now this is a no-op since they're already unverified,
  // but we keep this action for UI completeness and future audit logging.
  revalidatePath(`/${locale}/admin/farmers`);
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
