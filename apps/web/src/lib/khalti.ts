// Khalti ePayment API v2 integration
// Docs: https://docs.khalti.com/khalti-epayment/

const KHALTI_ENDPOINTS = {
  sandbox: {
    initiate: "https://dev.khalti.com/api/v2/epayment/initiate/",
    lookup: "https://dev.khalti.com/api/v2/epayment/lookup/",
  },
  production: {
    initiate: "https://khalti.com/api/v2/epayment/initiate/",
    lookup: "https://khalti.com/api/v2/epayment/lookup/",
  },
} as const;

type Environment = "sandbox" | "production";

function getEnvironment(): Environment {
  return process.env.KHALTI_ENVIRONMENT === "production"
    ? "production"
    : "sandbox";
}

function getSecretKey(): string {
  const key = process.env.KHALTI_SECRET_KEY;
  if (!key) {
    throw new Error("KHALTI_SECRET_KEY environment variable is not set");
  }
  return key;
}

function getBaseUrl(): string {
  const url = process.env.NEXT_PUBLIC_BASE_URL;
  if (!url) {
    throw new Error("NEXT_PUBLIC_BASE_URL environment variable is not set");
  }
  return url;
}

export interface KhaltiInitiateParams {
  orderId: string;
  purchaseOrderId: string;
  purchaseOrderName: string;
  amountPaisa: number;
  customerName?: string;
  customerEmail?: string;
  customerPhone?: string;
}

export interface KhaltiInitiateResponse {
  pidx: string;
  payment_url: string;
  expires_at: string;
  expires_in: number;
}

/**
 * Initiate a Khalti payment by calling their ePayment API.
 *
 * Unlike eSewa (form POST), Khalti uses a server-to-server API call
 * that returns a payment_url to redirect the user to.
 *
 * Amount must be in paisa (1 NPR = 100 paisa, minimum 1000 paisa = Rs. 10).
 */
export async function initiatePayment(
  params: KhaltiInitiateParams,
): Promise<KhaltiInitiateResponse | null> {
  const env = getEnvironment();
  const secretKey = getSecretKey();
  const baseUrl = getBaseUrl();

  const body: Record<string, unknown> = {
    return_url: `${baseUrl}/api/khalti/callback`,
    website_url: baseUrl,
    amount: params.amountPaisa,
    purchase_order_id: params.purchaseOrderId,
    purchase_order_name: params.purchaseOrderName,
  };

  if (params.customerName || params.customerEmail || params.customerPhone) {
    body.customer_info = {
      name: params.customerName ?? "",
      email: params.customerEmail ?? "",
      phone: params.customerPhone ?? "",
    };
  }

  try {
    const response = await fetch(KHALTI_ENDPOINTS[env].initiate, {
      method: "POST",
      headers: {
        Authorization: `Key ${secretKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(
        "Khalti payment initiation failed:",
        response.status,
        errorBody,
      );
      return null;
    }

    const data: KhaltiInitiateResponse = await response.json();
    return data;
  } catch (err) {
    console.error("Khalti payment initiation error:", err);
    return null;
  }
}

export type KhaltiPaymentStatus =
  | "Completed"
  | "Pending"
  | "Initiated"
  | "Refunded"
  | "Partially Refunded"
  | "Expired"
  | "User canceled";

export interface KhaltiLookupResponse {
  pidx: string;
  total_amount: number;
  status: KhaltiPaymentStatus;
  transaction_id: string | null;
  fee: number;
  refunded: boolean;
}

/**
 * Verify a Khalti transaction's status via their lookup API.
 * This is the server-side verification that MUST be done before delivering goods.
 */
export async function verifyTransaction(
  pidx: string,
): Promise<KhaltiLookupResponse | null> {
  const env = getEnvironment();
  const secretKey = getSecretKey();

  try {
    const response = await fetch(KHALTI_ENDPOINTS[env].lookup, {
      method: "POST",
      headers: {
        Authorization: `Key ${secretKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ pidx }),
    });

    if (!response.ok) {
      console.error(
        "Khalti lookup failed:",
        response.status,
        await response.text(),
      );
      return null;
    }

    const data: KhaltiLookupResponse = await response.json();
    return data;
  } catch (err) {
    console.error("Khalti transaction verification error:", err);
    return null;
  }
}

/**
 * Generate a unique purchase order ID for Khalti.
 * Format: JIRISEWA-<orderId-short>-<timestamp>
 */
export function generatePurchaseOrderId(orderId: string): string {
  const shortId = orderId.replace(/-/g, "").slice(0, 8);
  const ts = Date.now().toString(36);
  return `JIRISEWA-${shortId}-${ts}`;
}

/**
 * Convert NPR amount to paisa for Khalti API.
 * Khalti requires amounts in paisa (1 NPR = 100 paisa).
 */
export function toPaisa(amountNpr: number): number {
  return Math.round(amountNpr * 100);
}
