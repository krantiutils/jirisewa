import { NextRequest, NextResponse } from "next/server";
import { fetchProduceListings, type ProduceFilters } from "@/lib/queries/produce";

const VALID_SORT_VALUES = new Set([
  "price_asc",
  "price_desc",
  "freshness",
  "rating",
  "distance",
]);

function parseFiniteNumber(value: string | null): number | undefined {
  if (!value) return undefined;
  const n = Number(value);
  return Number.isFinite(n) ? n : undefined;
}

/**
 * GET /api/produce — browse marketplace with filters.
 *
 * Query params: category_id, min_price, max_price, lat, lng, radius_km,
 *               search, sort_by, page, per_page
 */
export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams;

  const filters: ProduceFilters = {};

  const categoryId = params.get("category_id");
  if (categoryId) filters.category_id = categoryId;

  filters.min_price = parseFiniteNumber(params.get("min_price"));
  filters.max_price = parseFiniteNumber(params.get("max_price"));

  const lat = parseFiniteNumber(params.get("lat"));
  const lng = parseFiniteNumber(params.get("lng"));
  if (lat != null && lng != null) {
    filters.lat = lat;
    filters.lng = lng;
  }

  filters.radius_km = parseFiniteNumber(params.get("radius_km"));

  const search = params.get("search");
  if (search) filters.search = search.slice(0, 200); // Cap search length

  const sortBy = params.get("sort_by");
  if (sortBy && VALID_SORT_VALUES.has(sortBy)) {
    filters.sort_by = sortBy as ProduceFilters["sort_by"];
  }

  filters.page = parseFiniteNumber(params.get("page"));
  filters.per_page = parseFiniteNumber(params.get("per_page"));

  try {
    const result = await fetchProduceListings(filters);
    return NextResponse.json(result);
  } catch {
    return NextResponse.json(
      { error: "Unable to fetch produce listings" },
      { status: 500 },
    );
  }
}
