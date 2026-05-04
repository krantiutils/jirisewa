import { setRequestLocale } from "next-intl/server";
import {
  listOriginHubs,
  listMyDropoffs,
  listFarmerActiveListings,
} from "@/lib/actions/hubs";
import { DropoffForm } from "./_DropoffForm";
import { Building2 } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function FarmerHubsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const [hubs, listings, dropoffs] = await Promise.all([
    listOriginHubs(),
    listFarmerActiveListings(),
    listMyDropoffs(),
  ]);

  return (
    <div className="container mx-auto max-w-3xl px-4 py-6 space-y-8">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold">
          <Building2 className="h-6 w-6" />
          Drop off at a hub
        </h1>
        <p className="text-sm text-gray-600">
          Drop your produce at a hub. The hub operator will confirm receipt and a
          rider will pick it up — you don&apos;t need to wait at your farm.
        </p>
      </div>

      <DropoffForm hubs={hubs} listings={listings} />

      <section data-testid="my-dropoffs">
        <h2 className="mb-2 text-lg font-semibold">Your recent dropoffs</h2>
        {dropoffs.length === 0 ? (
          <p className="text-sm text-gray-500">No dropoffs yet.</p>
        ) : (
          <div className="overflow-x-auto rounded-md border">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr className="text-left">
                  <th className="px-3 py-2">Lot</th>
                  <th className="px-3 py-2">Listing</th>
                  <th className="px-3 py-2">Hub</th>
                  <th className="px-3 py-2">Qty (kg)</th>
                  <th className="px-3 py-2">Status</th>
                  <th className="px-3 py-2">Dropped</th>
                </tr>
              </thead>
              <tbody>
                {dropoffs.map((d) => (
                  <tr key={d.id} className="border-t" data-testid={`dropoff-row-${d.id}`}>
                    <td className="px-3 py-2 font-mono">{d.lot_code}</td>
                    <td className="px-3 py-2">{d.listing_name}</td>
                    <td className="px-3 py-2">{d.hub_name}</td>
                    <td className="px-3 py-2">{d.quantity_kg}</td>
                    <td className="px-3 py-2">{d.status}</td>
                    <td className="px-3 py-2">
                      {new Date(d.dropped_at).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
