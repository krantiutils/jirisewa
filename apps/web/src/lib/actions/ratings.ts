"use server";

import { RoleRated } from "@jirisewa/shared";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import type { Tables } from "@/lib/supabase/types";

export type ActionResult<T = null> =
  | { success: true; data: T }
  | { success: false; error: string };

export type RatingWithUsers = Tables<"ratings"> & {
  rater: Pick<Tables<"users">, "id" | "name" | "avatar_url"> | null;
  rated: Pick<Tables<"users">, "id" | "name" | "avatar_url"> | null;
};

export type SubmitRatingInput = {
  orderId: string;
  ratedId: string;
  roleRated: RoleRated;
  score: number;
  comment?: string;
};

export type RatingStatus = {
  orderId: string;
  canRate: { ratedId: string; ratedName: string; roleRated: RoleRated }[];
  alreadyRated: { ratedId: string; ratedName: string; roleRated: RoleRated; score: number }[];
};

/**
 * Submit a rating for a delivered order.
 *
 * Validates:
 * 1. User is authenticated
 * 2. Order exists and is delivered
 * 3. User is a party to the order (consumer, rider, or farmer with items)
 * 4. User hasn't already rated this person for this order
 * 5. Score is 1-5
 * 6. Rated user is actually a party to the order in the claimed role
 */
export async function submitRating(
  input: SubmitRatingInput,
): Promise<ActionResult<Tables<"ratings">>> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return { success: false, error: "Not authenticated" };
  }

  // Validate score
  if (!Number.isInteger(input.score) || input.score < 1 || input.score > 5) {
    return { success: false, error: "Score must be an integer between 1 and 5" };
  }

  // Validate role_rated enum
  if (!Object.values(RoleRated).includes(input.roleRated)) {
    return { success: false, error: "Invalid role_rated value" };
  }

  // Cannot rate yourself
  if (input.ratedId === user.id) {
    return { success: false, error: "You cannot rate yourself" };
  }

  // Fetch order with items to validate parties
  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select("id, consumer_id, rider_id, status, order_items(farmer_id)")
    .eq("id", input.orderId)
    .single();

  if (orderError || !order) {
    return { success: false, error: "Order not found" };
  }

  if (order.status !== "delivered") {
    return { success: false, error: "Ratings can only be submitted for delivered orders" };
  }

  // Determine all parties to this order
  const farmerIds = [
    ...new Set(
      (order.order_items as { farmer_id: string }[]).map((item) => item.farmer_id),
    ),
  ];
  const allPartyIds = new Set([
    order.consumer_id,
    ...(order.rider_id ? [order.rider_id] : []),
    ...farmerIds,
  ]);

  // Verify rater is a party to the order
  if (!allPartyIds.has(user.id)) {
    return { success: false, error: "You are not a party to this order" };
  }

  // Verify rated user is a party to the order
  if (!allPartyIds.has(input.ratedId)) {
    return { success: false, error: "Rated user is not a party to this order" };
  }

  // Verify the role_rated matches the rated user's actual role in this order
  const roleValid = validateRoleForOrder(
    input.ratedId,
    input.roleRated,
    order.consumer_id,
    order.rider_id,
    farmerIds,
  );
  if (!roleValid) {
    return {
      success: false,
      error: "The rated user does not hold the specified role in this order",
    };
  }

  // Validate the rater→rated relationship makes sense:
  // Consumer can rate farmer or rider
  // Farmer can rate rider
  // Rider can rate farmer
  const validRelationship = validateRatingRelationship(
    user.id,
    input.ratedId,
    input.roleRated,
    order.consumer_id,
    order.rider_id,
    farmerIds,
  );
  if (!validRelationship) {
    return { success: false, error: "Invalid rating relationship" };
  }

  // Check for duplicate rating (UNIQUE constraint will catch this too, but
  // we give a friendlier error)
  const { data: existing } = await supabase
    .from("ratings")
    .select("id")
    .eq("order_id", input.orderId)
    .eq("rater_id", user.id)
    .eq("rated_id", input.ratedId)
    .maybeSingle();

  if (existing) {
    return {
      success: false,
      error: "You have already rated this person for this order",
    };
  }

  // Insert the rating
  const { data: rating, error: insertError } = await supabase
    .from("ratings")
    .insert({
      order_id: input.orderId,
      rater_id: user.id,
      rated_id: input.ratedId,
      role_rated: input.roleRated,
      score: input.score,
      comment: input.comment?.trim() || null,
    })
    .select()
    .single();

  if (insertError) {
    console.error("submitRating insert error:", insertError);
    // Handle unique constraint violation gracefully
    if (insertError.code === "23505") {
      return {
        success: false,
        error: "You have already rated this person for this order",
      };
    }
    return { success: false, error: "Failed to submit rating" };
  }

  revalidatePath("/[locale]/orders");
  return { success: true, data: rating as Tables<"ratings"> };
}

/**
 * Get the rating status for an order — who can still be rated and who has already been rated.
 */
