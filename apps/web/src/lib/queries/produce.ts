import { createClient } from "@/lib/supabase/server";
import type { ProduceCategory, ProduceListingWithDetails } from "@/lib/supabase/types";

export interface ProduceFilters {
  category_id?: string;
  min_price?: number;
  max_price?: number;
  lat?: number;
  lng?: number;
  radius_km?: number;
  search?: string;
  sort_by?: "price_asc" | "price_desc" | "freshness" | "rating" | "distance";
  page?: number;
  per_page?: number;
}

export interface ProduceListResult {
  listings: ProduceListingWithDetails[];
  total: number;
  page: number;
  per_page: number;
}

const DEFAULT_PER_PAGE = 12;

/** Row shape returned by the search_produce_listings RPC */
interface RpcProduceRow {
  id: string;
  farmer_id: string;
  category_id: string;
  name_en: string;
  name_ne: string;
  description: string | null;
  price_per_kg: number;
  available_qty_kg: number;
  freshness_date: string | null;
  location: string | null;
  photos: string[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
  distance_km: number | null;
  farmer_name: string;
  farmer_avatar_url: string | null;
  farmer_rating_avg: number;
  farmer_rating_count: number;
  category_name_en: string;
  category_name_ne: string;
  category_icon: string | null;
  total_count: number;
}

/** Row shape returned by the listings query with joined relations */
interface JoinedListingRow {
  id: string;
  farmer_id: string;
  category_id: string;
  name_en: string;
  name_ne: string;
  description: string | null;
  price_per_kg: number;
  available_qty_kg: number;
  freshness_date: string | null;
  location: string | null;
  photos: string[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
  farmer: { id: string; name: string; avatar_url: string | null; rating_avg: number; rating_count: number } | Array<{ id: string; name: string; avatar_url: string | null; rating_avg: number; rating_count: number }>;
  category: { id: string; name_en: string; name_ne: string; icon: string | null } | Array<{ id: string; name_en: string; name_ne: string; icon: string | null }>;
}

/**
 * Fetch produce listings with filters, search, sorting, and pagination.
 *
 * When lat/lng are provided, computes distance using PostGIS ST_Distance and
 * optionally filters by radius_km using ST_DWithin.
 */
export async function fetchProduceListings(
  filters: ProduceFilters,
): Promise<ProduceListResult> {
  const page = filters.page ?? 1;
  const perPage = filters.per_page ?? DEFAULT_PER_PAGE;
  const offset = (page - 1) * perPage;

  const hasLocation = filters.lat != null && filters.lng != null;

  if (hasLocation) {
    return fetchWithLocation(filters, offset, perPage, page);
  }

  return fetchWithoutLocation(filters, offset, perPage, page);
}

async function fetchWithLocation(
  filters: ProduceFilters,
  offset: number,
  perPage: number,
  page: number,
): Promise<ProduceListResult> {
  const supabase = await createClient();
  const { lat, lng, radius_km, category_id, min_price, max_price, search, sort_by } =
    filters;

  const { data, error } = await supabase
    .rpc("search_produce_listings" as never, {
      p_lat: lat!,
      p_lng: lng!,
      p_radius_km: radius_km ?? null,
      p_category_id: category_id ?? null,
      p_min_price: min_price ?? null,
      p_max_price: max_price ?? null,
      p_search: search ?? null,
      p_sort_by: sort_by ?? "distance",
      p_limit: perPage,
      p_offset: offset,
    } as never) as { data: RpcProduceRow[] | null; error: { message: string } | null };

  if (error) {
    throw new Error(`Failed to fetch produce listings: ${error.message}`);
  }

  const rows = data ?? [];
  const listings: ProduceListingWithDetails[] = rows.map(mapRpcRow);
  const total = rows[0]?.total_count ?? 0;

  return { listings, total, page, per_page: perPage };
}

async function fetchWithoutLocation(
  filters: ProduceFilters,
  offset: number,
  perPage: number,
  page: number,
): Promise<ProduceListResult> {
  const supabase = await createClient();
  const { category_id, min_price, max_price, search, sort_by } = filters;

  let query = supabase
    .from("produce_listings")
    .select(
      `
      *,
      farmer:users!produce_listings_farmer_id_fkey(id, name, avatar_url, rating_avg, rating_count),
      category:produce_categories!produce_listings_category_id_fkey(id, name_en, name_ne, icon)
    `,
      { count: "exact" },
    )
    .eq("is_active", true);

  if (category_id) {
    query = query.eq("category_id", category_id);
  }
  if (min_price != null) {
    query = query.gte("price_per_kg", min_price);
  }
  if (max_price != null) {
    query = query.lte("price_per_kg", max_price);
  }
  if (search) {
    query = query.or(`name_en.ilike.%${search}%,name_ne.ilike.%${search}%`);
  }

  switch (sort_by) {
    case "price_asc":
      query = query.order("price_per_kg", { ascending: true });
      break;
    case "price_desc":
      query = query.order("price_per_kg", { ascending: false });
      break;
    case "freshness":
      query = query.order("freshness_date", { ascending: false, nullsFirst: false });
      break;
    default:
      query = query.order("created_at", { ascending: false });
  }

  query = query.range(offset, offset + perPage - 1);

  const { data, count, error } = await query as {
    data: JoinedListingRow[] | null;
    count: number | null;
    error: { message: string } | null;
  };

  if (error) {
    throw new Error(`Failed to fetch produce listings: ${error.message}`);
  }

  const listings: ProduceListingWithDetails[] = (data ?? []).map((row) => ({
    id: row.id,
    farmer_id: row.farmer_id,
    category_id: row.category_id,
    name_en: row.name_en,
    name_ne: row.name_ne,
    description: row.description,
    price_per_kg: row.price_per_kg,
    available_qty_kg: row.available_qty_kg,
    freshness_date: row.freshness_date,
    location: row.location,
    photos: row.photos ?? [],
    is_active: row.is_active,
    created_at: row.created_at,
    updated_at: row.updated_at,
    farmer: Array.isArray(row.farmer) ? row.farmer[0] : row.farmer,
    category: Array.isArray(row.category) ? row.category[0] : row.category,
  }));

  return { listings, total: count ?? 0, page, per_page: perPage };
}

/**
 * Fetch a single produce listing by ID with farmer and category details.
 */
export async function fetchProduceById(
  id: string,
): Promise<ProduceListingWithDetails | null> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("produce_listings")
    .select(
      `
      *,
      farmer:users!produce_listings_farmer_id_fkey(id, name, avatar_url, rating_avg, rating_count),
      category:produce_categories!produce_listings_category_id_fkey(id, name_en, name_ne, icon)
    `,
    )
    .eq("id", id)
    .eq("is_active", true)
    .single() as {
    data: JoinedListingRow | null;
    error: { code?: string; message: string } | null;
  };

