import {
  NOMINATIM_BASE_URL,
  OSRM_BASE_URL,
} from "@jirisewa/shared";

export interface LatLng {
  lat: number;
  lng: number;
}

export interface GeocodingResult {
  displayName: string;
  lat: number;
  lng: number;
}

/**
 * Reverse geocode coordinates to an address string via Nominatim.
 * Respects Nominatim usage policy: max 1 req/s, must set a meaningful User-Agent.
 */
export async function reverseGeocode(
  lat: number,
  lng: number,
): Promise<GeocodingResult | null> {
  const url = new URL("/reverse", NOMINATIM_BASE_URL);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lon", String(lng));

  const res = await fetch(url.toString(), {
    headers: { "User-Agent": "JiriSewa/1.0 (jirisewa.com)" },
  });

  if (!res.ok) {
    return null;
  }

  const data = await res.json();

  if (data.error) {
    return null;
  }

  return {
    displayName: data.display_name,
    lat: parseFloat(data.lat),
    lng: parseFloat(data.lon),
  };
}

/**
 * Forward geocode a query string to coordinates via Nominatim.
 * Bounded to Nepal by default.
 */
export async function forwardGeocode(
  query: string,
): Promise<GeocodingResult[]> {
  const url = new URL("/search", NOMINATIM_BASE_URL);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("q", query);
  url.searchParams.set("countrycodes", "np");
  url.searchParams.set("limit", "5");

  const res = await fetch(url.toString(), {
    headers: { "User-Agent": "JiriSewa/1.0 (jirisewa.com)" },
  });

  if (!res.ok) {
    return [];
  }

  const data = await res.json();

  return data.map(
    (item: { display_name: string; lat: string; lon: string }) => ({
      displayName: item.display_name,
      lat: parseFloat(item.lat),
      lng: parseFloat(item.lon),
    }),
  );
}

export interface RouteResult {
  coordinates: [number, number][]; // [lng, lat] pairs (GeoJSON order)
  distanceMeters: number;
  durationSeconds: number;
}

/**
 * Fetch a driving route between two points via OSRM public demo server.
 * Returns GeoJSON coordinates for the route polyline.
 */
export async function fetchRoute(
  origin: LatLng,
  destination: LatLng,
): Promise<RouteResult | null> {
  const coords = `${origin.lng},${origin.lat};${destination.lng},${destination.lat}`;
  const url = `${OSRM_BASE_URL}/route/v1/driving/${coords}?overview=full&geometries=geojson`;

  const res = await fetch(url);

  if (!res.ok) {
    return null;
  }

  const data = await res.json();

  if (data.code !== "Ok" || !data.routes?.length) {
    return null;
  }

  const route = data.routes[0];

  return {
    coordinates: route.geometry.coordinates,
    distanceMeters: route.distance,
    durationSeconds: route.duration,
  };
}
