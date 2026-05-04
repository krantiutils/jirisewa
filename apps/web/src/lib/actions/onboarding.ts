"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

interface CompleteOnboardingInput {
  role: "customer" | "farmer" | "rider";
  fullName?: string;
  vehicleType?: string;
  fixedRouteOrigin?: { lat: number; lng: number; name: string } | null;
  fixedRouteDest?: { lat: number; lng: number; name: string } | null;
}

export async function completeOnboarding(
  input: CompleteOnboardingInput,
): Promise<ActionResult<{ dashboard: string }>> {
  try {
    const authClient = await createClient();
    const { data: { user } } = await authClient.auth.getUser();
    if (!user) return { error: "Not authenticated" };

    const supabase = createServiceRoleClient();

    // 1. Upsert user_profiles
    // Phone-OTP signups don't have a row here (only the OAuth callback creates
    // one), so update() would silently affect 0 rows and the onboarding state
    // would never persist. Upsert handles both cases.
    const profileUpdate: Record<string, unknown> = {
      id: user.id,
      role: input.role,
      onboarding_completed: true,
      email: user.email ?? null,
      phone: user.phone ?? null,
    };
    if (input.fullName?.trim()) {
      profileUpdate.full_name = input.fullName.trim();
    }
    if (input.role === "rider" && input.vehicleType) {
      profileUpdate.vehicle_type = input.vehicleType;
      if (["bus", "truck"].includes(input.vehicleType)) {
        if (input.fixedRouteOrigin) {
          profileUpdate.fixed_route_origin = `POINT(${input.fixedRouteOrigin.lng} ${input.fixedRouteOrigin.lat})`;
          profileUpdate.fixed_route_origin_name = input.fixedRouteOrigin.name;
        }
        if (input.fixedRouteDest) {
          profileUpdate.fixed_route_destination = `POINT(${input.fixedRouteDest.lng} ${input.fixedRouteDest.lat})`;
          profileUpdate.fixed_route_destination_name = input.fixedRouteDest.name;
        }
      }
    }

    const { error: profileError } = await supabase
      .from("user_profiles")
      .upsert(profileUpdate, { onConflict: "id" });

    if (profileError) {
      console.error("[onboarding] user_profiles upsert failed:", profileError);
      return { error: `user_profiles: ${profileError.message}` };
    }

    // 2. Ensure row in users table (FK target for orders.consumer_id)
    const appRole = input.role === "customer" ? "consumer" : input.role;
    const phone = user.phone || user.user_metadata?.phone || user.email || user.id;
    const name = input.fullName?.trim() || user.user_metadata?.full_name || user.email || "User";

    const { error: usersError } = await supabase
      .from("users")
      .upsert(
        { id: user.id, phone, name, role: appRole },
        { onConflict: "id" },
      );
    if (usersError) {
      console.error("[onboarding] users upsert failed:", usersError, {
        id: user.id,
        phone,
        name,
        role: appRole,
      });
      return { error: `users: ${usersError.message}` };
    }

    // 3. Ensure row in user_roles
    const { error: rolesError } = await supabase
      .from("user_roles")
      .insert({ user_id: user.id, role: appRole });
    if (rolesError && rolesError.code !== "23505") {
      console.error("[onboarding] user_roles insert failed:", rolesError);
      // Non-fatal
    }

    const dashboardMap: Record<string, string> = {
      farmer: "/farmer/dashboard",
      rider: "/rider/dashboard",
      customer: "/customer",
    };

    return { data: { dashboard: dashboardMap[input.role] || "/customer" } };
  } catch (err) {
    console.error("completeOnboarding unexpected error:", err);
    return { error: "Failed to complete onboarding" };
  }
}
