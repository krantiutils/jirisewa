"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { useTranslations } from "next-intl";
import { MapPin, Plus, Pencil, Trash2, Loader2, Star } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import {
  listAddresses,
  createAddress,
  updateAddress,
  deleteAddress,
} from "@/lib/actions/addresses";
import type { SavedAddress } from "@/lib/actions/addresses";
import type { Locale } from "@/lib/i18n";
import type { LatLng } from "@/lib/map";

const LocationPicker = dynamic(
  () => import("@/components/map/LocationPicker"),
  { ssr: false },
);

interface AddressFormState {
  label: string;
  location: LatLng | null;
  addressText: string;
  isDefault: boolean;
}

const emptyForm: AddressFormState = {
  label: "",
  location: null,
  addressText: "",
  isDefault: false,
};

export default function SavedAddressesPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("addresses");
  const { user, loading: authLoading } = useAuth();

  const [addresses, setAddresses] = useState<SavedAddress[]>([]);
  const [loading, setLoading] = useState(true);

  // Form state
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<AddressFormState>(emptyForm);
  const [saving, setSaving] = useState(false);

  // Auth guard
  useEffect(() => {
    if (!authLoading && !user) {
      router.replace(`/${locale}/auth/login`);
    }
  }, [authLoading, user, router, locale]);

  // Load addresses
  useEffect(() => {
    if (authLoading || !user) return;
    async function load() {
      const result = await listAddresses();
      setAddresses(result.data ?? []);
      setLoading(false);
    }
    load();
  }, [authLoading, user]);

  const handleLocationChange = (location: LatLng, address: string) => {
    setForm((prev) => ({ ...prev, location, addressText: address }));
  };

  const handleSave = async () => {
    if (!form.label.trim() || !form.location) return;
    setSaving(true);

    if (editingId) {
      await updateAddress(editingId, {
        label: form.label,
        addressText: form.addressText,
        lat: form.location.lat,
        lng: form.location.lng,
        isDefault: form.isDefault,
      });
    } else {
      await createAddress({
        label: form.label,
        addressText: form.addressText,
        lat: form.location.lat,
        lng: form.location.lng,
        isDefault: form.isDefault,
      });
    }

    // Reload
    const result = await listAddresses();
    setAddresses(result.data ?? []);
    setSaving(false);
    resetForm();
  };

  const handleEdit = (addr: SavedAddress) => {
    setEditingId(addr.id);
    setForm({
      label: addr.label,
      location: { lat: addr.lat, lng: addr.lng },
      addressText: addr.addressText,
      isDefault: addr.isDefault,
    });
    setShowForm(true);
  };

  const handleDelete = async (id: string) => {
    if (!confirm(t("deleteConfirm"))) return;
    await deleteAddress(id);
    const result = await listAddresses();
    setAddresses(result.data ?? []);
  };

  const resetForm = () => {
    setShowForm(false);
    setEditingId(null);
    setForm(emptyForm);
  };

  if (authLoading || !user) return null;

  if (loading) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
              <MapPin className="h-6 w-6 text-primary" />
            </div>
            <h1 className="text-2xl font-bold text-foreground">
              {t("title")}
            </h1>
          </div>
          {!showForm && (
            <Button
              onClick={() => {
                resetForm();
                setShowForm(true);
              }}
              className="gap-2 h-10 px-4 text-sm"
            >
              <Plus className="h-4 w-4" />
              {t("addNew")}
            </Button>
          )}
        </div>

        {/* Add / Edit form */}
        {showForm && (
          <Card className="mb-6 cursor-default hover:scale-100">
            <h2 className="text-lg font-semibold text-foreground mb-4">
              {editingId ? t("edit") : t("addNew")}
            </h2>

            {/* Label input */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {t("label")}
              </label>
              <input
                type="text"
                value={form.label}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, label: e.target.value }))
                }
                placeholder={t("labelPlaceholder")}
                className="w-full rounded-lg border-2 border-gray-200 px-4 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
              />
            </div>

            {/* Location picker */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {t("address")}
              </label>
              <LocationPicker
                value={form.location}
                onChange={handleLocationChange}
                className="h-[300px] rounded-lg overflow-hidden"
              />
            </div>

            {/* Default checkbox */}
            <div className="mb-4">
              <label className="flex items-center gap-2 text-sm text-gray-700">
                <input
                  type="checkbox"
                  checked={form.isDefault}
                  onChange={(e) =>
                    setForm((prev) => ({
                      ...prev,
                      isDefault: e.target.checked,
                    }))
                  }
                  className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                />
                {t("setDefault")}
              </label>
            </div>

            {/* Actions */}
            <div className="flex gap-3">
              <Button
                onClick={handleSave}
                disabled={saving || !form.label.trim() || !form.location}
                className="h-10 px-6 text-sm"
              >
                {saving ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    {t("saving")}
                  </>
                ) : (
                  t("save")
                )}
              </Button>
              <Button
                variant="secondary"
                onClick={resetForm}
                className="h-10 px-6 text-sm"
              >
                {t("cancel")}
              </Button>
            </div>
          </Card>
        )}

        {/* Address list */}
        {addresses.length === 0 ? (
          <div className="rounded-lg bg-white p-12 text-center">
            <MapPin className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-4 text-gray-500">{t("empty")}</p>
            <p className="mt-1 text-sm text-gray-400">{t("emptyHint")}</p>
          </div>
        ) : (
          <div className="space-y-3">
            {addresses.map((addr) => (
              <Card
                key={addr.id}
                className="cursor-default hover:scale-100 flex items-center justify-between gap-4 p-4"
              >
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="font-semibold text-foreground">
                      {addr.label}
                    </p>
                    {addr.isDefault && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-primary">
                        <Star className="h-3 w-3 fill-current" />
                        {t("default")}
                      </span>
                    )}
                  </div>
                  <p className="mt-0.5 text-sm text-gray-500 truncate">
                    {addr.addressText || `${addr.lat.toFixed(4)}, ${addr.lng.toFixed(4)}`}
                  </p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button
                    onClick={() => handleEdit(addr)}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-md text-gray-400 hover:bg-gray-100 hover:text-primary transition-colors"
                    aria-label={t("edit")}
                  >
                    <Pencil className="h-4 w-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(addr.id)}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-md text-gray-400 hover:bg-red-50 hover:text-red-500 transition-colors"
                    aria-label={t("delete")}
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
