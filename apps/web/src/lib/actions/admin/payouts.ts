"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import { requireAdmin } from "@/lib/admin/auth";
import { revalidatePath } from "next/cache";

type ActionResult =
  | { success: true }
  | { success: false; error: string };

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface AdminPayoutRequest {
  id: string;
  user_id: string;
  amount: number;
  method: string;
  account_details: Record<string, string>;
  status: string;
  admin_notes: string | null;
  created_at: string;
  processed_at: string | null;
  processed_by: string | null;
  user: { id: string; name: string; phone: string } | null;
}

// ---------------------------------------------------------------------------
// listPayoutRequests
// ---------------------------------------------------------------------------

/**
 * List all payout requests, optionally filtered by status.
 * Fetches user details separately since payout_requests.user_id
 * references auth.users, not public.users.
 */
export async function listPayoutRequests(
  locale: string,
  opts: {
    page?: number;
    limit?: number;
    status?: string;
  } = {},
): Promise<{ requests: AdminPayoutRequest[]; total: number }> {
  await requireAdmin(locale);
  const supabase = createServiceRoleClient();

  const page = opts.page ?? 1;
  const limit = opts.limit ?? 20;
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let query = supabase
    .from("payout_requests")
    .select(
      "id, user_id, amount, method, account_details, status, admin_notes, created_at, processed_at, processed_by",
      { count: "exact" },
    )
    .order("created_at", { ascending: false })
    .range(from, to);

  if (opts.status && opts.status !== "all") {
    query = query.eq("status", opts.status);
  }

  const { data, count, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch payout requests: ${error.message}`);
  }

  const rows = data ?? [];

  // Fetch user details for all unique user IDs
  const userIds = [...new Set(rows.map((r) => r.user_id))];
  const userMap: Record<string, { id: string; name: string; phone: string }> = {};

  if (userIds.length > 0) {
    const { data: users } = await supabase
      .from("users")
      .select("id, name, phone")
      .in("id", userIds);

    if (users) {
      for (const u of users) {
        userMap[u.id] = u;
      }
    }
  }

  const requests: AdminPayoutRequest[] = rows.map((row) => ({
    id: row.id,
    user_id: row.user_id,
    amount: Number(row.amount),
    method: row.method,
    account_details: row.account_details as Record<string, string>,
    status: row.status,
    admin_notes: row.admin_notes,
    created_at: row.created_at,
    processed_at: row.processed_at,
    processed_by: row.processed_by,
    user: userMap[row.user_id] ?? null,
  }));

  return {
    requests,
    total: count ?? 0,
  };
}

// ---------------------------------------------------------------------------
// processPayoutRequest
// ---------------------------------------------------------------------------

/**
 * Process a payout request: update its status and optionally add admin notes.
 *
 * Valid transitions:
 *   pending -> processing
 *   pending -> rejected
 *   processing -> completed
 *   processing -> rejected
 *
 * When completed: mark the user's related pending earnings as 'settled'.
 */
export async function processPayoutRequest(
  locale: string,
  id: string,
  input: { status: string; adminNotes?: string },
): Promise<ActionResult> {
  const adminId = await requireAdmin(locale);
  const supabase = createServiceRoleClient();

  // Fetch current payout request
  const { data: existing, error: fetchError } = await supabase
    .from("payout_requests")
    .select("id, user_id, amount, status")
    .eq("id", id)
    .single();

  if (fetchError || !existing) {
    return { success: false, error: "Payout request not found" };
  }

  // Validate status transition
  const validTransitions: Record<string, string[]> = {
    pending: ["processing", "rejected"],
    processing: ["completed", "rejected"],
  };

  const allowed = validTransitions[existing.status];
  if (!allowed || !allowed.includes(input.status)) {
    return {
      success: false,
      error: `Cannot transition from '${existing.status}' to '${input.status}'`,
    };
  }

  const now = new Date().toISOString();

  // Update payout request
  const { error: updateError } = await supabase
    .from("payout_requests")
    .update({
      status: input.status,
      admin_notes: input.adminNotes ?? null,
      processed_at: now,
      processed_by: adminId,
    })
    .eq("id", id);

  if (updateError) {
    return { success: false, error: updateError.message };
  }

  // When completed: settle pending earnings for this user up to the payout amount
  if (input.status === "completed") {
    const { error: settleError } = await supabase
      .from("earnings")
      .update({
        status: "settled",
        settled_at: now,
        settled_by: adminId,
      })
      .eq("user_id", existing.user_id)
      .eq("status", "pending");

    if (settleError) {
      console.error("processPayoutRequest: failed to settle earnings:", settleError);
      // Non-fatal: the payout status was already updated
    }
  }

  revalidatePath(`/${locale}/admin/payouts`);
  return { success: true };
}
