import { NextRequest, NextResponse } from "next/server";
import { verifyTransaction } from "@/lib/connectips";
import { createServiceRoleClient } from "@/lib/supabase/server";

/**
 * connectIPS success callback handler.
 *
 * After successful payment, connectIPS redirects the user to this success URL.
 * We look up the transaction, verify with connectIPS API, and update records.
 */
export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? "http://localhost:3000";

  // connectIPS passes TXNID and TXNAMT in the callback
  const txnId = searchParams.get("TXNID");
  const txnAmtParam = searchParams.get("TXNAMT");

  if (!txnId) {
    console.error("connectIPS success callback: missing TXNID parameter");
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_failed`,
    );
  }

  const supabase = createServiceRoleClient();

  // Look up our transaction record
  const { data: txn, error: txnError } = await supabase
    .from("connectips_transactions")
    .select("id, order_id, reference_id, amount_paisa, total_amount, status")
    .eq("txn_id", txnId)
    .single();

  if (txnError || !txn) {
    console.error("connectIPS success callback: transaction not found:", txnId);
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

  // Verify amount from callback matches expected amount
  if (txnAmtParam) {
    const receivedAmtPaisa = parseInt(txnAmtParam, 10);
    if (!Number.isNaN(receivedAmtPaisa) && receivedAmtPaisa !== txn.amount_paisa) {
      console.error(
        "connectIPS success callback: amount mismatch. Expected:",
        txn.amount_paisa,
        "Received:",
        receivedAmtPaisa,
      );
      await supabase
        .from("connectips_transactions")
        .update({ status: "FAILED", connectips_status: "AMOUNT_MISMATCH" })
        .eq("id", txn.id)
        .eq("status", "PENDING");
      return NextResponse.redirect(
        `${baseUrl}/en/orders/${txn.order_id}?payment=amount_mismatch`,
      );
    }
  }

  // Server-to-server verification with connectIPS validate API
  const validateResult = await verifyTransaction(
    txn.reference_id,
    txn.amount_paisa,
  );

  if (!validateResult || validateResult.status !== "SUCCESS") {
    console.error(
      "connectIPS success callback: server verification failed. Status:",
      validateResult?.status,
    );

    await supabase
      .from("connectips_transactions")
      .update({
        connectips_status: validateResult?.status ?? "VERIFICATION_FAILED",
      })
      .eq("id", txn.id)
      .eq("status", "PENDING");

    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=verification_failed`,
    );
  }

  // Payment verified — atomically update transaction (only if still PENDING)
  const now = new Date().toISOString();

  const { error: updateTxnError, count: updatedCount } = await supabase
    .from("connectips_transactions")
    .update({
      status: "COMPLETE",
      connectips_status: validateResult.status,
      verified_at: now,
    })
    .eq("id", txn.id)
    .eq("status", "PENDING");

  if (updateTxnError) {
    console.error("connectIPS success callback: failed to update transaction:", updateTxnError);
    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=verification_failed`,
    );
  }

  // If no rows updated, another request already processed this
  if (updatedCount === 0) {
    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=success`,
    );
  }

  // Mark order payment as escrowed
  const { error: updateOrderError } = await supabase
    .from("orders")
    .update({ payment_status: "escrowed" })
    .eq("id", txn.order_id);

  if (updateOrderError) {
    console.error("connectIPS success callback: failed to update order payment status:", updateOrderError);
  }

  return NextResponse.redirect(
    `${baseUrl}/en/orders/${txn.order_id}?payment=success`,
  );
}

/**
 * connectIPS may also POST to the success URL depending on configuration.
 */
export async function POST(request: NextRequest) {
  // connectIPS sometimes sends data as form POST
  const formData = await request.formData();
  const txnId = formData.get("TXNID") as string | null;

  if (!txnId) {
    // Fall back to treating as GET with search params
    return GET(request);
  }

  // Reconstruct as a GET-style request by appending to URL
  const url = new URL(request.url);
  url.searchParams.set("TXNID", txnId);
  const txnAmt = formData.get("TXNAMT") as string | null;
  if (txnAmt) url.searchParams.set("TXNAMT", txnAmt);
  const modifiedRequest = new NextRequest(url, {
    method: "GET",
    headers: request.headers,
  });

  return GET(modifiedRequest);
}
