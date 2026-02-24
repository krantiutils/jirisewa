"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import { createClient } from "@/lib/supabase/client";
import type { Session, User } from "@supabase/supabase-js";


interface UserProfile {
  id: string;
  email: string | null;
  full_name: string | null;
  phone: string | null;
  avatar_url: string | null;
  role: string | null;
  onboarding_completed: boolean;
  vehicle_type?: string | null;
  fixed_route_origin?: string | null;       // EWKB hex
  fixed_route_origin_name?: string | null;
  fixed_route_destination?: string | null;   // EWKB hex
  fixed_route_destination_name?: string | null;
  bio?: string | null;
}

interface AuthState {
  session: Session | null;
  user: User | null;
  profile: UserProfile | null;
  loading: boolean;
}

interface AuthContextValue extends AuthState {
  signInWithOtp: (phone: string) => Promise<{ error: Error | null }>;
  signInWithGoogle: () => Promise<{ error: Error | null }>;
  signUpWithEmail: (email: string, password: string) => Promise<{ error: Error | null }>;
  signInWithPassword: (email: string, password: string) => Promise<{ error: Error | null }>;
  verifyOtp: (
    phone: string,
    token: string,
  ) => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    session: null,
    user: null,
    profile: null,
    loading: true,
  });
  const supabase = createClient();

  const fetchProfile = useCallback(async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from("user_profiles")
        .select("*")
        .eq("id", userId)
        .single();

      if (error) {
        console.error("Error fetching profile:", error);
        // If profile doesn't exist or RLS blocks it, return null
        // Profile will be created by trigger or callback handler
        if (error.code === "PGRST116") {
          return null; // Profile not found
        }
        // For RLS errors or other issues, also return null
        return null;
      }
      return data as UserProfile | null;
    } catch (err) {
      console.error("Profile fetch error:", err);
      return null;
    }
  }, [supabase]);

  useEffect(() => {
    const initializeAuth = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      const user = session?.user ?? null;

      let profile: UserProfile | null = null;
      if (user) {
        profile = await fetchProfile(user.id);
      }

      setState({ session, user, profile, loading: false });
    };

    initializeAuth();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, session) => {
      const user = session?.user ?? null;

      let profile: UserProfile | null = null;
      if (user) {
        profile = await fetchProfile(user.id);

        const currentPath = window.location.pathname;
        const isAuthPage = currentPath.includes("/auth/") || currentPath === "/login" || currentPath === "/register";

        // Extract locale from path (e.g. "/ne/auth/login" → "ne")
        const localeMatch = currentPath.match(/^\/([a-z]{2})\//);
        const locale = localeMatch ? localeMatch[1] : "en";

        if (!profile) {
          // New signup — profile trigger hasn't fired yet. Redirect to onboarding.
          if (isAuthPage) {
            window.location.href = `/${locale}/onboarding`;
            return;
          }
        } else if (!profile.onboarding_completed) {
          // Profile exists but onboarding not completed
          window.location.href = `/${locale}/onboarding`;
          return;
        } else if (isAuthPage) {
          // Onboarding complete — redirect away from auth pages
          const dashboardMap: Record<string, string> = {
            farmer: "/farmer/dashboard",
            rider: "/rider/dashboard",
            customer: "/marketplace",
          };
          window.location.href = `/${locale}${dashboardMap[profile.role || "customer"] || "/marketplace"}`;
          return;
        }
      }

      setState({ session, user, profile, loading: false });
    });

    return () => subscription.unsubscribe();
  }, [supabase, fetchProfile]);

  const signInWithOtp = useCallback(
    async (phone: string) => {
      const { error } = await supabase.auth.signInWithOtp({ phone });
      return { error: error ? new Error(error.message) : null };
    },
    [supabase],
  );

  const signInWithGoogle = useCallback(async () => {
    // redirectTo should point to our callback handler which will handle the session and redirect
    const origin = typeof window !== "undefined" ? window.location.origin : "";
    const redirectUrl = `${origin}/api/auth/callback`;

    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: redirectUrl,
        queryParams: {
          access_type: "offline",
          prompt: "consent",
        },
        skipBrowserRedirect: false,
      },
    });

    return { error: error ? new Error(error.message) : null };
  }, [supabase]);

  const verifyOtp = useCallback(
    async (phone: string, token: string) => {
      const { error } = await supabase.auth.verifyOtp({
        phone,
        token,
        type: "sms",
      });
      return { error: error ? new Error(error.message) : null };
    },
    [supabase],
  );

  const signUpWithEmail = useCallback(
    async (email: string, password: string) => {
      const { error } = await supabase.auth.signUp({ email, password });
      return { error: error ? new Error(error.message) : null };
    },
    [supabase],
  );

  const signInWithPassword = useCallback(
    async (email: string, password: string) => {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      return { error: error ? new Error(error.message) : null };
    },
    [supabase],
  );

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    setState({ session: null, user: null, profile: null, loading: false });
    // Hard reload to ensure server-side session cookies are cleared
    window.location.href = "/";
  }, [supabase]);

  const refreshProfile = useCallback(async () => {
    if (state.user) {
      const profile = await fetchProfile(state.user.id);
      setState(prev => ({ ...prev, profile }));
    }
  }, [state.user, fetchProfile]);

  return (
    <AuthContext.Provider
      value={{ ...state, signInWithOtp, signInWithGoogle, signUpWithEmail, signInWithPassword, verifyOtp, signOut, refreshProfile }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
