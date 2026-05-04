import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextRequest, NextResponse } from "next/server";

export const runtime = "edge";

type CallbackDatabase = {
  public: {
    Tables: {
      user_profiles: {
        Row: {
          id: string;
          onboarding_completed: boolean | null;
          role: string | null;
        };
        Insert: {
          id: string;
          email?: string | null;
          full_name?: string | null;
          avatar_url?: string | null;
          role?: string | null;
          onboarding_completed?: boolean | null;
        };
        Update: never;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get("code");
  const error = searchParams.get("error");
  const errorDescription = searchParams.get("error_description");

  // Get the actual host from the request (not localhost)
  const host = request.headers.get('host') || 'khetbata.xyz';
  const protocol = request.headers.get('x-forwarded-proto') || 'https';
  const baseUrl = protocol + "://" + host;

  // Handle OAuth errors
  if (error) {
    const errorParam = error ? encodeURIComponent(error) : "";
    const descParam = errorDescription ? encodeURIComponent(errorDescription) : "";
    return NextResponse.redirect(
      new URL("/?error=" + errorParam + "&description=" + descParam, baseUrl)
    );
  }

  // Create Supabase client with proper cookie handling for edge runtime
  // In edge runtime, we need to collect cookies and apply them to the final redirect response
  const cookiesToSet: {
    name: string;
    value: string;
    options: CookieOptions;
  }[] = [];

  const supabase = createServerClient<CallbackDatabase>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookies) {
          cookies.forEach(({ name, value, options }) => {
            cookiesToSet.push({ name, value, options });
          });
        },
      },
    }
  );

  // Exchange code for session (Supabase handles this automatically via cookie)
  // The code is already in the URL from the OAuth callback
  if (code) {
    await supabase.auth.exchangeCodeForSession(code);
  }

  // Get user and ensure profile exists
  const { data: { user } } = await supabase.auth.getUser();

  if (user) {
    // Check if profile exists - use type assertion
    const { data: profile, error: profileError } = await supabase
      .from("user_profiles")
      .select("id, onboarding_completed, role")
      .eq("id", user.id)
      .single();

    // If profile does not exist (RLS or not created), create it using metadata
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

      // New user - redirect to onboarding with locale prefix
      const redirectUrl = new URL("/ne/onboarding", baseUrl);
      const response = NextResponse.redirect(redirectUrl);
      cookiesToSet.forEach(({ name, value, options }) => {
        response.cookies.set(name, value, options);
      });
      return response;
    }

    // Profile exists - check onboarding status
    if (profile && !profile.onboarding_completed) {
      const redirectUrl = new URL("/ne/onboarding", baseUrl);
      const response = NextResponse.redirect(redirectUrl);
      cookiesToSet.forEach(({ name, value, options }) => {
        response.cookies.set(name, value, options);
      });
      return response;
    }

    // Onboarding complete - redirect to appropriate dashboard
    if (profile && profile.onboarding_completed) {
      const dashboardMap: Record<string, string> = {
        farmer: "/farmer/dashboard",
        rider: "/rider/dashboard",
        customer: "/customer",
      };
      const redirectPath = dashboardMap[profile.role || "customer"] || "/customer";
      const redirectUrl = new URL("/ne" + redirectPath, baseUrl);
      const response = NextResponse.redirect(redirectUrl);
      cookiesToSet.forEach(({ name, value, options }) => {
        response.cookies.set(name, value, options);
      });
      return response;
    }
  }

  // Fallback - redirect to onboarding with locale prefix
  const redirectUrl = new URL("/ne/onboarding", baseUrl);
  const response = NextResponse.redirect(redirectUrl);
  cookiesToSet.forEach(({ name, value, options }) => {
    response.cookies.set(name, value, options);
  });
  return response;
}
