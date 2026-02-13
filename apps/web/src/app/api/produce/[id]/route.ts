import { NextRequest, NextResponse } from "next/server";
import { fetchProduceById } from "@/lib/queries/produce";

/**
 * GET /api/produce/:id — single listing with farmer info.
 */
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(id)) {
    return NextResponse.json({ error: "Invalid product ID" }, { status: 400 });
  }

  try {
    const listing = await fetchProduceById(id);
    if (!listing) {
      return NextResponse.json({ error: "Product not found" }, { status: 404 });
    }
    return NextResponse.json(listing);
  } catch {
    return NextResponse.json(
      { error: "Unable to fetch product details" },
      { status: 500 },
    );
  }
}
