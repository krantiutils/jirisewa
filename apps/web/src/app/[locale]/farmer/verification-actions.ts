"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import type { VerificationStatus } from "@/lib/supabase/types";

type ActionResult<T = null> =
  | { success: true; data: T }
  | { success: false; error: string };

async function getAuthenticatedFarmerRole() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    return { supabase, user: null, role: null, error: "Not authenticated" } as const;
  }

  const { data: userRole } = await supabase
    .from("user_roles")
    .select("id, role, verified, verification_status")
    .eq("user_id", user.id)
    .eq("role", "farmer")
    .single();

  if (!userRole) {
    return { supabase, user: null, role: null, error: "Not a farmer" } as const;
  }

  return { supabase, user, role: userRole, error: null } as const;
}

export type VerificationData = {
  verificationStatus: VerificationStatus;
  verified: boolean;
  documents: {
    id: string;
    citizenship_photo_url: string;
    farm_photo_url: string;
    municipality_letter_url: string | null;
    admin_notes: string | null;
    created_at: string;
  } | null;
};

export async function getVerificationStatus(): Promise<ActionResult<VerificationData>> {
  const { supabase, user, role, error: authError } = await getAuthenticatedFarmerRole();
  if (!user || !role) {
    return { success: false, error: authError };
  }

  const { data: docs } = await supabase
    .from("verification_documents")
    .select("id, citizenship_photo_url, farm_photo_url, municipality_letter_url, admin_notes, created_at")
    .eq("user_role_id", role.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .single();

  return {
    success: true,
    data: {
      verificationStatus: role.verification_status as VerificationStatus,
      verified: role.verified,
      documents: docs ?? null,
    },
  };
}

export async function uploadVerificationDocument(
  formData: FormData,
): Promise<ActionResult<{ url: string }>> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmerRole();
  if (!user) {
    return { success: false, error: authError };
  }

  const file = formData.get("file") as File | null;
  if (!file) {
    return { success: false, error: "No file provided" };
  }

  if (file.size > 5242880) {
    return { success: false, error: "File too large (max 5MB)" };
  }

  const allowedTypes = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
  if (!allowedTypes.includes(file.type)) {
    return { success: false, error: "Invalid file type. Use JPEG, PNG, WebP, or PDF." };
  }

  const mimeToExt: Record<string, string> = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "application/pdf": "pdf",
  };
  const ext = mimeToExt[file.type] ?? "jpg";
  const fileName = `${user.id}/${crypto.randomUUID()}.${ext}`;

  const { error } = await supabase.storage
    .from("verification-docs")
    .upload(fileName, file, {
      contentType: file.type,
      upsert: false,
    });

  if (error) {
    return { success: false, error: error.message };
  }

  // Verification docs are in a private bucket — generate a signed URL
  const { data: signedData, error: signError } = await supabase.storage
    .from("verification-docs")
    .createSignedUrl(fileName, 60 * 60 * 24 * 365); // 1 year

  if (signError || !signedData) {
    return { success: false, error: signError?.message ?? "Failed to generate URL" };
  }

  return { success: true, data: { url: signedData.signedUrl } };
}

export async function submitVerificationDocuments(
  citizenshipPhotoUrl: string,
  farmPhotoUrl: string,
  municipalityLetterUrl: string | null,
): Promise<ActionResult> {
  const { supabase, user, role, error: authError } = await getAuthenticatedFarmerRole();
  if (!user || !role) {
    return { success: false, error: authError };
  }

  if (role.verification_status === "pending") {
    return { success: false, error: "Documents already submitted and under review." };
  }

  if (role.verification_status === "approved") {
    return { success: false, error: "Already verified." };
  }

  // Validate URLs are non-empty strings (basic check)
  if (!citizenshipPhotoUrl || !farmPhotoUrl) {
    return { success: false, error: "Citizenship photo and farm photo are required." };
  }

  // Insert verification document record
  const { data: docData, error: insertError } = await supabase
    .from("verification_documents")
    .insert({
      user_role_id: role.id,
      citizenship_photo_url: citizenshipPhotoUrl,
      farm_photo_url: farmPhotoUrl,
      municipality_letter_url: municipalityLetterUrl || null,
    })
    .select("id")
    .single();

  if (insertError) {
    return { success: false, error: insertError.message };
  }

  // Update user_role verification_status to pending
  const { error: updateError } = await supabase
    .from("user_roles")
    .update({ verification_status: "pending" as const })
    .eq("id", role.id);

  if (updateError) {
    // Rollback: delete the document record if status update fails
    if (docData) {
      await supabase.from("verification_documents").delete().eq("id", docData.id);
    }
    return { success: false, error: updateError.message };
  }

  revalidatePath("/[locale]/farmer/dashboard");
  return { success: true, data: null };
}
