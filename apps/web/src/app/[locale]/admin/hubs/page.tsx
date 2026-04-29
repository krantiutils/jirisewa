import { setRequestLocale } from "next-intl/server";
import Link from "next/link";
import { listHubs } from "@/lib/admin/hubs";
import { Badge } from "@/components/ui";
import { Building2, Plus } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function AdminHubsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const hubs = await listHubs(locale);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold">
            <Building2 className="h-6 w-6" />
            Pickup Hubs
          </h1>
          <p className="text-sm text-gray-500">{hubs.length} hubs</p>
        </div>
        <Link
          href={`/${locale}/admin/hubs/new`}
          className="inline-flex items-center gap-1 rounded-md bg-primary px-3 py-2 text-sm font-medium text-white hover:bg-primary/90"
          data-testid="new-hub-link"
        >
          <Plus className="h-4 w-4" />
          New Hub
        </Link>
      </div>

      <div className="overflow-x-auto rounded-md border">
        <table className="w-full text-sm" data-testid="hubs-table">
          <thead className="bg-gray-50">
            <tr className="text-left">
              <th className="px-4 py-2">Name</th>
              <th className="px-4 py-2">Type</th>
              <th className="px-4 py-2">Municipality</th>
              <th className="px-4 py-2">Operator</th>
              <th className="px-4 py-2">Status</th>
              <th className="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody>
            {hubs.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-gray-500">
                  No hubs yet.
                </td>
              </tr>
            )}
            {hubs.map((h) => (
              <tr key={h.id} className="border-t" data-testid={`hub-row-${h.id}`}>
                <td className="px-4 py-2 font-medium">
                  {h.name_en}
                  <div className="text-xs text-gray-500">{h.address}</div>
                </td>
                <td className="px-4 py-2">
                  <Badge>{h.hub_type}</Badge>
                </td>
                <td className="px-4 py-2">{h.municipality_name ?? "—"}</td>
                <td className="px-4 py-2">{h.operator_name ?? <span className="text-gray-400">unassigned</span>}</td>
                <td className="px-4 py-2">
                  {h.is_active ? (
                    <Badge>active</Badge>
                  ) : (
                    <span className="text-gray-400">disabled</span>
                  )}
                </td>
                <td className="px-4 py-2 text-right">
                  <Link
                    href={`/${locale}/admin/hubs/${h.id}`}
                    className="text-sm text-primary hover:underline"
                  >
                    Edit
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
