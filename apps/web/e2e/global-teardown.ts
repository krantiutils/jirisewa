import { test as teardown } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "http://127.0.0.1:54321";
const SUPABASE_SERVICE_ROLE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

const TEST_PHONES = ["+9779800000001", "+9779800000002"];

teardown("clean up test data", async () => {
  if (!SUPABASE_SERVICE_ROLE_KEY) return;

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: users } = await supabase.auth.admin.listUsers();
  if (!users?.users) return;

  for (const phone of TEST_PHONES) {
    const user = users.users.find((u) => u.phone === phone);
    if (!user) continue;

    // Delete order items, orders, listings, roles, profile, then auth user
    // Cascading deletes handle most of this, but order_items has RESTRICT
    await supabase.from("order_items").delete().eq("farmer_id", user.id);
    await supabase
      .from("orders")
      .delete()
      .eq("consumer_id", user.id);
    await supabase
      .from("produce_listings")
      .delete()
      .eq("farmer_id", user.id);
    await supabase.from("user_roles").delete().eq("user_id", user.id);
    await supabase.from("users").delete().eq("id", user.id);
    await supabase.auth.admin.deleteUser(user.id);
  }
});
