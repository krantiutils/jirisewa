import { createClient } from "@/lib/supabase/server";
import type { MunicipalitySearchResult } from "@/lib/supabase/types";

export interface MunicipalityFilters {
  query?: string;
  province?: number;
  district?: string;
  limit?: number;
}

/**
 * Search municipalities using the search_municipalities RPC.
 * Returns bilingual name, district, province, and center coordinates.
 */
export async function searchMunicipalities(
  filters: MunicipalityFilters,
): Promise<MunicipalitySearchResult[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .rpc("search_municipalities" as never, {
      p_query: filters.query ?? null,
      p_province: filters.province ?? null,
      p_district: filters.district ?? null,
      p_limit: filters.limit ?? 20,
    } as never) as { data: MunicipalitySearchResult[] | null; error: { message: string } | null };

  if (error) {
    throw new Error(`Failed to search municipalities: ${error.message}`);
  }

  return data ?? [];
}

export interface PopularRouteWithNames {
  id: string;
  origin: MunicipalitySearchResult;
  destination: MunicipalitySearchResult;
  display_order: number;
  trip_count: number;
}

/**
 * Fetch popular routes with resolved municipality names.
 */
export async function fetchPopularRoutes(): Promise<PopularRouteWithNames[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("popular_routes")
    .select(`
      id,
      display_order,
      trip_count,
      origin:municipalities!popular_routes_origin_municipality_id_fkey(id, name_en, name_ne, district, province),
      destination:municipalities!popular_routes_destination_municipality_id_fkey(id, name_en, name_ne, district, province)
    `)
    .eq("is_active", true)
    .order("display_order", { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch popular routes: ${error.message}`);
  }

  return (data ?? []).map((row: Record<string, unknown>) => {
    const origin = Array.isArray(row.origin) ? row.origin[0] : row.origin;
    const dest = Array.isArray(row.destination) ? row.destination[0] : row.destination;
    return {
      id: row.id as string,
      origin: { ...origin, center_lat: null, center_lng: null } as MunicipalitySearchResult,
      destination: { ...dest, center_lat: null, center_lng: null } as MunicipalitySearchResult,
      display_order: row.display_order as number,
      trip_count: row.trip_count as number,
    };
  });
}
