"use client";

import { useState, useEffect } from "react";
import { useTranslations } from "next-intl";
import {
  getNotificationPreferences,
  updateNotificationPreference,
} from "@/lib/actions/notifications";

interface Preference {
  category: string;
  enabled: boolean;
}

export function NotificationPreferences() {
  const t = useTranslations("notifications.preferences");
  const [preferences, setPreferences] = useState<Preference[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      const result = await getNotificationPreferences();
      if (result.data) {
        setPreferences(result.data);
      }
      setLoading(false);
    }
    load();
  }, []);

  const handleToggle = async (category: string, enabled: boolean) => {
    setSaving(category);
    const result = await updateNotificationPreference(category, enabled);
    if (!result.error) {
      setPreferences((prev) =>
        prev.map((p) => (p.category === category ? { ...p, enabled } : p)),
      );
    }
    setSaving(null);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="h-5 w-5 animate-spin rounded-full border-2 border-gray-300 border-t-primary" />
      </div>
    );
  }

  // Group categories by user role relevance
  const consumerCategories = [
    "order_matched",
    "rider_picked_up",
    "rider_arriving",
    "order_delivered",
  ];
  const farmerCategories = [
    "new_order_for_farmer",
    "rider_arriving_for_pickup",
  ];
  const riderCategories = [
    "new_order_match",
    "trip_reminder",
    "delivery_confirmed",
  ];

  const renderGroup = (
    groupTitle: string,
    categories: string[],
  ) => {
    const groupPrefs = preferences.filter((p) =>
      categories.includes(p.category),
    );
    if (groupPrefs.length === 0) return null;

    return (
      <div className="mb-6">
        <h3 className="mb-3 text-sm font-semibold text-gray-700">
          {groupTitle}
        </h3>
        <div className="space-y-3">
          {groupPrefs.map((pref) => (
            <label
              key={pref.category}
              className="flex items-center justify-between rounded-lg border border-gray-200 px-4 py-3"
            >
              <div>
                <p className="text-sm font-medium text-gray-900">
                  {t(`categories.${pref.category}.title`)}
                </p>
                <p className="text-xs text-gray-500">
                  {t(`categories.${pref.category}.description`)}
                </p>
              </div>
              <button
                onClick={() => handleToggle(pref.category, !pref.enabled)}
                disabled={saving === pref.category}
                className={`relative h-6 w-11 rounded-full transition-colors ${
                  pref.enabled ? "bg-primary" : "bg-gray-300"
                } ${saving === pref.category ? "opacity-50" : ""}`}
                role="switch"
                aria-checked={pref.enabled}
              >
                <span
                  className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform ${
                    pref.enabled ? "translate-x-5" : "translate-x-0.5"
                  }`}
                />
              </button>
            </label>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div>
      <h2 className="mb-4 text-lg font-semibold text-gray-900">
        {t("title")}
      </h2>
      {renderGroup(t("consumerGroup"), consumerCategories)}
      {renderGroup(t("farmerGroup"), farmerCategories)}
      {renderGroup(t("riderGroup"), riderCategories)}
    </div>
  );
}
