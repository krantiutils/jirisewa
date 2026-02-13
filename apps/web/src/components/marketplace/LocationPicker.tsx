"use client";

import { useState, useCallback } from "react";
import { MapPin, Loader2, Check } from "lucide-react";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ui";

interface LocationPickerProps {
  onLocationChange: (lat: number, lng: number) => void;
  currentLocation: { lat: number; lng: number } | null;
}

export function LocationPicker({ onLocationChange, currentLocation }: LocationPickerProps) {
  const t = useTranslations("marketplace");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const requestGeolocation = useCallback(() => {
    if (!navigator.geolocation) {
      setError("Geolocation is not supported by your browser");
      return;
    }

    setLoading(true);
    setError(null);

    navigator.geolocation.getCurrentPosition(
      (position) => {
        onLocationChange(position.coords.latitude, position.coords.longitude);
        setLoading(false);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      },
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 },
    );
  }, [onLocationChange]);

  if (currentLocation) {
    return (
      <div className="flex items-center gap-2 rounded-md bg-emerald-50 px-3 py-2 text-sm">
        <Check className="h-4 w-4 text-emerald-600" />
        <span className="font-medium text-emerald-700">{t("locationSet")}</span>
        <button
          onClick={requestGeolocation}
          className="ml-auto text-xs text-emerald-600 underline hover:text-emerald-800"
        >
          {t("useMyLocation")}
        </button>
      </div>
    );
  }

  return (
    <div className="rounded-lg border-2 border-dashed border-gray-300 p-4">
      <div className="flex flex-col items-center gap-2 text-center">
        <MapPin className="h-8 w-8 text-gray-400" />
        <p className="text-sm font-medium text-gray-600">{t("setLocation")}</p>
        <p className="text-xs text-gray-500">{t("setLocationHint")}</p>
        <Button
          variant="primary"
          onClick={requestGeolocation}
          disabled={loading}
          className="mt-2 h-10 px-4 text-sm"
        >
          {loading ? (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          ) : (
            <MapPin className="mr-2 h-4 w-4" />
          )}
          {t("useMyLocation")}
        </Button>
        {error && <p className="text-xs text-red-500">{error}</p>}
      </div>
    </div>
  );
}
