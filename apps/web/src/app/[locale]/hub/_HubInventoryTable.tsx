"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  markDropoffReceived,
  markDropoffSpoiled,
  type DropoffRow,
} from "@/lib/actions/hubs";

interface Props {
  rows: DropoffRow[];
}

export function HubInventoryTable({ rows }: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function handleAction(fn: () => Promise<{ success: boolean; error?: string }>) {
    setError(null);
    startTransition(async () => {
      const res = await fn();
      if (!res.success) {
        setError(res.error ?? "Action failed");
        return;
      }
      router.refresh();
    });
  }

  if (rows.length === 0) {
    return (
      <div className="rounded-md border p-6 text-center text-sm text-gray-500" data-testid="empty">
        No dropoffs in this state.
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {error && (
        <div role="alert" className="rounded bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      )}
      <div className="overflow-x-auto rounded-md border">
        <table className="w-full text-sm" data-testid="inventory-table">
          <thead className="bg-gray-50">
            <tr className="text-left">
              <th className="px-3 py-2">Lot</th>
              <th className="px-3 py-2">Listing</th>
              <th className="px-3 py-2">Farmer</th>
              <th className="px-3 py-2">Qty (kg)</th>
              <th className="px-3 py-2">Status</th>
              <th className="px-3 py-2">Dropped</th>
              <th className="px-3 py-2">Expires</th>
              <th className="px-3 py-2"></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} className="border-t" data-testid={`inventory-row-${r.id}`}>
                <td className="px-3 py-2 font-mono">{r.lot_code}</td>
                <td className="px-3 py-2">{r.listing_name}</td>
                <td className="px-3 py-2">{r.farmer_name}</td>
                <td className="px-3 py-2">{r.quantity_kg}</td>
                <td className="px-3 py-2">{r.status}</td>
                <td className="px-3 py-2">{new Date(r.dropped_at).toLocaleString()}</td>
                <td className="px-3 py-2">{new Date(r.expires_at).toLocaleString()}</td>
                <td className="px-3 py-2 text-right space-x-2">
                  {r.status === "dropped_off" && (
                    <button
                      type="button"
                      data-testid={`receive-${r.id}`}
                      onClick={() => handleAction(() => markDropoffReceived(r.id))}
                      disabled={pending}
                      className="rounded bg-primary px-3 py-1 text-xs text-white"
                    >
                      Mark received
                    </button>
                  )}
                  {(r.status === "dropped_off" || r.status === "in_inventory") && (
                    <button
                      type="button"
                      data-testid={`spoil-${r.id}`}
                      onClick={() => handleAction(() => markDropoffSpoiled(r.id))}
                      disabled={pending}
                      className="rounded border px-3 py-1 text-xs"
                    >
                      Spoiled
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
