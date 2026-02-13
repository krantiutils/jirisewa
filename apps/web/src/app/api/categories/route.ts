import { NextResponse } from "next/server";
import { fetchCategories } from "@/lib/queries/produce";

/**
 * GET /api/categories — all produce categories for filter dropdowns.
 */
export async function GET() {
  try {
    const categories = await fetchCategories();
    return NextResponse.json(categories);
  } catch {
    return NextResponse.json(
      { error: "Unable to fetch categories" },
      { status: 500 },
    );
  }
}
