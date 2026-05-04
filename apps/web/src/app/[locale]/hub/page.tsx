import { setRequestLocale } from "next-intl/server";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  getMyOperatedHub,
  listHubInventory,
} from "@/lib/actions/hubs";
import { HubInventoryTable } from "./_HubInventoryTable";
import { Building2 } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function HubOperatorPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ status?: string }>;
}) {
  const { locale } = await params;
  const sp = await searchParams;
  setRequestLocale(locale);

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/auth/login`);

  const hub = await getMyOperatedHub();
  if (!hub) {
    return (
      <div className="container mx-auto max-w-3xl px-4 py-10">
        <h1 className="text-2xl font-bold">Hub operator dashboard</h1>
        <div className="mt-4 rounded-md bg-yellow-50 p-3 text-sm text-yellow-800">
          You are not assigned as the operator of any active hub. Ask an admin
          to assign you.
        </div>
      </div>
    );
  }

  const all = await listHubInventory(hub.id);
  const filter = sp.status ?? "all";
  const filtered = filter === "all" ? all : all.filter((d) => d.status === filter);

  const counts = {
    dropped_off: all.filter((d) => d.status === "dropped_off").length,
    in_inventory: all.filter((d) => d.status === "in_inventory").length,
    dispatched: all.filter((d) => d.status === "dispatched").length,
    expired: all.filter((d) => d.status === "expired").length,
    spoiled: all.filter((d) => d.status === "spoiled").length,
  };

  const tabs = [
    { key: "all", label: `All (${all.length})` },
    { key: "dropped_off", label: `Awaiting (${counts.dropped_off})` },
    { key: "in_inventory", label: `In inventory (${counts.in_inventory})` },
    { key: "dispatched", label: `Dispatched (${counts.dispatched})` },
    { key: "expired", label: `Expired (${counts.expired})` },
    { key: "spoiled", label: `Spoiled (${counts.spoiled})` },
  ];

  return (
    <div className="container mx-auto max-w-5xl px-4 py-6 space-y-4">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold">
          <Building2 className="h-6 w-6" />
          {hub.name_en}
        </h1>
        <p className="text-sm text-gray-500">{hub.address}</p>
      </div>

      <nav className="flex flex-wrap gap-2 border-b" data-testid="hub-status-tabs">
        {tabs.map((t) => (
          <a
            key={t.key}
            href={`?status=${t.key}`}
            data-testid={`tab-${t.key}`}
            className={`-mb-px border-b-2 px-3 py-2 text-sm font-medium ${
              filter === t.key
                ? "border-primary text-primary"
                : "border-transparent text-gray-500 hover:text-foreground"
            }`}
          >
            {t.label}
          </a>
        ))}
      </nav>

      <HubInventoryTable rows={filtered} />
    </div>
  );
}
