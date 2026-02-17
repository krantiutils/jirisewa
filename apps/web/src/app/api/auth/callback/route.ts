import { createClient } from "@/lib/supabase/server";
import { NextRequest, NextResponse } from "next/server";

export const runtime = "edge";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get("code");
  const error = searchParams.get("error");
  const errorDescription = searchParams.get("error_description");

  // Handle OAuth errors
  if (error) {
    return NextResponse.redirect(
      new URL(`/?error=${error}&description=${errorDescription || ""}`, request.url)
    );
  }

  const supabase = await createClient();

  // Exchange code for session (Supabase handles this automatically via cookie)
  // The code is already in the URL from the OAuth callback
  if (code) {
    await supabase.auth.exchangeCodeForSession(code);
  }

  // Get user and ensure profile exists
  const { data: { user } } = await supabase.auth.getUser();

  if (user) {
    // Check if profile exists
    const { data: profile, error: profileError } = await supabase
      .from("user_profiles")
      .select("id, onboarding_completed, role")
      .eq("id", user.id)
      .single();

    // If profile doesn't exist (RLS or not created), create it using metadata
    if (!profile || profileError) {
      const fullName =
        user.user_metadata?.full_name ||
        user.user_metadata?.name ||
        null;
      const avatarUrl =
        user.user_metadata?.avatar_url ||
        user.user_metadata?.picture ||
        null;

      const { error: insertError } = await supabase
        .from("user_profiles")
        .insert({
          id: user.id,
          email: user.email,
          full_name: fullName,
          avatar_url: avatarUrl,
          role: null,
          onboarding_completed: false,
        });

      // If insert failed due to RLS, the trigger should have created it anyway
      if (insertError && insertError.code !== "23505") {
        // 23505 is duplicate key - profile already exists via trigger
        console.error("Failed to create user profile:", insertError);
      }

      // New user - redirect to onboarding
      return NextResponse.redirect(new URL("/onboarding", request.url));
    }

    // Profile exists - check onboarding status
    if (profile && !profile.onboarding_completed) {
      return NextResponse.redirect(new URL("/onboarding", request.url));
    }

    // Onboarding complete - redirect to appropriate dashboard
    if (profile && profile.onboarding_completed) {
      const dashboardMap: Record<string, string> = {
        farmer: "/farmer/dashboard",
        rider: "/rider/dashboard",
        customer: "/customer",
      };
      const redirectPath = dashboardMap[profile.role || "customer"] || "/customer";
      return NextResponse.redirect(new URL(redirectPath, request.url));
    }
  }

  // Fallback - redirect to onboarding or root
  return NextResponse.redirect(new URL("/onboarding", request.url));
}
