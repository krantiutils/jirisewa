import { createHmac } from "crypto";

// eSewa ePay V2 integration
// Docs: https://developer.esewa.com.np/pages/Epay

const ESEWA_ENDPOINTS = {
  sandbox: {
    form: "https://rc-epay.esewa.com.np/api/epay/main/v2/form",
    status: "https://rc.esewa.com.np/api/epay/transaction/status/",
  },
  production: {
    form: "https://epay.esewa.com.np/api/epay/main/v2/form",
    status: "https://esewa.com.np/api/epay/transaction/status/",
  },
} as const;

type Environment = "sandbox" | "production";

function getEnvironment(): Environment {
  return process.env.ESEWA_ENVIRONMENT === "production"
    ? "production"
    : "sandbox";
}

function getSecretKey(): string {
  const key = process.env.ESEWA_SECRET_KEY;
  if (!key) {
    throw new Error("ESEWA_SECRET_KEY environment variable is not set");
  }
  return key;
}

function getProductCode(): string {
  const code = process.env.ESEWA_PRODUCT_CODE;
  if (!code) {
    throw new Error("ESEWA_PRODUCT_CODE environment variable is not set");
  }
  return code;
}

function getBaseUrl(): string {
  const url = process.env.NEXT_PUBLIC_BASE_URL;
  if (!url) {
    throw new Error("NEXT_PUBLIC_BASE_URL environment variable is not set");
  }
  return url;
}

/**
 * Generate HMAC-SHA256 signature for eSewa ePay V2.
 *
 * The signed fields must be in exact order: total_amount,transaction_uuid,product_code
 * The message format is: "total_amount=<value>,transaction_uuid=<value>,product_code=<value>"
 */
export function generateSignature(
  totalAmount: number,
  transactionUuid: string,
  productCode: string,
): string {
  const message = `total_amount=${totalAmount},transaction_uuid=${transactionUuid},product_code=${productCode}`;
  const hmac = createHmac("sha256", getSecretKey());
  hmac.update(message);
  return hmac.digest("base64");
}

/**
 * Verify a signature received from eSewa callback.
 * Compares the provided signature against a freshly computed one.
 */
export function verifySignature(
  totalAmount: number,
  transactionUuid: string,
  productCode: string,
  receivedSignature: string,
): boolean {
  const expected = generateSignature(totalAmount, transactionUuid, productCode);
  // Constant-time comparison to prevent timing attacks
  if (expected.length !== receivedSignature.length) return false;
  let result = 0;
  for (let i = 0; i < expected.length; i++) {
    result |= expected.charCodeAt(i) ^ receivedSignature.charCodeAt(i);
  }
  return result === 0;
}

export interface EsewaPaymentParams {
  orderId: string;
  amount: number;
  deliveryCharge: number;
  taxAmount?: number;
  serviceCharge?: number;
  transactionUuid: string;
}

export interface EsewaFormData {
  url: string;
  fields: Record<string, string>;
}

/**
 * Build the form data required to redirect the user to eSewa payment page.
 * The consumer's browser submits this form via POST to eSewa's endpoint.
 */
export function buildPaymentFormData(params: EsewaPaymentParams): EsewaFormData {
  const env = getEnvironment();
  const productCode = getProductCode();
  const baseUrl = getBaseUrl();

  const taxAmount = params.taxAmount ?? 0;
  const serviceCharge = params.serviceCharge ?? 0;
  const deliveryCharge = params.deliveryCharge;
  const totalAmount = params.amount + taxAmount + serviceCharge + deliveryCharge;

  const signature = generateSignature(
    totalAmount,
    params.transactionUuid,
    productCode,
  );

  const successUrl = `${baseUrl}/api/esewa/success`;
  const failureUrl = `${baseUrl}/api/esewa/failure`;

  return {
    url: ESEWA_ENDPOINTS[env].form,
    fields: {
      amount: params.amount.toString(),
      tax_amount: taxAmount.toString(),
      product_service_charge: serviceCharge.toString(),
      product_delivery_charge: deliveryCharge.toString(),
      total_amount: totalAmount.toString(),
      transaction_uuid: params.transactionUuid,
      product_code: productCode,
      success_url: successUrl,
      failure_url: failureUrl,
      signed_field_names: "total_amount,transaction_uuid,product_code",
      signature,
    },
  };
}

export interface EsewaSuccessResponse {
  transaction_code: string;
  status: string;
  total_amount: string;
  transaction_uuid: string;
  product_code: string;
  signed_field_names: string;
  signature: string;
}

/**
 * Decode and validate the base64-encoded response from eSewa's success redirect.
 * Returns the parsed response if signature is valid, null otherwise.
 */
export function decodeSuccessResponse(
  encodedData: string,
): EsewaSuccessResponse | null {
  try {
    const decoded = Buffer.from(encodedData, "base64").toString("utf-8");
    const data: EsewaSuccessResponse = JSON.parse(decoded);

    if (!data.transaction_uuid || !data.total_amount || !data.product_code) {
      console.error("eSewa success response missing required fields");
      return null;
    }

    const isValid = verifySignature(
      parseFloat(data.total_amount),
      data.transaction_uuid,
      data.product_code,
      data.signature,
    );

    if (!isValid) {
      console.error("eSewa success response signature verification failed");
      return null;
    }

    return data;
  } catch (err) {
    console.error("Failed to decode eSewa success response:", err);
    return null;
  }
}

export interface EsewaTransactionStatus {
  product_code: string;
  transaction_uuid: string;
  total_amount: number;
  status: "COMPLETE" | "PENDING" | "FULL_REFUND" | "PARTIAL_REFUND" | "AMBIGUOUS" | "NOT_FOUND" | "CANCELED";
  ref_id: string | null;
}

/**
 * Verify a transaction's status directly with eSewa's API.
 * This is the server-side verification that MUST be done before delivering goods.
 */
export async function verifyTransaction(
  productCode: string,
  totalAmount: number,
  transactionUuid: string,
): Promise<EsewaTransactionStatus | null> {
  const env = getEnvironment();
  const url = new URL(ESEWA_ENDPOINTS[env].status);
  url.searchParams.set("product_code", productCode);
  url.searchParams.set("total_amount", totalAmount.toString());
  url.searchParams.set("transaction_uuid", transactionUuid);

  try {
    const response = await fetch(url.toString(), {
      method: "GET",
      headers: { Accept: "application/json" },
    });

    if (!response.ok) {
      console.error(
        "eSewa transaction status check failed:",
        response.status,
        await response.text(),
      );
      return null;
    }

    const data: EsewaTransactionStatus = await response.json();
    return data;
  } catch (err) {
    console.error("eSewa transaction verification error:", err);
    return null;
  }
}

/**
 * Generate a unique transaction UUID for an order.
 * Format: JIRISEWA-<orderId-short>-<timestamp>
 */
export function generateTransactionUuid(orderId: string): string {
  const shortId = orderId.replace(/-/g, "").slice(0, 8);
  const ts = Date.now().toString(36);
  return `JIRISEWA-${shortId}-${ts}`;
}
