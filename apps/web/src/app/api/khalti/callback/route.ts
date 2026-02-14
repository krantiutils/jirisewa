import { NextRequest, NextResponse } from "next/server";
import { verifyTransaction } from "@/lib/khalti";
import { createServiceRoleClient } from "@/lib/supabase/server";

/**
 * Khalti callback handler.
 *
 * After payment, Khalti redirects the user here with query parameters:
 * - pidx: Payment identifier
 * - status: "Completed", "Pending", or "User canceled"
 * - purchase_order_id: Our order reference
 * - transaction_id: Khalti's transaction ID
 * - amount: Amount in paisa
 *
 * Flow:
 * 1. Extract callback parameters
 * 2. Look up our transaction by purchase_order_id
 * 3. Verify with Khalti's lookup API (server-to-server, authoritative)
 * 4. Update transaction and order records
 * 5. Redirect user to order detail page
 */
export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? "http://localhost:3000";

  const pidx = searchParams.get("pidx");
  const status = searchParams.get("status");
  const purchaseOrderId = searchParams.get("purchase_order_id");

  if (!pidx || !purchaseOrderId) {
    console.error("Khalti callback: missing required parameters");
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_failed`,
    );
  }

  // User cancelled on Khalti's side
  if (status === "User canceled") {
    const supabase = createServiceRoleClient();

    const { data: txn } = await supabase
      .from("khalti_transactions")
      .select("id, order_id, status")
      .eq("purchase_order_id", purchaseOrderId)
      .single();

    if (txn && txn.status === "PENDING") {
      await supabase
        .from("khalti_transactions")
        .update({ status: "CANCELLED", khalti_status: "User canceled" })
        .eq("id", txn.id);
    }

    if (txn) {
      return NextResponse.redirect(
        `${baseUrl}/en/orders/${txn.order_id}?payment=failed`,
      );
    }

    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_cancelled`,
    );
  }

  const supabase = createServiceRoleClient();

  // Look up our transaction record
  const { data: txn, error: txnError } = await supabase
    .from("khalti_transactions")
    .select("id, order_id, amount_paisa, total_amount, status")
    .eq("purchase_order_id", purchaseOrderId)
    .single();

  if (txnError || !txn) {
    console.error("Khalti callback: transaction not found:", purchaseOrderId);
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=transaction_not_found`,
    );
  }

  // Already processed — idempotent redirect
  if (txn.status === "COMPLETE") {
    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=success`,
    );
  }

  // Server-to-server verification with Khalti's lookup API
  const lookupResult = await verifyTransaction(pidx);

  if (!lookupResult || lookupResult.status !== "Completed") {
    console.error(
      "Khalti callback: server verification failed. Status:",
      lookupResult?.status,
    );

    await supabase
      .from("khalti_transactions")
      .update({
        pidx,
        khalti_status: lookupResult?.status ?? "VERIFICATION_FAILED",
        transaction_id: lookupResult?.transaction_id ?? null,
      })
      .eq("id", txn.id);

    // Pending status means payment may still complete — don't mark as failed
    if (lookupResult?.status === "Pending") {
      return NextResponse.redirect(
        `${baseUrl}/en/orders/${txn.order_id}?payment=pending`,
      );
    }

    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=verification_failed`,
    );
  }

  // Verify amount matches (Khalti returns amount in paisa)
  if (lookupResult.total_amount !== txn.amount_paisa) {
    console.error(
      "Khalti callback: amount mismatch. Expected:",
      txn.amount_paisa,
      "Received:",
      lookupResult.total_amount,
    );
    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=amount_mismatch`,
    );
  }

  // Payment verified — update transaction and order
  const now = new Date().toISOString();

  const { error: updateTxnError } = await supabase
    .from("khalti_transactions")
    .update({
      status: "COMPLETE",
      pidx,
      khalti_status: lookupResult.status,
      transaction_id: lookupResult.transaction_id,
      khalti_fee: lookupResult.fee,
      verified_at: now,
    })
    .eq("id", txn.id);

  if (updateTxnError) {
    console.error("Khalti callback: failed to update transaction:", updateTxnError);
  }

  // Mark order payment as escrowed (held until delivery confirmation)
  const { error: updateOrderError } = await supabase
    .from("orders")
    .update({ payment_status: "escrowed" })
    .eq("id", txn.order_id);

  if (updateOrderError) {
    console.error("Khalti callback: failed to update order payment status:", updateOrderError);
  }

  return NextResponse.redirect(
    `${baseUrl}/en/orders/${txn.order_id}?payment=success`,
  );
}
