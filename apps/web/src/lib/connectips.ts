import { createSign } from "crypto";
import { readFileSync } from "fs";

// connectIPS e-Payment integration
// Docs: https://doc.connectips.com/

const CONNECTIPS_ENDPOINTS = {
  sandbox: {
    gateway: "https://uat.connectips.com/connectipswebgw/loginpage",
    validate: "https://uat.connectips.com/connectipswebws/api/creditor/validatetxn",
  },
  production: {
    gateway: "https://connectips.com/connectipswebgw/loginpage",
    validate: "https://connectips.com/connectipswebws/api/creditor/validatetxn",
  },
} as const;

type Environment = "sandbox" | "production";

function getEnvironment(): Environment {
  return process.env.CONNECTIPS_ENVIRONMENT === "production"
    ? "production"
    : "sandbox";
}

function getMerchantId(): string {
  const id = process.env.CONNECTIPS_MERCHANT_ID;
  if (!id) {
    throw new Error("CONNECTIPS_MERCHANT_ID environment variable is not set");
  }
  return id;
}

function getAppId(): string {
  const id = process.env.CONNECTIPS_APP_ID;
  if (!id) {
    throw new Error("CONNECTIPS_APP_ID environment variable is not set");
  }
  return id;
}

function getAppName(): string {
  return (process.env.CONNECTIPS_APP_NAME ?? "JiriSewa").slice(0, 20);
}

function getAppPassword(): string {
  const password = process.env.CONNECTIPS_APP_PASSWORD;
  if (!password) {
    throw new Error("CONNECTIPS_APP_PASSWORD environment variable is not set");
  }
  return password;
}

function getBaseUrl(): string {
  const url = process.env.NEXT_PUBLIC_BASE_URL;
  if (!url) {
    throw new Error("NEXT_PUBLIC_BASE_URL environment variable is not set");
  }
  return url;
}

// Cache the private key to avoid repeated file reads
let cachedPrivateKey: string | null = null;

/**
 * Load the RSA private key for signing connectIPS requests.
 *
 * The key must be a PEM-format private key file.
 * Extract from PFX with: openssl pkcs12 -in cert.pfx -nocerts -nodes -out key.pem
 */
function getPrivateKey(): string {
  if (cachedPrivateKey) return cachedPrivateKey;

  const keyPath = process.env.CONNECTIPS_KEY_PATH;
  if (!keyPath) {
    throw new Error("CONNECTIPS_KEY_PATH environment variable is not set (path to PEM private key)");
  }

  const keyPem = readFileSync(keyPath, "utf-8");
  cachedPrivateKey = keyPem;
  return keyPem;
}

/**
 * Generate RSA-SHA256 signature for connectIPS.
 *
 * The message is constructed from UPPERCASE field names in exact order:
 * "MERCHANTID=val,APPID=val,REFERENCEID=val,TXNAMT=val"
 */
export function generateToken(fields: {
  merchantId: string;
  appId: string;
  referenceId: string;
  txnAmt: string;
}): string {
  const message = `MERCHANTID=${fields.merchantId},APPID=${fields.appId},REFERENCEID=${fields.referenceId},TXNAMT=${fields.txnAmt}`;

  const privateKey = getPrivateKey();
  const sign = createSign("SHA256");
  sign.update(message);
  sign.end();

  return sign.sign(privateKey, "base64");
}

export interface ConnectIPSPaymentParams {
  orderId: string;
  txnId: string;
  referenceId: string;
  amountPaisa: number;
  remarks?: string;
}

export interface ConnectIPSFormData {
  url: string;
  fields: Record<string, string>;
}

/**
 * Build the form data required to redirect the user to connectIPS payment page.
 * The consumer's browser submits this form via POST to connectIPS gateway.
 */
export function buildPaymentFormData(params: ConnectIPSPaymentParams): ConnectIPSFormData {
  const env = getEnvironment();
  const merchantId = getMerchantId();
  const appId = getAppId();
  const appName = getAppName();
  const baseUrl = getBaseUrl();

  const now = new Date();
  const txnDate = `${String(now.getDate()).padStart(2, "0")}-${String(now.getMonth() + 1).padStart(2, "0")}-${now.getFullYear()}`;

  const token = generateToken({
    merchantId,
    appId,
    referenceId: params.referenceId,
    txnAmt: params.amountPaisa.toString(),
  });

  return {
    url: CONNECTIPS_ENDPOINTS[env].gateway,
    fields: {
      MERCHANTID: merchantId,
      APPID: appId,
      APPNAME: appName,
      TXNID: params.txnId,
      TXNDATE: txnDate,
      TXNCRNCY: "NPR",
      TXNAMT: params.amountPaisa.toString(),
      REFERENCEID: params.referenceId,
      REMARKS: (params.remarks ?? "JiriSewa Order").slice(0, 20),
      PARTICULARS: `Order-${params.orderId.slice(0, 13)}`,
      TOKEN: token,
      successUrl: `${baseUrl}/api/connectips/success`,
      failureUrl: `${baseUrl}/api/connectips/failure`,
    },
  };
}

export type ConnectIPSTransactionStatus = "SUCCESS" | "FAILED" | "ERROR" | "UNKNOWN";

export interface ConnectIPSValidateResponse {
  status: ConnectIPSTransactionStatus;
}

/**
 * Verify a connectIPS transaction via their validation API.
 * Uses Basic Authentication with appId:password.
 */
export async function verifyTransaction(
  referenceId: string,
  txnAmt: number,
): Promise<ConnectIPSValidateResponse | null> {
  const env = getEnvironment();
  const merchantId = getMerchantId();
  const appId = getAppId();
  const appPassword = getAppPassword();

  const token = generateToken({
    merchantId,
    appId,
    referenceId,
    txnAmt: txnAmt.toString(),
  });

  const authHeader = Buffer.from(`${appId}:${appPassword}`).toString("base64");

  try {
    const response = await fetch(CONNECTIPS_ENDPOINTS[env].validate, {
      method: "POST",
      headers: {
        Authorization: `Basic ${authHeader}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        merchantId,
        appId,
        referenceId,
        txnAmt: txnAmt.toString(),
        token,
      }),
    });

    if (!response.ok) {
      console.error(
        "connectIPS validation failed:",
        response.status,
        await response.text(),
      );
      return null;
    }

    const data: ConnectIPSValidateResponse = await response.json();
    return data;
  } catch (err) {
    console.error("connectIPS transaction verification error:", err);
    return null;
  }
}

/**
 * Generate a unique transaction ID for connectIPS.
 * Must be max 20 characters, alphanumeric.
 */
export function generateTxnId(orderId: string): string {
  const shortId = orderId.replace(/-/g, "").slice(0, 8);
  const ts = Date.now().toString(36).slice(-6);
  return `JS${shortId}${ts}`.slice(0, 20);
}

/**
 * Generate a reference ID for connectIPS.
 * Must be max 20 characters.
 */
export function generateReferenceId(orderId: string): string {
  const shortId = orderId.replace(/-/g, "").slice(0, 8);
  const ts = Date.now().toString(36).slice(-6);
  return `REF${shortId}${ts}`.slice(0, 20);
}

/**
 * Convert NPR amount to paisa for connectIPS.
 * connectIPS requires amounts in paisa (amount × 100).
 */
export function toPaisa(amountNpr: number): number {
  return Math.round(amountNpr * 100);
}
