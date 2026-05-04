"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import type { HubRow, HubType, HubUpsertInput } from "@/lib/admin/hubs";

interface Props {
  locale: string;
  initial?: HubRow;
  operators: { id: string; name: string }[];
  municipalities: { id: string; name: string }[];
  action: (locale: string, input: HubUpsertInput) => Promise<{ id?: string; ok?: true; error?: string }>;
  updateAction?: (
    locale: string,
    id: string,
    input: HubUpsertInput,
  ) => Promise<{ ok?: true; error?: string }>;
  disableAction?: (locale: string, id: string) => Promise<{ ok?: true; error?: string }>;
}

export function HubForm({
  locale,
  initial,
  operators,
  municipalities,
  action,
  updateAction,
  disableAction,
}: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [nameEn, setNameEn] = useState(initial?.name_en ?? "");
  const [nameNe, setNameNe] = useState(initial?.name_ne ?? "");
  const [address, setAddress] = useState(initial?.address ?? "");
  const [hubType, setHubType] = useState<HubType>(initial?.hub_type ?? "origin");
  const [lat, setLat] = useState(initial?.lat ? String(initial.lat) : "27.6298");
  const [lng, setLng] = useState(initial?.lng ? String(initial.lng) : "86.2310");
  const [operatorId, setOperatorId] = useState(initial?.operator_id ?? "");
  const [municipalityId, setMunicipalityId] = useState(initial?.municipality_id ?? "");
  const [isActive, setIsActive] = useState(initial?.is_active ?? true);

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const input: HubUpsertInput = {
      name_en: nameEn,
      name_ne: nameNe,
      address,
      hub_type: hubType,
      lat: parseFloat(lat),
      lng: parseFloat(lng),
      operator_id: operatorId || null,
      municipality_id: municipalityId || null,
      is_active: isActive,
    };

    startTransition(async () => {
      let res: { id?: string; ok?: true; error?: string };
      if (initial && updateAction) {
        res = await updateAction(locale, initial.id, input);
      } else {
        res = await action(locale, input);
      }
      if (res.error) {
        setError(res.error);
        return;
      }
      router.push(`/${locale}/admin/hubs`);
      router.refresh();
    });
  }

  return (
    <form onSubmit={submit} className="space-y-4 max-w-2xl" data-testid="hub-form">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Name (EN)" required>
          <input
            data-testid="hub-name-en"
            value={nameEn}
            onChange={(e) => setNameEn(e.target.value)}
            required
            className="w-full rounded border px-3 py-2"
          />
        </Field>
        <Field label="Name (NE)" required>
          <input
            data-testid="hub-name-ne"
            value={nameNe}
            onChange={(e) => setNameNe(e.target.value)}
            required
            className="w-full rounded border px-3 py-2"
          />
        </Field>
      </div>

      <Field label="Address" required>
        <input
          data-testid="hub-address"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          required
          className="w-full rounded border px-3 py-2"
        />
      </Field>

      <div className="grid grid-cols-3 gap-4">
        <Field label="Hub type">
          <select
            data-testid="hub-type"
            value={hubType}
            onChange={(e) => setHubType(e.target.value as HubType)}
            className="w-full rounded border px-3 py-2"
          >
            <option value="origin">Origin</option>
            <option value="destination">Destination</option>
            <option value="transit">Transit</option>
          </select>
        </Field>
        <Field label="Latitude">
          <input
            data-testid="hub-lat"
            type="number"
            step="0.000001"
            value={lat}
            onChange={(e) => setLat(e.target.value)}
            required
            className="w-full rounded border px-3 py-2"
          />
        </Field>
        <Field label="Longitude">
          <input
            data-testid="hub-lng"
            type="number"
            step="0.000001"
            value={lng}
            onChange={(e) => setLng(e.target.value)}
            required
            className="w-full rounded border px-3 py-2"
          />
        </Field>
      </div>

      <Field label="Municipality">
        <select
          data-testid="hub-municipality"
          value={municipalityId}
          onChange={(e) => setMunicipalityId(e.target.value)}
          className="w-full rounded border px-3 py-2"
        >
          <option value="">— None —</option>
          {municipalities.map((m) => (
            <option key={m.id} value={m.id}>
              {m.name}
            </option>
          ))}
        </select>
      </Field>

      <Field label="Operator">
        <select
          data-testid="hub-operator"
          value={operatorId}
          onChange={(e) => setOperatorId(e.target.value)}
          className="w-full rounded border px-3 py-2"
        >
          <option value="">— Unassigned —</option>
          {operators.map((o) => (
            <option key={o.id} value={o.id}>
              {o.name}
            </option>
          ))}
        </select>
      </Field>

      <label className="flex items-center gap-2">
        <input
          data-testid="hub-active"
          type="checkbox"
          checked={isActive}
          onChange={(e) => setIsActive(e.target.checked)}
        />
        <span>Active</span>
      </label>

      {error && (
        <div role="alert" className="rounded bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="flex items-center gap-2">
        <button
          type="submit"
          disabled={pending}
          data-testid="hub-submit"
          className="rounded bg-primary px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
        >
          {pending ? "Saving…" : initial ? "Save" : "Create hub"}
        </button>
        {initial && disableAction && initial.is_active && (
          <button
            type="button"
            data-testid="hub-disable"
            onClick={() => {
              startTransition(async () => {
                const res = await disableAction(locale, initial.id);
                if (res.error) setError(res.error);
                else {
                  router.push(`/${locale}/admin/hubs`);
                  router.refresh();
                }
              });
            }}
            className="rounded border px-4 py-2 text-sm"
          >
            Disable
          </button>
        )}
      </div>
    </form>
  );
}

function Field({
  label,
  children,
  required,
}: {
  label: string;
  children: React.ReactNode;
  required?: boolean;
}) {
  return (
    <label className="block space-y-1">
      <span className="text-sm font-medium">
        {label}
        {required && <span className="text-red-500"> *</span>}
      </span>
      {children}
    </label>
  );
}
