"use client";

import { useState } from "react";
import Image from "next/image";
import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { Badge } from "@/components/ui";
import { Pencil, ToggleLeft, ToggleRight, Package } from "lucide-react";
import { toggleListingActive } from "../actions";
import type { ListingWithCategory } from "../actions";
import type { Locale } from "@/lib/i18n";

interface ListingCardProps {
  listing: ListingWithCategory;
}

export function ListingCard({ listing }: ListingCardProps) {
  const locale = useLocale() as Locale;
  const t = useTranslations("farmer");
  const [toggling, setToggling] = useState(false);

  const name = locale === "ne" ? listing.name_ne : listing.name_en;
  const categoryName = listing.produce_categories
    ? locale === "ne"
      ? listing.produce_categories.name_ne
      : listing.produce_categories.name_en
    : "";

  async function handleToggle() {
    setToggling(true);
    await toggleListingActive(listing.id, !listing.is_active);
    setToggling(false);
  }

  const photo = listing.photos.length > 0 ? listing.photos[0] : null;

  return (
    <div className="flex gap-4 rounded-lg bg-white p-4 transition-all duration-200 hover:scale-[1.01]">
      {/* Thumbnail */}
      <div className="h-20 w-20 flex-shrink-0 overflow-hidden rounded-lg bg-muted">
        {photo ? (
          <Image
            src={photo}
            alt={name}
            width={80}
            height={80}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <Package className="h-8 w-8 text-gray-300" />
          </div>
        )}
      </div>

      {/* Details */}
      <div className="flex flex-1 flex-col justify-between">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="font-semibold text-foreground">{name}</h3>
            <Badge color={listing.is_active ? "secondary" : "accent"}>
              {listing.is_active ? t("listing.active") : t("listing.inactive")}
            </Badge>
          </div>
          <p className="text-sm text-gray-500">
            {listing.produce_categories?.icon} {categoryName}
          </p>
        </div>
        <div className="flex items-center gap-4 text-sm">
          <span className="font-medium text-primary">
            NPR {listing.price_per_kg}/kg
          </span>
          <span className="text-gray-500">
            {listing.available_qty_kg} kg {t("listing.available")}
          </span>
        </div>
      </div>

      {/* Actions */}
      <div className="flex flex-shrink-0 flex-col gap-2">
        <Link
          href={`/farmer/listings/${listing.id}/edit`}
          className="inline-flex h-10 w-10 items-center justify-center rounded-md bg-muted text-foreground transition-colors hover:bg-gray-200"
          aria-label={t("listing.edit")}
        >
          <Pencil className="h-4 w-4" />
        </Link>
        <button
          type="button"
          onClick={handleToggle}
          disabled={toggling}
          className="inline-flex h-10 w-10 items-center justify-center rounded-md bg-muted transition-colors hover:bg-gray-200 disabled:opacity-50"
          aria-label={
            listing.is_active
              ? t("listing.deactivate")
              : t("listing.activate")
          }
        >
          {listing.is_active ? (
            <ToggleRight className="h-5 w-5 text-secondary" />
          ) : (
            <ToggleLeft className="h-5 w-5 text-gray-400" />
          )}
        </button>
      </div>
    </div>
  );
}