export async function getOrderRatingStatus(
  orderId: string,
): Promise<ActionResult<RatingStatus>> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return { success: false, error: "Not authenticated" };
  }

  // Fetch order with items and existing ratings
  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select(
      "id, consumer_id, rider_id, status, order_items(farmer_id), ratings(rater_id, rated_id, role_rated, score)",
    )
    .eq("id", orderId)
    .single();

  if (orderError || !order) {
    return { success: false, error: "Order not found" };
  }

  if (order.status !== "delivered") {
    return {
      success: true,
      data: { orderId, canRate: [], alreadyRated: [] },
    };
  }

  const farmerIds = [
    ...new Set(
      (order.order_items as { farmer_id: string }[]).map((item) => item.farmer_id),
    ),
  ];

  // Build the list of possible rating targets for the current user
  const possibleTargets = getPossibleRatingTargets(
    user.id,
    order.consumer_id,
    order.rider_id,
    farmerIds,
  );

  // Fetch names for all target users
  const targetIds = possibleTargets.map((t) => t.ratedId);
  const { data: users } = await supabase
    .from("users")
    .select("id, name")
    .in("id", targetIds.length > 0 ? targetIds : ["__none__"]);

  const userNameMap = new Map(
    (users ?? []).map((u) => [u.id, u.name]),
  );

  const existingRatings = (order.ratings ?? []) as {
    rater_id: string;
    rated_id: string;
    role_rated: string;
    score: number;
  }[];

  const canRate: RatingStatus["canRate"] = [];
  const alreadyRated: RatingStatus["alreadyRated"] = [];

  for (const target of possibleTargets) {
    const existing = existingRatings.find(
      (r) =>
        r.rater_id === user.id &&
        r.rated_id === target.ratedId,
    );
    const name = userNameMap.get(target.ratedId) ?? "Unknown";

    if (existing) {
      alreadyRated.push({
        ratedId: target.ratedId,
        ratedName: name,
        roleRated: target.roleRated,
        score: existing.score,
      });
    } else {
      canRate.push({
        ratedId: target.ratedId,
        ratedName: name,
        roleRated: target.roleRated,
      });
    }
  }

  return { success: true, data: { orderId, canRate, alreadyRated } };
}

/**
 * Get paginated ratings received by a user.
 */
export async function getUserRatings(
  userId: string,
  page: number = 1,
  perPage: number = 10,
): Promise<
  ActionResult<{
    ratings: RatingWithUsers[];
    total: number;
    page: number;
    perPage: number;
  }>
> {
  const supabase = await createSupabaseServerClient();

  const from = (page - 1) * perPage;
  const to = from + perPage - 1;

  const { data, error, count } = await supabase
    .from("ratings")
    .select(
      "*, rater:users!ratings_rater_id_fkey(id, name, avatar_url), rated:users!ratings_rated_id_fkey(id, name, avatar_url)",
      { count: "exact" },
    )
    .eq("rated_id", userId)
    .order("created_at", { ascending: false })
    .range(from, to);

  if (error) {
    console.error("getUserRatings error:", error);
    return { success: false, error: "Failed to fetch ratings" };
  }

  return {
    success: true,
    data: {
      ratings: data as unknown as RatingWithUsers[],
      total: count ?? 0,
      page,
      perPage,
    },
  };
}

// --- Private helpers ---

function validateRoleForOrder(
  ratedId: string,
  roleRated: RoleRated,
  consumerId: string,
  riderId: string | null,
  farmerIds: string[],
): boolean {
  switch (roleRated) {
    case RoleRated.Consumer:
      return ratedId === consumerId;
    case RoleRated.Rider:
      return ratedId === riderId;
    case RoleRated.Farmer:
      return farmerIds.includes(ratedId);
    default:
      return false;
  }
}

function validateRatingRelationship(
  raterId: string,
  ratedId: string,
  roleRated: RoleRated,
  consumerId: string,
  riderId: string | null,
  farmerIds: string[],
): boolean {
  const isConsumer = raterId === consumerId;
  const isRider = raterId === riderId;
  const isFarmer = farmerIds.includes(raterId);

  // Consumer can rate farmer (produce quality) or rider (delivery quality)
  if (isConsumer) {
    return (
      (roleRated === RoleRated.Farmer && farmerIds.includes(ratedId)) ||
      (roleRated === RoleRated.Rider && ratedId === riderId)
    );
  }

  // Farmer can rate rider (cooperation, timeliness)
  if (isFarmer) {
    return roleRated === RoleRated.Rider && ratedId === riderId;
  }

  // Rider can rate farmer (produce readiness, accuracy)
  if (isRider) {
    return roleRated === RoleRated.Farmer && farmerIds.includes(ratedId);
  }

  return false;
}

function getPossibleRatingTargets(
  userId: string,
  consumerId: string,
  riderId: string | null,
  farmerIds: string[],
): { ratedId: string; roleRated: RoleRated }[] {
  const targets: { ratedId: string; roleRated: RoleRated }[] = [];
  const isConsumer = userId === consumerId;
  const isRider = userId === riderId;
  const isFarmer = farmerIds.includes(userId);

  if (isConsumer) {
    // Consumer rates each farmer
    for (const farmerId of farmerIds) {
      targets.push({ ratedId: farmerId, roleRated: RoleRated.Farmer });
    }
    // Consumer rates rider
    if (riderId) {
      targets.push({ ratedId: riderId, roleRated: RoleRated.Rider });
    }
  }

  if (isFarmer && riderId) {
    // Farmer rates rider
    targets.push({ ratedId: riderId, roleRated: RoleRated.Rider });
  }

  if (isRider) {
    // Rider rates each farmer
    for (const farmerId of farmerIds) {
      targets.push({ ratedId: farmerId, roleRated: RoleRated.Farmer });
    }
  }

  return targets;
}
