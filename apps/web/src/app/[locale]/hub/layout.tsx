import { setRequestLocale } from "next-intl/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireHubOperator } from "@/lib/hub/auth";
import { HubSidebar } from "./_components/HubSidebar";

export const dynamic = "force-dynamic";

export default async function HubLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const { hubId } = await requireHubOperator(locale);

  let hubName: string | null = null;
  if (hubId) {
    const supabase = await createSupabaseServerClient();
    // pickup_hubs is missing from the generated Database type — cast around it.
    const { data } = await (supabase as unknown as {
      from: (t: string) => {
        select: (s: string) => {
          eq: (k: string, v: string) => {
            maybeSingle: () => Promise<{ data: { name_en: string } | null }>;
          };
        };
      };
    })
      .from("pickup_hubs")
      .select("name_en")
      .eq("id", hubId)
      .maybeSingle();
    hubName = data?.name_en ?? null;
  }

  return (
    <div className="flex min-h-[calc(100vh-57px)]">
      <HubSidebar locale={locale} hubName={hubName} />
      <main className="flex-1 bg-gray-50 p-6 overflow-auto">{children}</main>
    </div>
  );
}
