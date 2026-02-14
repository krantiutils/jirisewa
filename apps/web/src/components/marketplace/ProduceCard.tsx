import Image from "next/image";
import { Link } from "@/i18n/navigation";
import { useLocale, useTranslations } from "next-intl";
import { Star, MapPin, ShieldCheck } from "lucide-react";
import { Badge } from "@/components/ui";
import type { ProduceListingWithDetails } from "@/lib/supabase/types";
import type { Locale } from "@/lib/i18n";

interface ProduceCardProps {
  listing: ProduceListingWithDetails;
}

export function ProduceCard({ listing }: ProduceCardProps) {
  const locale = useLocale() as Locale;
  const t = useTranslations("marketplace");

  const name = locale === "ne" ? listing.name_ne : listing.name_en;
  const categoryName =
    locale === "ne" ? listing.category.name_ne : listing.category.name_en;
  const photo = listing.photos?.[0];

  return (
    <Link
      href={`/produce/${listing.id}`}
      className="group block rounded-lg bg-white transition-all duration-200 hover:scale-[1.02]"
    >
      {/* Photo */}
      <div className="relative aspect-[4/3] overflow-hidden rounded-t-lg bg-muted">
        {photo ? (
          <Image
            src={photo}
            alt={name}
            fill
            sizes="(max-width: 640px) 100vw, (max-width: 1280px) 50vw, 33vw"
            className="object-cover transition-transform duration-300 group-hover:scale-105"
            unoptimized
          />
        ) : (
          <div className="flex h-full items-center justify-center text-4xl text-gray-300">
            🌿
          </div>
        )}
        <Badge color="secondary" className="absolute left-3 top-3">
          {categoryName}
        </Badge>
      </div>

      {/* Details */}
      <div className="p-4">
        {/* Name and price */}
        <div className="flex items-start justify-between gap-2">
          <h3 className="text-lg font-bold leading-tight text-foreground">{name}</h3>
          <span className="shrink-0 text-lg font-extrabold text-primary">
            रु {listing.price_per_kg}
            <span className="text-sm font-medium text-gray-500">{t("perKg")}</span>
          </span>
        </div>

        {/* Farmer info */}
        <div className="mt-2 flex items-center gap-2 text-sm text-gray-600">
          <span className="font-medium">{listing.farmer.name}</span>
          {listing.farmer_verified && (
            <span className="inline-flex items-center gap-0.5 text-emerald-600" title={t("verifiedFarmer")}>
              <ShieldCheck className="h-3.5 w-3.5" />
              <span className="text-xs font-medium">{t("verifiedFarmer")}</span>
            </span>
          )}
          {listing.farmer.rating_avg > 0 && (
            <span className="flex items-center gap-0.5">
              <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" />
              <span>
                {Number(listing.farmer.rating_avg).toFixed(1)}
              </span>
            </span>
          )}
        </div>

        {/* Distance and freshness */}
        <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-gray-500">
          {listing.distance_km != null && (
            <span className="flex items-center gap-1">
              <MapPin className="h-3 w-3" />
              {t("kmAway", { distance: listing.distance_km })}
            </span>
          )}
          {listing.freshness_date && (
            <span>
              {t("harvestedOn", {
                date: new Date(listing.freshness_date).toLocaleDateString(
                  locale === "ne" ? "ne-NP" : "en-US",
                  { month: "short", day: "numeric" },
                ),
              })}
            </span>
          )}
          <span>{t("available", { qty: listing.available_qty_kg })}</span>
        </div>
      </div>
    </Link>
  );
}
