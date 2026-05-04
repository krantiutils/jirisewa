import { setRequestLocale } from "next-intl/server";
import { getMyOperatedHub, listHubInventory } from "@/lib/actions/hubs";
import { Inbox } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function HubDropoffsPage({
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
        You are not assigned as the operator of any active hub.
      </div>
    );
  }

  const all = await listHubInventory(hub.id);
  // Chronological: most-recent dropoffs first
  const rows = [...all].sort(
    (a, b) => new Date(b.dropped_at).getTime() - new Date(a.dropped_at).getTime(),
  );

  return (
    <div className="space-y-4">
      <h1 className="flex items-center gap-2 text-2xl font-bold">
        <Inbox className="h-6 w-6" />
        Drop-offs
      </h1>
      <p className="text-sm text-gray-500">
        Chronological log of every farmer drop-off at this hub.
      </p>

      <div className="overflow-hidden rounded-xl border border-gray-200 bg-white">
        <table className="min-w-full divide-y divide-gray-200 text-sm">
          <thead className="bg-gray-50">
            <tr className="text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
              <th className="px-4 py-3">When</th>
              <th className="px-4 py-3">Lot</th>
              <th className="px-4 py-3">Farmer</th>
              <th className="px-4 py-3">Listing</th>
              <th className="px-4 py-3 text-right">Qty (kg)</th>
              <th className="px-4 py-3">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {rows.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-gray-500">
                  No drop-offs yet.
                </td>
              </tr>
            ) : (
              rows.map((d) => (
                <tr key={d.id}>
                  <td className="px-4 py-3 text-gray-600">
                    {new Date(d.dropped_at).toLocaleString()}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">{d.lot_code}</td>
                  <td className="px-4 py-3">{d.farmer_name}</td>
                  <td className="px-4 py-3">{d.listing_name}</td>
                  <td className="px-4 py-3 text-right font-medium">{d.quantity_kg}</td>
                  <td className="px-4 py-3">
                    <span className="inline-flex rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700">
                      {d.status}
                    </span>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
