import { setRequestLocale } from "next-intl/server";
import { getMyOperatedHub, listHubInventory } from "@/lib/actions/hubs";
import { Building2, Package, Inbox, Truck, AlertTriangle, Trash2 } from "lucide-react";

export const dynamic = "force-dynamic";

interface StatCardProps {
  label: string;
  value: number | string;
  icon: typeof Package;
  color: string;
}

function StatCard({ label, value, icon: Icon, color }: StatCardProps) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-5">
      <div className="flex items-center gap-3">
        <div className={`flex h-10 w-10 items-center justify-center rounded-lg ${color}`}>
          <Icon className="h-5 w-5 text-white" />
        </div>
        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-gray-500">{label}</p>
          <p className="text-2xl font-bold text-foreground">{value}</p>
        </div>
      </div>
    </div>
  );
}

export default async function HubDashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const hub = await getMyOperatedHub();
  if (!hub) {
    return (
      <div className="rounded-md bg-yellow-50 p-4 text-sm text-yellow-800">
        You are not assigned as the operator of any active hub. Ask an admin
        to assign you at <code>/{locale}/admin/hubs</code>.
      </div>
    );
  }

  const all = await listHubInventory(hub.id);
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const weekStart = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const droppedToday = all.filter(
    (d) => new Date(d.dropped_at) >= todayStart,
  ).length;
  const inInventory = all.filter((d) => d.status === "in_inventory");
  const dispatchedThisWeek = all.filter(
    (d) => d.status === "dispatched" && d.dispatched_at && new Date(d.dispatched_at) >= weekStart,
  ).length;
  const spoiledThisWeek = all.filter(
    (d) => d.status === "spoiled" && new Date(d.dropped_at) >= weekStart,
  ).length;

  const totalKgInInventory = inInventory.reduce(
    (sum, d) => sum + Number(d.quantity_kg),
    0,
  );

  // Recent activity — last 8 changes by most-recent timestamp
  const activity = [...all]
    .sort((a, b) => {
      const aT = new Date(a.dispatched_at ?? a.received_at ?? a.dropped_at).getTime();
      const bT = new Date(b.dispatched_at ?? b.received_at ?? b.dropped_at).getTime();
      return bT - aT;
    })
    .slice(0, 8);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold">
          <Building2 className="h-6 w-6" />
          {hub.name_en}
        </h1>
        <p className="text-sm text-gray-500">{hub.address}</p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          label="Drop-offs today"
          value={droppedToday}
          icon={Inbox}
          color="bg-blue-500"
        />
        <StatCard
          label="In inventory"
          value={`${inInventory.length} (${totalKgInInventory.toFixed(0)} kg)`}
          icon={Package}
          color="bg-emerald-500"
        />
        <StatCard
          label="Dispatched (7d)"
          value={dispatchedThisWeek}
          icon={Truck}
          color="bg-amber-500"
        />
        <StatCard
          label="Spoiled (7d)"
          value={spoiledThisWeek}
          icon={Trash2}
          color="bg-red-500"
        />
      </div>

      <div className="rounded-xl border border-gray-200 bg-white">
        <div className="border-b border-gray-100 px-5 py-3">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            Recent activity
          </h2>
        </div>
        {activity.length === 0 ? (
          <div className="px-5 py-6 text-sm text-gray-500">No activity yet.</div>
        ) : (
          <ul className="divide-y divide-gray-100">
            {activity.map((d) => {
              const ts =
                d.dispatched_at ?? d.received_at ?? d.dropped_at;
              const verb =
                d.status === "dispatched"
                  ? "Dispatched"
                  : d.status === "in_inventory"
                  ? "Received"
                  : d.status === "spoiled"
                  ? "Spoiled"
                  : d.status === "expired"
                  ? "Expired"
                  : "Dropped off";
              const Icon =
                d.status === "spoiled" || d.status === "expired"
                  ? AlertTriangle
                  : d.status === "dispatched"
                  ? Truck
                  : d.status === "in_inventory"
                  ? Package
                  : Inbox;
              return (
                <li key={d.id} className="flex items-start gap-3 px-5 py-3">
                  <Icon className="mt-0.5 h-4 w-4 shrink-0 text-gray-400" />
                  <div className="flex-1 text-sm">
                    <span className="font-medium">{verb}</span>{" "}
                    <span className="text-gray-700">
                      {d.quantity_kg} kg {d.listing_name}
                    </span>{" "}
                    <span className="text-gray-500">
                      ({d.lot_code}) — {d.farmer_name}
                    </span>
                  </div>
                  <span className="text-xs text-gray-500">
                    {new Date(ts).toLocaleString()}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}
