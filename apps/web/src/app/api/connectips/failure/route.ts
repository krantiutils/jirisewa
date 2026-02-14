import { NextRequest, NextResponse } from "next/server";
import { createServiceRoleClient } from "@/lib/supabase/server";

/**
 * connectIPS failure/cancellation callback handler.
 *
 * When payment fails or the user cancels, connectIPS redirects here.
 * We mark the transaction as failed and redirect the user to their order.
 */
export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? "http://localhost:3000";

  const txnId = searchParams.get("TXNID");

  if (!txnId) {
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_cancelled`,
    );
  }

  const supabase = createServiceRoleClient();

  const { data: txn, error: txnError } = await supabase
    .from("connectips_transactions")
    .select("id, order_id, status")
    .eq("txn_id", txnId)
    .single();

  if (txnError || !txn) {
    console.error("connectIPS failure callback: transaction not found:", txnId);
    return NextResponse.redirect(
      `${baseUrl}/en/checkout?error=payment_cancelled`,
    );
  }

  // Only update if still pending
  if (txn.status === "PENDING") {
    await supabase
      .from("connectips_transactions")
      .update({ status: "FAILED", connectips_status: "FAILED" })
      .eq("id", txn.id);
  }

  return NextResponse.redirect(
    `${baseUrl}/en/orders/${txn.order_id}?payment=failed`,
  );
}

/**
 * connectIPS may also POST to the failure URL.
 */
export async function POST(request: NextRequest) {
  const formData = await request.formData();
  const txnId = formData.get("TXNID") as string | null;

  if (!txnId) {
    return GET(request);
  }

  const url = new URL(request.url);
  url.searchParams.set("TXNID", txnId);
  const modifiedRequest = new NextRequest(url, {
    method: "GET",
    headers: request.headers,
  });

  return GET(modifiedRequest);
}
