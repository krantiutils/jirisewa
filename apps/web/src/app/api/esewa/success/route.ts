import { NextRequest, NextResponse } from "next/server";
import { decodeSuccessResponse, verifyTransaction } from "@/lib/esewa";
import { createServiceRoleClient } from "@/lib/supabase/server";

/**
 * eSewa success callback handler.
 *
 * After successful payment, eSewa redirects the user here with a base64-encoded
 * response body containing transaction details and a signature.
 *
 * Flow:
 * 1. Decode and verify the signature from the redirect data
 * 2. Double-check with eSewa's transaction status API (server-to-server)
 * 3. Update the order and transaction records
 * 4. Redirect user to the order detail page
 */
export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const encodedData = searchParams.get("data");
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? "http://localhost:3000";

  if (!encodedData) {
    console.error("eSewa success callback: missing data parameter");
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_failed`,
    );
  }

  // Step 1: Decode and verify the signature from the redirect
  const responseData = decodeSuccessResponse(encodedData);
  if (!responseData) {
    console.error("eSewa success callback: invalid or tampered response data");
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_verification_failed`,
    );
  }

  const supabase = createServiceRoleClient();

  // Look up the transaction by UUID
  const { data: txn, error: txnError } = await supabase
    .from("esewa_transactions")
    .select("id, order_id, total_amount, product_code, status")
    .eq("transaction_uuid", responseData.transaction_uuid)
    .single();

  if (txnError || !txn) {
    console.error("eSewa success callback: transaction not found:", responseData.transaction_uuid);
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

  // Verify amounts match
  const expectedAmount = Number(txn.total_amount);
  const receivedAmount = parseFloat(responseData.total_amount);
  if (Math.abs(expectedAmount - receivedAmount) > 0.01) {
    console.error(
      "eSewa success callback: amount mismatch. Expected:",
      expectedAmount,
      "Received:",
      receivedAmount,
    );
    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=amount_mismatch`,
    );
  }

  // Step 2: Server-to-server verification with eSewa's status API
  const statusResult = await verifyTransaction(
    txn.product_code,
    expectedAmount,
    responseData.transaction_uuid,
  );

  if (!statusResult || statusResult.status !== "COMPLETE") {
    console.error(
      "eSewa success callback: server verification failed. Status:",
      statusResult?.status,
    );

    // Update transaction with the actual status from eSewa
    await supabase
      .from("esewa_transactions")
      .update({
        esewa_status: statusResult?.status ?? "VERIFICATION_FAILED",
        esewa_ref_id: statusResult?.ref_id ?? null,
      })
      .eq("id", txn.id);

    return NextResponse.redirect(
      `${baseUrl}/en/orders/${txn.order_id}?payment=verification_failed`,
    );
  }

  // Step 3: Payment verified — update transaction and order
  const now = new Date().toISOString();

  const { error: updateTxnError } = await supabase
    .from("esewa_transactions")
    .update({
      status: "COMPLETE",
      esewa_ref_id: statusResult.ref_id,
      esewa_status: statusResult.status,
      verified_at: now,
    })
    .eq("id", txn.id);

  if (updateTxnError) {
    console.error("eSewa success callback: failed to update transaction:", updateTxnError);
  }

  // Mark order payment as escrowed (held until delivery confirmation)
  const { error: updateOrderError } = await supabase
    .from("orders")
    .update({ payment_status: "escrowed" })
    .eq("id", txn.order_id);

  if (updateOrderError) {
    console.error("eSewa success callback: failed to update order payment status:", updateOrderError);
  }

  // Step 4: Redirect to order detail
  return NextResponse.redirect(
    `${baseUrl}/en/orders/${txn.order_id}?payment=success`,
  );
}
