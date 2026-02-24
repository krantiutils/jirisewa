"use server";

import { createServiceRoleClient, createClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

// Helper: get authenticated user
async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function updateProfile(input: {
  fullName: string;
  phone: string;
  bio?: string;
}): Promise<ActionResult> {
  const user = await getAuthUser();
  if (!user) return { error: "Not authenticated" };

  const supabase = createServiceRoleClient();
  const { error } = await supabase
    .from("user_profiles")
    .update({
      full_name: input.fullName.trim(),
      phone: input.phone.trim() || null,
      bio: input.bio?.trim() || null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", user.id);

  if (error) return { error: error.message };
  return { data: undefined };
}

export async function changePassword(input: {
  currentPassword: string;
  newPassword: string;
}): Promise<ActionResult> {
  const user = await getAuthUser();
  if (!user) return { error: "Not authenticated" };

  if (!user.email) {
    return { error: "Password change is only available for email accounts" };
  }

  // Verify current password by attempting sign-in
  const supabase = await createClient();
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password: input.currentPassword,
  });

  if (signInError) {
    return { error: "Current password is incorrect" };
  }

  // Update to new password
  const { error: updateError } = await supabase.auth.updateUser({
    password: input.newPassword,
  });

  if (updateError) return { error: updateError.message };
  return { data: undefined };
}
