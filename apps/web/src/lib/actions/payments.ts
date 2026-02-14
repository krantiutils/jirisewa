"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import { buildPaymentFormData, generateTransactionUuid } from "@/lib/esewa";
import type { ActionResult } from "@/lib/types/action";
import type { EsewaPaymentFormData } from "@/lib/types/order";

const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";

/**
 * Retry eSewa payment for a pending order that hasn't been paid yet.
 * Creates a new transaction UUID and returns fresh form data for redirect.
 */
export async function retryEsewaPayment(
  orderId: string,
): Promise<ActionResult<EsewaPaymentFormData>> {
  try {
    const supabase = createServiceRoleClient();

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, consumer_id, total_price, delivery_fee, payment_method, payment_status, status")
      .eq("id", orderId)
      .single();

    if (orderError || !order) {
      return { error: "Order not found" };
    }

    if (order.consumer_id !== DEMO_CONSUMER_ID) {
      return { error: "You can only pay for your own orders" };
    }

    if (order.payment_method !== "esewa") {
      return { error: "This order does not use eSewa payment" };
    }

    if (order.payment_status !== "pending") {
      return { error: "Payment has already been processed for this order" };
    }

    if (order.status === "cancelled") {
      return { error: "Cannot pay for a cancelled order" };
    }

    const totalAmount = Number(order.total_price) + Number(order.delivery_fee);
    const transactionUuid = generateTransactionUuid(order.id);

    // Create a new transaction record (old failed ones are kept for audit)
    const { error: txnError } = await supabase
      .from("esewa_transactions")
      .insert({
        order_id: order.id,
        transaction_uuid: transactionUuid,
        product_code: process.env.ESEWA_PRODUCT_CODE ?? "EPAYTEST",
        amount: Number(order.total_price),
        tax_amount: 0,
        service_charge: 0,
        delivery_charge: Number(order.delivery_fee),
        total_amount: totalAmount,
        status: "PENDING",
      });

    if (txnError) {
      console.error("retryEsewaPayment: failed to create transaction:", txnError);
      return { error: "Failed to initiate eSewa payment" };
    }

    const esewaForm = buildPaymentFormData({
      orderId: order.id,
      amount: Number(order.total_price),
      deliveryCharge: Number(order.delivery_fee),
      transactionUuid,
    });

    return {
      data: {
        orderId: order.id,
        url: esewaForm.url,
        fields: esewaForm.fields,
      },
    };
  } catch (err) {
    console.error("retryEsewaPayment unexpected error:", err);
    return { error: "Failed to retry payment" };
  }
}

/**
 * Get eSewa transaction status for an order.
 */
export async function getEsewaTransactionStatus(
  orderId: string,
): Promise<ActionResult<{ status: string; refId: string | null; verifiedAt: string | null }>> {
  try {
    const supabase = createServiceRoleClient();

    const { data: txn, error } = await supabase
      .from("esewa_transactions")
      .select("status, esewa_ref_id, verified_at")
      .eq("order_id", orderId)
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    if (error || !txn) {
      return { error: "No eSewa transaction found for this order" };
    }

    return {
      data: {
        status: txn.status,
        refId: txn.esewa_ref_id,
        verifiedAt: txn.verified_at,
      },
    };
  } catch (err) {
    console.error("getEsewaTransactionStatus unexpected error:", err);
    return { error: "Failed to get transaction status" };
  }
}
