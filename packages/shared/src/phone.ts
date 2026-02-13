/**
 * Nepal phone number validation and formatting.
 *
 * Valid Nepal mobile numbers:
 * - 10 digits starting with 97 or 98
 * - Operators: NTC (984, 985, 986), Ncell (980, 981, 982), Smart (961, 962, 988)
 */

const NEPAL_PHONE_REGEX = /^(97|98|96)\d{8}$/;

/** Strips spaces, dashes, and leading +977 country code */
export function normalizePhone(raw: string): string {
  let phone = raw.replace(/[\s\-()]/g, "");
  if (phone.startsWith("+977")) {
    phone = phone.slice(4);
  } else if (phone.startsWith("977")) {
    phone = phone.slice(3);
  }
  if (phone.startsWith("0")) {
    phone = phone.slice(1);
  }
  return phone;
}

/** Returns true if the normalized phone is a valid 10-digit Nepal mobile number */
export function isValidNepalPhone(raw: string): boolean {
  const phone = normalizePhone(raw);
  return NEPAL_PHONE_REGEX.test(phone);
}

/** Returns the E.164 formatted phone for Supabase Auth (+977XXXXXXXXXX) */
export function toE164(raw: string): string {
  return `+977${normalizePhone(raw)}`;
}
