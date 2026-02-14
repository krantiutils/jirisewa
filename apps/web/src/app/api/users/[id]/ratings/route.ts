import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function parsePositiveInt(value: string | null, fallback: number): number {
  if (!value) return fallback;
  const n = parseInt(value, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

/**
 * GET /api/users/:id/ratings — public paginated ratings for a user.
 *
 * Query params: page (default 1), per_page (default 10, max 50)
 *
 * Returns: { ratings, avgScore, count, page, perPage }
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id: userId } = await params;
  const searchParams = request.nextUrl.searchParams;

  const page = parsePositiveInt(searchParams.get("page"), 1);
  const perPage = Math.min(parsePositiveInt(searchParams.get("per_page"), 10), 50);
  const from = (page - 1) * perPage;
  const to = from + perPage - 1;

  try {
    const supabase = await createSupabaseServerClient();

    // Verify user exists and get their rating stats
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("id, name, rating_avg, rating_count")
      .eq("id", userId)
      .single();

    if (userError || !user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Fetch paginated ratings with rater info
    const { data: ratings, error: ratingsError, count } = await supabase
      .from("ratings")
      .select(
        "id, order_id, score, comment, role_rated, created_at, rater:users!ratings_rater_id_fkey(id, name, avatar_url)",
        { count: "exact" },
      )
      .eq("rated_id", userId)
      .order("created_at", { ascending: false })
      .range(from, to);

    if (ratingsError) {
      console.error("GET /api/users/[id]/ratings error:", ratingsError);
      return NextResponse.json(
        { error: "Failed to fetch ratings" },
        { status: 500 },
      );
    }

    return NextResponse.json({
      ratings: ratings ?? [],
      avgScore: Number(user.rating_avg),
      count: count ?? 0,
      page,
      perPage,
    });
  } catch {
    return NextResponse.json(
      { error: "Unable to fetch user ratings" },
      { status: 500 },
    );
  }
}
