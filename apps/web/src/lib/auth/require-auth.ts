import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function requireAuth(locale: string) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/auth/login`);
  return user;
}
