"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface EarningsSummary {
  totalEarned: number;
  pendingBalance: number;
  settledBalance: number;
  totalWithdrawn: number;
  totalRequested: number;
}

export interface EarningItem {
  id: string;
  orderId: string;
  amount: number;
  status: string;
  role: string;
  createdAt: string;
}

export interface PayoutRequest {
  id: string;
  userId: string;
  amount: number;
  method: string;
  accountDetails: Record<string, string>;
  status: string;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function getAuthUserId(): Promise<string | null> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id ?? null;
}

// ---------------------------------------------------------------------------
// getEarningsSummary
// ---------------------------------------------------------------------------

/**
 * Get earnings summary for the authenticated user.
 * Returns totals for earned, pending, settled, withdrawn, and requested amounts.
 */
export async function getEarningsSummary(): Promise<ActionResult<EarningsSummary>> {
  try {
    const userId = await getAuthUserId();
    if (!userId) {
      return { error: "Not authenticated" };
    }

    const supabase = createServiceRoleClient();

    // Fetch all earnings for this user
    const { data: earnings, error: earningsError } = await supabase
      .from("earnings")
      .select("amount, status")
      .eq("user_id", userId);

    if (earningsError) {
      console.error("getEarningsSummary: earnings fetch error:", earningsError);
      return { error: "Failed to fetch earnings" };
    }

    const earningsRows = earnings ?? [];
    const totalEarned = earningsRows.reduce(
      (sum, row) => sum + Number(row.amount),
      0,
    );
    const pendingBalance = earningsRows
      .filter((row) => row.status === "pending")
      .reduce((sum, row) => sum + Number(row.amount), 0);
    const settledBalance = earningsRows
      .filter((row) => row.status === "settled")
      .reduce((sum, row) => sum + Number(row.amount), 0);

    // Fetch payout requests for this user
    const { data: payouts, error: payoutsError } = await supabase
      .from("payout_requests")
      .select("amount, status")
      .eq("user_id", userId);

    if (payoutsError) {
      console.error("getEarningsSummary: payouts fetch error:", payoutsError);
      return { error: "Failed to fetch payout requests" };
    }

    const payoutRows = payouts ?? [];
    const totalWithdrawn = payoutRows
      .filter((row) => row.status === "completed")
      .reduce((sum, row) => sum + Number(row.amount), 0);
    const totalRequested = payoutRows
      .filter((row) => row.status === "pending" || row.status === "processing")
      .reduce((sum, row) => sum + Number(row.amount), 0);

    return {
      data: {
        totalEarned: Math.round(totalEarned * 100) / 100,
        pendingBalance: Math.round(pendingBalance * 100) / 100,
        settledBalance: Math.round(settledBalance * 100) / 100,
        totalWithdrawn: Math.round(totalWithdrawn * 100) / 100,
        totalRequested: Math.round(totalRequested * 100) / 100,
      },
    };
  } catch (err) {
    console.error("getEarningsSummary unexpected error:", err);
    return { error: "Failed to get earnings summary" };
  }
}

// ---------------------------------------------------------------------------
// listEarnings
// ---------------------------------------------------------------------------

const PAGE_SIZE = 20;

/**
 * List earnings for the authenticated user with pagination.
 * Optionally filter by earnings status.
 */
export async function listEarnings(
  page: number,
  status?: string,
): Promise<ActionResult<{ items: EarningItem[]; total: number }>> {
  try {
    const userId = await getAuthUserId();
    if (!userId) {
      return { error: "Not authenticated" };
    }

    const supabase = createServiceRoleClient();
    const offset = (Math.max(1, page) - 1) * PAGE_SIZE;

    // Build count query
    let countQuery = supabase
      .from("earnings")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId);

    if (status) {
      countQuery = countQuery.eq("status", status);
    }

    const { count, error: countError } = await countQuery;

    if (countError) {
      console.error("listEarnings: count error:", countError);
      return { error: "Failed to count earnings" };
    }

    // Build data query
    let dataQuery = supabase
      .from("earnings")
      .select("id, order_id, amount, status, role, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .range(offset, offset + PAGE_SIZE - 1);

    if (status) {
      dataQuery = dataQuery.eq("status", status);
    }

    const { data, error } = await dataQuery;

    if (error) {
      console.error("listEarnings: fetch error:", error);
      return { error: "Failed to fetch earnings" };
    }

    const items: EarningItem[] = (data ?? []).map((row) => ({
      id: row.id,
      orderId: row.order_id,
      amount: Number(row.amount),
      status: row.status,
      role: row.role,
      createdAt: row.created_at,
    }));

    return {
      data: {
        items,
        total: count ?? 0,
      },
    };
  } catch (err) {
    console.error("listEarnings unexpected error:", err);
    return { error: "Failed to list earnings" };
  }
}

// ---------------------------------------------------------------------------
// requestPayout
// ---------------------------------------------------------------------------

/**
 * Request a payout of earnings.
 * Validates amount is positive and does not exceed available balance
 * (pendingBalance minus already-requested amounts).
 */
export async function requestPayout(input: {
  amount: number;
  method: string;
  accountDetails: Record<string, string>;
}): Promise<ActionResult<PayoutRequest>> {
  try {
    const userId = await getAuthUserId();
    if (!userId) {
      return { error: "Not authenticated" };
    }

    if (!input.amount || input.amount <= 0) {
      return { error: "Amount must be greater than 0" };
    }

    if (!input.method) {
      return { error: "Payment method is required" };
    }

    const supabase = createServiceRoleClient();

    // Calculate available balance: pending earnings minus already-requested payouts
    const { data: earnings, error: earningsError } = await supabase
      .from("earnings")
      .select("amount")
      .eq("user_id", userId)
      .eq("status", "pending");

    if (earningsError) {
      console.error("requestPayout: earnings fetch error:", earningsError);
      return { error: "Failed to verify balance" };
    }

    const pendingBalance = (earnings ?? []).reduce(
      (sum, row) => sum + Number(row.amount),
      0,
    );

    const { data: existingRequests, error: requestsError } = await supabase
      .from("payout_requests")
      .select("amount")
      .eq("user_id", userId)
      .in("status", ["pending", "processing"]);

    if (requestsError) {
      console.error("requestPayout: requests fetch error:", requestsError);
      return { error: "Failed to verify existing requests" };
    }

    const totalRequested = (existingRequests ?? []).reduce(
      (sum, row) => sum + Number(row.amount),
      0,
    );

    const availableBalance = Math.round((pendingBalance - totalRequested) * 100) / 100;

    if (input.amount > availableBalance) {
      return {
        error: `Insufficient balance. Available: Rs ${availableBalance.toFixed(2)}`,
      };
    }

    // Create the payout request
    const { data: created, error: insertError } = await supabase
      .from("payout_requests")
      .insert({
        user_id: userId,
        amount: Math.round(input.amount * 100) / 100,
        method: input.method,
        account_details: input.accountDetails,
        status: "pending",
      })
      .select("id, user_id, amount, method, account_details, status, created_at")
      .single();

    if (insertError) {
      console.error("requestPayout: insert error:", insertError);
      return { error: "Failed to create payout request" };
    }

    return {
      data: {
        id: created.id,
        userId: created.user_id,
        amount: Number(created.amount),
        method: created.method,
        accountDetails: created.account_details as Record<string, string>,
        status: created.status,
        createdAt: created.created_at,
      },
    };
  } catch (err) {
    console.error("requestPayout unexpected error:", err);
    return { error: "Failed to request payout" };
  }
}
