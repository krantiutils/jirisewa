import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

/**
 * Gate a server component / action behind hub-operator (or admin) access.
 * Returns the operated-hub row, or redirects to /{locale} if the caller
 * isn't authorized. Admins are allowed in but get a synthetic-style hub
 * record only if they actually operate one — otherwise the page itself
 * decides what to show.
 */
export async function requireHubOperator(
  locale: string,
): Promise<{ userId: string; hubId: string | null; isAdmin: boolean }> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/auth/login`);

  // Fetch role + admin flag in one shot. The generated app_role enum type
  // hasn't been regenerated since 'hub_operator' was added in migration
  // 20260429000001, so we cast to a record to read it.
  const { data: profileRaw } = await supabase
    .from("users")
    .select("role, is_admin")
    .eq("id", user.id)
    .maybeSingle();
  const profile = profileRaw as { role?: string; is_admin?: boolean } | null;

  const isAdmin = profile?.is_admin === true;
  const isHubOperator = profile?.role === "hub_operator";
  if (!isAdmin && !isHubOperator) redirect(`/${locale}`);

  // Find the hub they operate (admins might not operate any). The pickup_hubs
  // table also pre-dates the generated types in this branch.
  const { data: hubRaw } = await (supabase as unknown as {
    from: (t: string) => {
      select: (s: string) => {
        eq: (k: string, v: string) => {
          eq: (k: string, v: boolean) => {
            maybeSingle: () => Promise<{ data: { id: string } | null }>;
          };
        };
      };
    };
  })
    .from("pickup_hubs")
    .select("id")
    .eq("operator_id", user.id)
    .eq("is_active", true)
    .maybeSingle();

  return { userId: user.id, hubId: hubRaw?.id ?? null, isAdmin };
}
