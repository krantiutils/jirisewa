"use client";

import { useState } from "react";
import Image from "next/image";
import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import {
  ArrowLeft,
  Star,
  Calendar,
  Weight,
  ShoppingCart,
  Plus,
  Minus,
  User,
  ShieldCheck,
} from "lucide-react";
import { Button, Badge } from "@/components/ui";
import { useCart } from "@/lib/cart";
import type { ProduceListingWithDetails } from "@/lib/supabase/types";
import type { Locale } from "@/lib/i18n";

interface ProduceDetailProps {
  listing: ProduceListingWithDetails;
}

export function ProduceDetail({ listing }: ProduceDetailProps) {
  const locale = useLocale() as Locale;
  const t = useTranslations("produce");
  const mt = useTranslations("marketplace");
  const { addItem } = useCart();
  const [selectedPhoto, setSelectedPhoto] = useState(0);
  const [quantity, setQuantity] = useState(1);
  const [added, setAdded] = useState(false);

  const name = locale === "ne" ? listing.name_ne : listing.name_en;
  const categoryName =
    locale === "ne" ? listing.category.name_ne : listing.category.name_en;
  const total = (listing.price_per_kg * quantity).toFixed(2);

  const adjustQuantity = (delta: number) => {
    setQuantity((q) => Math.max(0.5, Math.min(listing.available_qty_kg, q + delta)));
  };

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        {/* Back link */}
        <Link
          href="/marketplace"
          className="mb-6 inline-flex items-center gap-2 text-sm font-medium text-gray-500 transition-colors hover:text-primary"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("backToMarketplace")}
        </Link>

        <div className="grid gap-8 lg:grid-cols-2">
          {/* Photo gallery */}
          <div>
            {/* Main photo */}
            <div className="relative aspect-[4/3] overflow-hidden rounded-lg bg-white">
              {listing.photos.length > 0 ? (
                <Image
                  src={listing.photos[selectedPhoto]}
                  alt={name}
                  fill
                  sizes="(max-width: 1024px) 100vw, 50vw"
                  className="object-cover"
                  priority
                  unoptimized
                />
              ) : (
                <div className="flex h-full items-center justify-center text-6xl text-gray-300">
                  🌿
                </div>
              )}
              <Badge color="secondary" className="absolute left-4 top-4">
                {categoryName}
              </Badge>
            </div>

            {/* Thumbnails */}
            {listing.photos.length > 1 && (
              <div className="mt-3 flex gap-2 overflow-x-auto">
                {listing.photos.map((photo, idx) => (
                  <button
                    key={idx}
                    onClick={() => setSelectedPhoto(idx)}
                    className={`relative h-16 w-16 shrink-0 overflow-hidden rounded-md transition-all ${
                      idx === selectedPhoto
                        ? "ring-2 ring-primary ring-offset-2"
                        : "opacity-70 hover:opacity-100"
                    }`}
                  >
                    <Image
                      src={photo}
                      alt={`${name} ${idx + 1}`}
                      fill
                      sizes="64px"
                      className="object-cover"
                      unoptimized
                    />
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Product info */}
          <div className="space-y-6">
            {/* Name + price */}
            <div>
              <h1 className="text-3xl font-extrabold tracking-tight text-foreground">
                {name}
              </h1>
              <p className="mt-2 text-3xl font-extrabold text-primary">
                {t("pricePerKg", { price: listing.price_per_kg })}
              </p>
            </div>

            {/* Details chips */}
            <div className="flex flex-wrap gap-3">
              {listing.freshness_date && (
                <div className="flex items-center gap-1.5 rounded-md bg-white px-3 py-2 text-sm">
                  <Calendar className="h-4 w-4 text-secondary" />
                  {t("harvestedOn", {
                    date: new Date(listing.freshness_date).toLocaleDateString(
                      locale === "ne" ? "ne-NP" : "en-US",
                      { year: "numeric", month: "long", day: "numeric" },
                    ),
                  })}
                </div>
              )}
              <div className="flex items-center gap-1.5 rounded-md bg-white px-3 py-2 text-sm">
                <Weight className="h-4 w-4 text-accent" />
                {t("availableQty", { qty: listing.available_qty_kg })}
              </div>
            </div>

            {/* Description */}
            {listing.description && (
              <div>
                <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
                  {t("description")}
                </h2>
                <p className="mt-2 leading-relaxed text-gray-700">{listing.description}</p>
              </div>
            )}

            {/* Quantity selector + Add to cart */}
            <div className="rounded-lg bg-white p-6">
              <label className="mb-3 block text-sm font-semibold uppercase tracking-wider text-gray-500">
                {t("quantity")}
              </label>
              <div className="flex items-center gap-4">
                <div className="flex items-center rounded-md border-2 border-gray-200">
                  <button
                    onClick={() => adjustQuantity(-0.5)}
                    className="flex h-12 w-12 items-center justify-center transition-colors hover:bg-gray-100"
                    disabled={quantity <= 0.5}
                  >
                    <Minus className="h-4 w-4" />
                  </button>
                  <span className="w-16 text-center text-lg font-bold">{quantity}</span>
                  <button
                    onClick={() => adjustQuantity(0.5)}
                    className="flex h-12 w-12 items-center justify-center transition-colors hover:bg-gray-100"
                    disabled={quantity >= listing.available_qty_kg}
                  >
                    <Plus className="h-4 w-4" />
                  </button>
                </div>
                <span className="text-lg font-bold text-foreground">
                  {t("totalPrice", { total })}
                </span>
              </div>

              <Button
                variant="primary"
                className="mt-4 w-full h-14 text-base"
                onClick={() => {
                  addItem({
                    listingId: listing.id,
                    farmerId: listing.farmer_id,
                    quantityKg: quantity,
                    pricePerKg: listing.price_per_kg,
                    nameEn: listing.name_en,
                    nameNe: listing.name_ne,
                    farmerName: listing.farmer.name,
                    photo: listing.photos[0] ?? null,
                  });
                  setAdded(true);
                  setTimeout(() => setAdded(false), 2000);
                }}
              >
                <ShoppingCart className="mr-2 h-5 w-5" />
                {added ? t("addedToCart") : t("addToCart")}
              </Button>
            </div>

            {/* Farmer info */}
            <div className="rounded-lg bg-white p-6">
              <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-gray-500">
                {t("farmerInfo")}
              </h2>
              <div className="flex items-center gap-4">
                <div className="flex h-14 w-14 items-center justify-center rounded-full bg-secondary/10">
                  {listing.farmer.avatar_url ? (
                    <Image
                      src={listing.farmer.avatar_url}
                      alt={listing.farmer.name}
                      width={56}
                      height={56}
                      className="rounded-full object-cover"
                      unoptimized
                    />
                  ) : (
                    <User className="h-7 w-7 text-secondary" />
                  )}
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-lg font-bold text-foreground">{listing.farmer.name}</p>
                    {listing.farmer_verified && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-700">
                        <ShieldCheck className="h-3.5 w-3.5" />
                        {mt("verifiedFarmer")}
                      </span>
                    )}
                  </div>
                  {listing.farmer.rating_avg > 0 && (
                    <div className="mt-0.5 flex items-center gap-1 text-sm text-gray-600">
                      <Star className="h-4 w-4 fill-amber-400 text-amber-400" />
                      <span>
                        {Number(listing.farmer.rating_avg).toFixed(1)} ({listing.farmer.rating_count})
                      </span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
