"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

export async function deleteAccount(): Promise<ActionResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const admin = createServiceRoleClient();
  const uid = user.id;

  // Delete in order to satisfy RESTRICT foreign key constraints.
  // Everything else cascades when we delete from auth.users at the end.

  // 1. ratings (rater_id & rated_id → RESTRICT)
  await admin.from("ratings").delete().eq("rater_id", uid);
  await admin.from("ratings").delete().eq("rated_id", uid);

  // 2. order_items (farmer_id → RESTRICT)
  await admin.from("order_items").delete().eq("farmer_id", uid);

  // 3. order_farmer_splits (farmer_id → RESTRICT)
  await admin.from("order_farmer_splits").delete().eq("farmer_id", uid);

  // 4. bulk_order_items (farmer_id → RESTRICT)
  await admin.from("bulk_order_items").delete().eq("farmer_id", uid);

  // 5. orders (consumer_id → RESTRICT)
  await admin.from("orders").delete().eq("consumer_id", uid);

  // 6. earnings & payout_requests (reference auth.users without ON DELETE)
  await admin.from("earnings").delete().eq("user_id", uid);
  await admin.from("payout_requests").delete().eq("user_id", uid);

  // 7. Delete auth user — cascades to users, user_profiles, user_roles,
  //    produce_listings, rider_trips, notifications, chat_messages, etc.
  const { error } = await admin.auth.admin.deleteUser(uid);
  if (error) return { error: error.message };

  return { data: undefined };
}
