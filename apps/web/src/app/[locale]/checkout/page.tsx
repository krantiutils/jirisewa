"use client";

import { useEffect, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import dynamic from "next/dynamic";
import { useTranslations } from "next-intl";
import { MapPin, Loader2 } from "lucide-react";
import { useCart, getCartSubtotal } from "@/lib/cart";
import { placeOrder } from "@/lib/actions/orders";
import { Button } from "@/components/ui/Button";
import type { Locale } from "@/lib/i18n";
import type { LatLng } from "@/lib/map";
import type { EsewaPaymentFormData } from "@/lib/types/order";

const LocationPicker = dynamic(
  () => import("@/components/map/LocationPicker"),
  { ssr: false },
);

type PaymentMethodOption = "cash" | "esewa";

export default function CheckoutPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("checkout");
  const { cart, hydrated, clearCart } = useCart();
  const esewaFormRef = useRef<HTMLFormElement>(null);

  const [deliveryLocation, setDeliveryLocation] = useState<LatLng | null>(null);
  const [deliveryAddress, setDeliveryAddress] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethodOption>("cash");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [esewaForm, setEsewaForm] = useState<EsewaPaymentFormData | null>(null);

  const subtotal = getCartSubtotal(cart);

  // Redirect to cart if empty (after hydration to avoid flash)
  useEffect(() => {
    if (hydrated && cart.items.length === 0) {
      router.push(`/${locale}/cart`);
    }
  }, [hydrated, cart.items.length, locale, router]);

  // Auto-submit the hidden eSewa form when form data is set
  useEffect(() => {
    if (esewaForm && esewaFormRef.current) {
      esewaFormRef.current.submit();
    }
  }, [esewaForm]);

  if (!hydrated || cart.items.length === 0) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  const handleLocationChange = (location: LatLng, address: string) => {
    setDeliveryLocation(location);
    setDeliveryAddress(address);
  };

  const handlePlaceOrder = async () => {
    if (!deliveryLocation) {
      setError(t("selectDeliveryLocation"));
      return;
    }

    setSubmitting(true);
    setError(null);

    const result = await placeOrder({
      deliveryAddress: deliveryAddress || t("deliveryLocationSet"),
      deliveryLat: deliveryLocation.lat,
      deliveryLng: deliveryLocation.lng,
      paymentMethod,
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

    // For eSewa: redirect to eSewa payment page via hidden form POST
    if (result.data.esewaForm) {
      setEsewaForm(result.data.esewaForm);
      // Form auto-submits via useEffect above
      return;
    }

    // For cash: go directly to order detail
    router.push(`/${locale}/orders/${result.data.orderId}`);
  };

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

        {/* Payment method selection */}
        <section className="mt-8">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("payment")}
          </h2>
          <div className="mt-3 space-y-2">
            {/* Cash on Delivery */}
            <button
              type="button"
              onClick={() => setPaymentMethod("cash")}
              className={`w-full flex items-center gap-3 rounded-lg bg-white p-4 text-left transition-all ${
                paymentMethod === "cash"
                  ? "ring-2 ring-primary border-primary"
                  : "border-2 border-gray-200 hover:border-gray-300"
              }`}
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-green-100 shrink-0">
                <span className="text-lg">💵</span>
              </div>
              <div className="flex-1">
                <p className="font-semibold text-foreground">{t("cashOnDelivery")}</p>
                <p className="text-sm text-gray-500">{t("cashOnDeliveryHint")}</p>
              </div>
              <div
                className={`h-5 w-5 rounded-full border-2 shrink-0 ${
                  paymentMethod === "cash"
                    ? "border-primary bg-primary"
                    : "border-gray-300"
                }`}
              >
                {paymentMethod === "cash" && (
                  <div className="flex h-full w-full items-center justify-center">
                    <div className="h-2 w-2 rounded-full bg-white" />
                  </div>
                )}
              </div>
            </button>

            {/* eSewa */}
            <button
              type="button"
              onClick={() => setPaymentMethod("esewa")}
              className={`w-full flex items-center gap-3 rounded-lg bg-white p-4 text-left transition-all ${
                paymentMethod === "esewa"
                  ? "ring-2 ring-primary border-primary"
                  : "border-2 border-gray-200 hover:border-gray-300"
              }`}
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-green-100 shrink-0">
                <span className="text-lg font-bold text-green-600">e</span>
              </div>
              <div className="flex-1">
                <p className="font-semibold text-foreground">{t("esewaPayment")}</p>
                <p className="text-sm text-gray-500">{t("esewaPaymentHint")}</p>
              </div>
              <div
                className={`h-5 w-5 rounded-full border-2 shrink-0 ${
                  paymentMethod === "esewa"
                    ? "border-primary bg-primary"
                    : "border-gray-300"
                }`}
              >
                {paymentMethod === "esewa" && (
                  <div className="flex h-full w-full items-center justify-center">
                    <div className="h-2 w-2 rounded-full bg-white" />
                  </div>
                )}
              </div>
            </button>
          </div>
        </section>

        {/* Total + Place order */}
        <section className="mt-8 rounded-lg bg-white p-6">
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">{t("subtotal")}</span>
              <span>NPR {subtotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">{t("deliveryFee")}</span>
              <span className="text-gray-500">{t("calculatedAfterMatch")}</span>
            </div>
            <div className="border-t pt-2">
              <div className="flex justify-between text-lg font-bold">
                <span>{t("total")}</span>
                <span>NPR {subtotal.toFixed(2)}</span>
              </div>
            </div>
          </div>

          <Button
            variant="primary"
            className="mt-4 w-full h-14 text-base"
            onClick={handlePlaceOrder}
            disabled={submitting || !deliveryLocation}
          >
            {submitting ? (
              <>
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                {paymentMethod === "esewa" ? t("redirectingToEsewa") : t("placing")}
              </>
            ) : paymentMethod === "esewa" ? (
              t("payWithEsewa")
            ) : (
              t("placeOrder")
            )}
          </Button>
        </section>
      </div>

      {/* Hidden form for eSewa redirect (POST to eSewa payment page) */}
      {esewaForm && (
        <form
          ref={esewaFormRef}
          method="POST"
          action={esewaForm.url}
          className="hidden"
        >
          {Object.entries(esewaForm.fields).map(([key, value]) => (
            <input key={key} type="hidden" name={key} value={value} />
          ))}
        </form>
      )}
    </main>
  );
}
