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

  // connectIPS passes TXNID in the callback
  const txnId = searchParams.get("TXNID");

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
      .eq("id", txn.id);

    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=verification_failed`,
    );
  }

  // Payment verified — update transaction and order
  const now = new Date().toISOString();

  const { error: updateTxnError } = await supabase
    .from("connectips_transactions")
    .update({
      status: "COMPLETE",
      connectips_status: validateResult.status,
      verified_at: now,
    })
    .eq("id", txn.id);

  if (updateTxnError) {
    console.error("connectIPS success callback: failed to update transaction:", updateTxnError);
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
  const modifiedRequest = new NextRequest(url, {
    method: "GET",
    headers: request.headers,
  });

  return GET(modifiedRequest);
}
