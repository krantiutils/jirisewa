import { NextRequest, NextResponse } from "next/server";
import { createServiceRoleClient } from "@/lib/supabase/server";

/**
 * eSewa failure/cancellation callback handler.
 *
 * When payment fails or the user cancels, eSewa redirects here.
 * We mark the transaction as failed and redirect the user to their order.
 */
export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? "http://localhost:3000";

  // eSewa may pass transaction_uuid or product_code in query params on failure
  const transactionUuid = searchParams.get("transaction_uuid");

  if (!transactionUuid) {
    // No transaction context — redirect to checkout
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_cancelled`,
    );
  }

  const supabase = createServiceRoleClient();

  const { data: txn, error: txnError } = await supabase
    .from("esewa_transactions")
    .select("id, order_id, status")
    .eq("transaction_uuid", transactionUuid)
    .single();

  if (txnError || !txn) {
    console.error("eSewa failure callback: transaction not found:", transactionUuid);
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_cancelled`,
    );
  }

  // Only update if still pending — don't overwrite a completed transaction
  if (txn.status === "PENDING") {
    await supabase
      .from("esewa_transactions")
      .update({ status: "FAILED", esewa_status: "FAILED" })
      .eq("id", txn.id);
  }

  // Redirect to the order with a failure indicator
  return NextResponse.redirect(
    `${baseUrl}/en/orders/${txn.order_id}?payment=failed`,
  );
}
