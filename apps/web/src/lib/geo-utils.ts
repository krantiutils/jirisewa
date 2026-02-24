/**
 * Parse EWKB hex point to {lat, lng}.
 * Supabase returns geography columns as EWKB hex strings.
 */
export function parseEwkbPoint(hex: string): { lat: number; lng: number } | null {
  if (!hex || hex.length < 50) return null;
  try {
    const buf = Buffer.from(hex, "hex");
    const lng = buf.readDoubleLE(9);
    const lat = buf.readDoubleLE(17);
    return { lat, lng };
  } catch {
    return null;
  }
}