  if (error) {
    if (error.code === "PGRST116") return null;
    throw new Error(`Failed to fetch produce listing: ${error.message}`);
  }

  if (!data) return null;

  return {
    id: data.id,
    farmer_id: data.farmer_id,
    category_id: data.category_id,
    name_en: data.name_en,
    name_ne: data.name_ne,
    description: data.description,
    price_per_kg: data.price_per_kg,
    available_qty_kg: data.available_qty_kg,
    freshness_date: data.freshness_date,
    location: data.location,
    photos: data.photos ?? [],
    is_active: data.is_active,
    created_at: data.created_at,
    updated_at: data.updated_at,
    farmer: Array.isArray(data.farmer) ? data.farmer[0] : data.farmer,
    category: Array.isArray(data.category) ? data.category[0] : data.category,
  };
}

/**
 * Fetch all produce categories (for filter dropdowns).
 */
export async function fetchCategories(): Promise<ProduceCategory[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("produce_categories")
    .select("*")
    .order("sort_order", { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch categories: ${error.message}`);
  }

  return (data ?? []) as unknown as ProduceCategory[];
}

function mapRpcRow(row: RpcProduceRow): ProduceListingWithDetails {
  return {
    id: row.id,
    farmer_id: row.farmer_id,
    category_id: row.category_id,
    name_en: row.name_en,
    name_ne: row.name_ne,
    description: row.description,
    price_per_kg: row.price_per_kg,
    available_qty_kg: row.available_qty_kg,
    freshness_date: row.freshness_date,
    location: row.location,
    photos: row.photos ?? [],
    is_active: row.is_active,
    created_at: row.created_at,
    updated_at: row.updated_at,
    distance_km:
      row.distance_km != null ? Math.round(row.distance_km * 10) / 10 : undefined,
    farmer: {
      id: row.farmer_id,
      name: row.farmer_name,
      avatar_url: row.farmer_avatar_url,
      rating_avg: row.farmer_rating_avg,
      rating_count: row.farmer_rating_count,
    },
    category: {
      id: row.category_id,
      name_en: row.category_name_en,
      name_ne: row.category_name_ne,
      icon: row.category_icon,
    },
  };
}
