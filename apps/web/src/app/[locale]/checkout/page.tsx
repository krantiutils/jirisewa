"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import dynamic from "next/dynamic";
import { useTranslations } from "next-intl";
import { MapPin, Loader2 } from "lucide-react";
import { useCart, getCartSubtotal } from "@/lib/cart";
import { placeOrder } from "@/lib/actions/orders";
import { calculateDeliveryFee } from "@/lib/actions/delivery-fee";
import { Button } from "@/components/ui/Button";
import type { Locale } from "@/lib/i18n";
import type { LatLng } from "@/lib/map";
import type { DeliveryFeeEstimate } from "@/lib/types/order";

const LocationPicker = dynamic(
  () => import("@/components/map/LocationPicker"),
  { ssr: false },
);

export default function CheckoutPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("checkout");
  const { cart, hydrated, clearCart } = useCart();

  const [deliveryLocation, setDeliveryLocation] = useState<LatLng | null>(null);
  const [deliveryAddress, setDeliveryAddress] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [feeEstimate, setFeeEstimate] = useState<DeliveryFeeEstimate | null>(null);
  const [feeLoading, setFeeLoading] = useState(false);
  const [feeError, setFeeError] = useState<string | null>(null);

  const subtotal = getCartSubtotal(cart);
  const total = subtotal + (feeEstimate?.totalFee ?? 0);

  // Redirect to cart if empty (after hydration to avoid flash)
  useEffect(() => {
    if (hydrated && cart.items.length === 0) {
      router.push(`/${locale}/cart`);
    }
  }, [hydrated, cart.items.length, locale, router]);

  // Calculate delivery fee when location changes
  const computeFee = useCallback(async (location: LatLng) => {
    if (cart.items.length === 0) return;

    setFeeLoading(true);
    setFeeError(null);
    setFeeEstimate(null);

    const result = await calculateDeliveryFee({
      listingIds: cart.items.map((item) => item.listingId),
      itemWeights: cart.items.map((item) => ({
        listingId: item.listingId,
        quantityKg: item.quantityKg,
      })),
      deliveryLat: location.lat,
      deliveryLng: location.lng,
    });

    if (result.error || !result.data) {
      setFeeError(result.error ?? t("feeError"));
    } else {
      setFeeEstimate(result.data);
    }

    setFeeLoading(false);
  }, [cart.items, t]);

  const handleLocationChange = (location: LatLng, address: string) => {
    setDeliveryLocation(location);
    setDeliveryAddress(address);
    computeFee(location);
  };

  const handlePlaceOrder = async () => {
    if (!deliveryLocation) {
      setError(t("selectDeliveryLocation"));
      return;
    }

    if (!feeEstimate) {
      setError(t("feeError"));
      return;
    }

    setSubmitting(true);
    setError(null);

    const result = await placeOrder({
      deliveryAddress: deliveryAddress || t("deliveryLocationSet"),
      deliveryLat: deliveryLocation.lat,
      deliveryLng: deliveryLocation.lng,
      deliveryFee: feeEstimate.totalFee,
      deliveryFeeBase: feeEstimate.baseFee,
      deliveryFeeDistance: feeEstimate.distanceFee,
      deliveryFeeWeight: feeEstimate.weightFee,
      deliveryDistanceKm: feeEstimate.distanceKm,
      items: cart.items.map((item) => ({
        listingId: item.listingId,
        farmerId: item.farmerId,
        quantityKg: item.quantityKg,
        pricePerKg: item.pricePerKg,
      })),
    });

    if (result.error || !result.data) {
      setError(result.error ?? "Failed to place order");
      setSubmitting(false);
      return;
    }

    clearCart();
    router.push(`/${locale}/orders/${result.data.orderId}`);
  };

  if (!hydrated || cart.items.length === 0) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-3xl px-4 py-6 sm:px-6">
        <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>

        {error && (
          <div className="mt-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Order summary */}
        <section className="mt-6">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("orderSummary")}
          </h2>
          <div className="mt-3 space-y-2">
            {cart.items.map((item) => {
              const name = locale === "ne" ? item.nameNe : item.nameEn;
              return (
                <div
                  key={item.listingId}
                  className="flex items-center gap-3 rounded-lg bg-white p-3"
                >
                  <div className="relative h-12 w-12 shrink-0 overflow-hidden rounded bg-gray-100">
                    {item.photo ? (
                      <Image
                        src={item.photo}
                        alt={name}
                        fill
                        sizes="48px"
                        className="object-cover"
                        unoptimized
                      />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center text-lg text-gray-300">
                        🌿
                      </div>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="truncate text-sm font-semibold">{name}</p>
                    <p className="text-xs text-gray-500">
                      {item.quantityKg} kg &times; NPR {item.pricePerKg}
                    </p>
                  </div>
                  <span className="text-sm font-bold">
                    NPR {(item.quantityKg * item.pricePerKg).toFixed(2)}
                  </span>
                </div>
              );
            })}
          </div>
        </section>

        {/* Delivery location */}
        <section className="mt-8">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            <MapPin className="mr-1 inline h-4 w-4" />
            {t("deliveryLocation")}
          </h2>
          <p className="mt-1 text-sm text-gray-500">
            {t("deliveryLocationHint")}
          </p>
          <div className="mt-3 h-64 overflow-hidden rounded-lg border-2 border-gray-200">
            <LocationPicker
              value={deliveryLocation}
              onChange={handleLocationChange}
              className="h-full"
            />
          </div>
          {deliveryAddress && (
            <p className="mt-2 text-sm text-gray-600">{deliveryAddress}</p>
          )}
        </section>

        {/* Payment */}
        <section className="mt-8">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("payment")}
          </h2>
          <div className="mt-3 rounded-lg bg-white p-4">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-green-100">
                <span className="text-lg">💵</span>
              </div>
              <div>
                <p className="font-semibold text-foreground">{t("cashOnDelivery")}</p>
                <p className="text-sm text-gray-500">{t("cashOnDeliveryHint")}</p>
              </div>
            </div>
          </div>
        </section>

        {/* Total + Place order */}
        <section className="mt-8 rounded-lg bg-white p-6">
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">{t("subtotal")}</span>
              <span>NPR {subtotal.toFixed(2)}</span>
            </div>

            {/* Delivery fee section */}
            {feeLoading ? (
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">{t("deliveryFee")}</span>
                <span className="flex items-center gap-1 text-gray-400">
                  <Loader2 className="h-3 w-3 animate-spin" />
                  {t("calculatingFee")}
                </span>
              </div>
            ) : feeError ? (
              <div className="rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-700">
                {feeError}
              </div>
            ) : feeEstimate ? (
              <>
                <div className="flex justify-between text-sm font-medium">
                  <span className="text-gray-500">{t("deliveryFee")}</span>
                  <span>NPR {feeEstimate.totalFee.toFixed(2)}</span>
                </div>
                <div className="ml-4 space-y-1 border-l-2 border-gray-100 pl-3">
                  <div className="flex justify-between text-xs text-gray-400">
                    <span>{t("baseFee")}</span>
                    <span>NPR {feeEstimate.baseFee.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-xs text-gray-400">
                    <span>{t("distanceFee", { km: feeEstimate.distanceKm.toFixed(1) })}</span>
                    <span>NPR {feeEstimate.distanceFee.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-xs text-gray-400">
                    <span>{t("weightFee", { kg: feeEstimate.weightKg.toFixed(1) })}</span>
                    <span>NPR {feeEstimate.weightFee.toFixed(2)}</span>
                  </div>
                </div>
              </>
            ) : (
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">{t("deliveryFee")}</span>
                <span className="text-gray-400">{t("calculatedAfterMatch")}</span>
              </div>
            )}

            <div className="border-t pt-2">
              <div className="flex justify-between text-lg font-bold">
                <span>{t("total")}</span>
                <span>NPR {total.toFixed(2)}</span>
              </div>
            </div>
          </div>

          <Button
            variant="primary"
            className="mt-4 w-full h-14 text-base"
            onClick={handlePlaceOrder}
            disabled={submitting || !deliveryLocation || feeLoading || !feeEstimate}
          >
            {submitting ? (
              <>
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                {t("placing")}
              </>
            ) : (
              t("placeOrder")
            )}
          </Button>
        </section>
      </div>
    </main>
  );
}
