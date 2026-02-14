export const locales = ["en", "ne"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "ne";

// Map constants
export const MAP_TILE_URL =
  "https://tile.openstreetmap.org/{z}/{x}/{y}.png" as const;

export const MAP_ATTRIBUTION =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';

export const NOMINATIM_BASE_URL =
  "https://nominatim.openstreetmap.org" as const;

export const OSRM_BASE_URL =
  "https://router.project-osrm.org" as const;

/** Jiri, Nepal — launch area default center */
export const MAP_DEFAULT_CENTER = { lat: 27.6306, lng: 86.2305 } as const;

export const MAP_DEFAULT_ZOOM = 13 as const;

/** Nepal bounding box for constraining map views */
export const NEPAL_BOUNDS = {
  southWest: { lat: 26.347, lng: 80.058 },
  northEast: { lat: 30.447, lng: 88.201 },
} as const;

// Order ping constants
/** How long a rider has to respond to a ping (5 minutes) */
export const PING_EXPIRY_MS = 5 * 60 * 1000;

/** Maximum detour distance in meters for rider matching (5 km) */
export const MAX_DETOUR_M = 5000;

/** Maximum number of riders to ping per order */
export const MAX_PINGS_PER_ORDER = 10;
