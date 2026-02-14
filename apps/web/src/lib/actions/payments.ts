"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import { buildPaymentFormData, generateTransactionUuid } from "@/lib/esewa";
import { initiatePayment as initiateKhaltiPayment, generatePurchaseOrderId, toPaisa as khaltiToPaisa } from "@/lib/khalti";
import { buildPaymentFormData as buildConnectIPSFormData, generateTxnId, generateReferenceId, toPaisa as connectipsToPaisa } from "@/lib/connectips";
import type { ActionResult } from "@/lib/types/action";
import type { EsewaPaymentFormData, KhaltiPaymentData, ConnectIPSPaymentFormData } from "@/lib/types/order";

const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";

/**
 * Validate order for retry payment. Returns the order data or an error.
 */
async function validateOrderForRetry(
  orderId: string,
  expectedMethod: string,
) {
  const supabase = createServiceRoleClient();

  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select("id, consumer_id, total_price, delivery_fee, payment_method, payment_status, status")
    .eq("id", orderId)
    .single();

  if (orderError || !order) {
    return { error: "Order not found" as const };
  }

  if (order.consumer_id !== DEMO_CONSUMER_ID) {
    return { error: "You can only pay for your own orders" as const };
  }

  if (order.payment_method !== expectedMethod) {
    return { error: `This order does not use ${expectedMethod} payment` as const };
  }

  if (order.payment_status !== "pending") {
    return { error: "Payment has already been processed for this order" as const };
  }

  if (order.status === "cancelled") {
    return { error: "Cannot pay for a cancelled order" as const };
  }

  return { order };
}

/**
 * Retry eSewa payment for a pending order that hasn't been paid yet.
 * Creates a new transaction UUID and returns fresh form data for redirect.
 */
export async function retryEsewaPayment(
  orderId: string,
): Promise<ActionResult<EsewaPaymentFormData>> {
  try {
    const result = await validateOrderForRetry(orderId, "esewa");
    if ("error" in result) return { error: result.error };
    const { order } = result;

    const supabase = createServiceRoleClient();
    const totalAmount = Number(order.total_price) + Number(order.delivery_fee);
    const transactionUuid = generateTransactionUuid(order.id);

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
 * Retry Khalti payment for a pending order.
 * Creates a new transaction record and initiates via Khalti API.
 */
export async function retryKhaltiPayment(
  orderId: string,
): Promise<ActionResult<KhaltiPaymentData>> {
  try {
    const result = await validateOrderForRetry(orderId, "khalti");
    if ("error" in result) return { error: result.error };
    const { order } = result;

    const supabase = createServiceRoleClient();
    const totalAmount = Number(order.total_price) + Number(order.delivery_fee);
    const purchaseOrderId = generatePurchaseOrderId(order.id);
    const amountPaisa = khaltiToPaisa(totalAmount);

    const { error: txnError } = await supabase
      .from("khalti_transactions")
      .insert({
        order_id: order.id,
        purchase_order_id: purchaseOrderId,
        amount_paisa: amountPaisa,
        total_amount: totalAmount,
        status: "PENDING",
      });

    if (txnError) {
      console.error("retryKhaltiPayment: failed to create transaction:", txnError);
      return { error: "Failed to initiate Khalti payment" };
    }

    const khaltiResponse = await initiateKhaltiPayment({
      orderId: order.id,
      purchaseOrderId,
      purchaseOrderName: "JiriSewa Order",
      amountPaisa,
    });

    if (!khaltiResponse) {
      console.error("retryKhaltiPayment: Khalti API initiation failed");
      return { error: "Failed to initiate Khalti payment" };
    }

    await supabase
      .from("khalti_transactions")
      .update({ pidx: khaltiResponse.pidx })
      .eq("purchase_order_id", purchaseOrderId);

    return {
      data: {
        orderId: order.id,
        paymentUrl: khaltiResponse.payment_url,
        pidx: khaltiResponse.pidx,
      },
    };
  } catch (err) {
    console.error("retryKhaltiPayment unexpected error:", err);
    return { error: "Failed to retry payment" };
  }
}

/**
 * Retry connectIPS payment for a pending order.
 * Creates a new transaction record and returns form data for redirect.
 */
export async function retryConnectIPSPayment(
  orderId: string,
): Promise<ActionResult<ConnectIPSPaymentFormData>> {
  try {
    const result = await validateOrderForRetry(orderId, "connectips");
    if ("error" in result) return { error: result.error };
    const { order } = result;

    const supabase = createServiceRoleClient();
    const totalAmount = Number(order.total_price) + Number(order.delivery_fee);
    const txnId = generateTxnId(order.id);
    const referenceId = generateReferenceId(order.id);
    const amountPaisa = connectipsToPaisa(totalAmount);

    const { error: txnError } = await supabase
      .from("connectips_transactions")
      .insert({
        order_id: order.id,
        txn_id: txnId,
        reference_id: referenceId,
        amount_paisa: amountPaisa,
        total_amount: totalAmount,
        status: "PENDING",
      });

    if (txnError) {
      console.error("retryConnectIPSPayment: failed to create transaction:", txnError);
      return { error: "Failed to initiate connectIPS payment" };
    }

    const connectipsForm = buildConnectIPSFormData({
      orderId: order.id,
      txnId,
      referenceId,
      amountPaisa,
    });

    return {
      data: {
        orderId: order.id,
        url: connectipsForm.url,
        fields: connectipsForm.fields,
      },
    };
  } catch (err) {
    console.error("retryConnectIPSPayment unexpected error:", err);
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
