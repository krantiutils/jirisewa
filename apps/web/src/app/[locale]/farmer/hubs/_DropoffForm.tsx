"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { recordHubDropoff } from "@/lib/actions/hubs";

interface Props {
  hubs: { id: string; name_en: string; address: string }[];
  listings: { id: string; name_en: string }[];
}

export function DropoffForm({ hubs, listings }: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [hubId, setHubId] = useState(hubs[0]?.id ?? "");
  const [listingId, setListingId] = useState(listings[0]?.id ?? "");
  const [qty, setQty] = useState("5");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<{
    lot_code: string;
    expires_at: string;
  } | null>(null);

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    const q = parseFloat(qty);
    if (!hubId || !listingId || isNaN(q) || q <= 0) {
      setError("Please fill in all fields with valid values.");
      return;
    }
    startTransition(async () => {
      const res = await recordHubDropoff({
        hub_id: hubId,
        listing_id: listingId,
        quantity_kg: q,
      });
      if (!res.success) {
        setError(res.error);
        return;
      }
      setSuccess({ lot_code: res.data.lot_code, expires_at: res.data.expires_at });
      setQty("5");
      router.refresh();
    });
  }

  if (hubs.length === 0) {
    return (
      <div className="rounded-md bg-yellow-50 p-3 text-sm text-yellow-800">
        No active origin hubs available right now.
      </div>
    );
  }
  if (listings.length === 0) {
    return (
      <div className="rounded-md bg-yellow-50 p-3 text-sm text-yellow-800">
        Create an active listing first, then drop off at a hub.
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="space-y-4 rounded-md border p-4" data-testid="dropoff-form">
      <div>
        <label className="mb-1 block text-sm font-medium">Hub</label>
        <select
          data-testid="dropoff-hub"
          value={hubId}
          onChange={(e) => setHubId(e.target.value)}
          className="w-full rounded border px-3 py-2"
        >
          {hubs.map((h) => (
            <option key={h.id} value={h.id}>
              {h.name_en} — {h.address}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label className="mb-1 block text-sm font-medium">Listing</label>
        <select
          data-testid="dropoff-listing"
          value={listingId}
          onChange={(e) => setListingId(e.target.value)}
          className="w-full rounded border px-3 py-2"
        >
          {listings.map((l) => (
            <option key={l.id} value={l.id}>
              {l.name_en}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label className="mb-1 block text-sm font-medium">Quantity (kg)</label>
        <input
          data-testid="dropoff-qty"
          type="number"
          min="0.1"
          step="0.1"
          value={qty}
          onChange={(e) => setQty(e.target.value)}
          className="w-full rounded border px-3 py-2"
          required
        />
      </div>
      {error && (
        <div role="alert" className="rounded bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      )}
      {success && (
        <div
          role="status"
          data-testid="dropoff-success"
          className="rounded bg-green-50 px-3 py-2 text-sm text-green-800"
        >
          Lot code <span className="font-mono font-bold">{success.lot_code}</span> —
          expires {new Date(success.expires_at).toLocaleString()}.
        </div>
      )}
      <button
        type="submit"
        disabled={pending}
        data-testid="dropoff-submit"
        className="rounded bg-primary px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {pending ? "Recording…" : "Record dropoff"}
      </button>
    </form>
  );
}
