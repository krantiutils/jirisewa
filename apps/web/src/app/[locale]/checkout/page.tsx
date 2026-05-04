"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import dynamic from "next/dynamic";
import { useTranslations } from "next-intl";
import { MapPin, Loader2 } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useCart, getCartSubtotal } from "@/lib/cart";
import { placeOrder } from "@/lib/actions/orders";
import { calculateDeliveryFee } from "@/lib/actions/delivery-fee";
import { listAddresses, createAddress } from "@/lib/actions/addresses";
import type { SavedAddress } from "@/lib/actions/addresses";
import { Button } from "@/components/ui/Button";
import type { Locale } from "@/lib/i18n";
import type { LatLng } from "@/lib/map";
import type { EsewaPaymentFormData, ConnectIPSPaymentFormData, DeliveryFeeEstimate } from "@/lib/types/order";

const LocationPicker = dynamic(
  () => import("@/components/map/LocationPicker"),
  { ssr: false },
);

type PaymentMethodOption = "cash" | "esewa" | "khalti" | "connectips";

export default function CheckoutPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("checkout");
  const { cart, hydrated, clearCart } = useCart();
  const esewaFormRef = useRef<HTMLFormElement>(null);
  const connectipsFormRef = useRef<HTMLFormElement>(null);

  const [deliveryLocation, setDeliveryLocation] = useState<LatLng | null>(null);
  const [deliveryAddress, setDeliveryAddress] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethodOption>("cash");
  const [submitting, setSubmitting] = useState(false);
  const [orderPlaced, setOrderPlaced] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [esewaForm, setEsewaForm] = useState<EsewaPaymentFormData | null>(null);
  const [connectipsForm, setConnectipsForm] = useState<ConnectIPSPaymentFormData | null>(null);

  const [feeEstimate, setFeeEstimate] = useState<DeliveryFeeEstimate | null>(null);
  const [feeLoading, setFeeLoading] = useState(false);
  const [feeError, setFeeError] = useState<string | null>(null);

  const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);
  const [saveNewAddress, setSaveNewAddress] = useState(false);

  const { user, loading: authLoading } = useAuth();

  useEffect(() => {
    if (!authLoading && !user) {
      router.replace(`/${locale}/auth/login`);
    }
  }, [authLoading, user, router, locale]);

  const subtotal = getCartSubtotal(cart);
  const total = subtotal + (feeEstimate?.totalFee ?? 0);

  // Redirect to cart if empty (after hydration to avoid flash)
  useEffect(() => {
    if (hydrated && cart.items.length === 0 && !submitting && !orderPlaced) {
      router.push(`/${locale}/cart`);
    }
  }, [hydrated, cart.items.length, locale, orderPlaced, router, submitting]);

  // Auto-submit hidden payment forms when form data is set
  useEffect(() => {
    if (esewaForm && esewaFormRef.current) {
      esewaFormRef.current.submit();
    }
  }, [esewaForm]);

  useEffect(() => {
    if (connectipsForm && connectipsFormRef.current) {
      connectipsFormRef.current.submit();
    }
  }, [connectipsForm]);

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

  // Load saved addresses when authenticated
  useEffect(() => {
    if (authLoading || !user) return;
    listAddresses().then((result) => {
      if (result.data) {
        setSavedAddresses(result.data);
        // Auto-select the default address if no delivery location is set yet
        const defaultAddr = result.data.find((a) => a.isDefault);
        if (defaultAddr && !deliveryLocation) {
          setDeliveryLocation({ lat: defaultAddr.lat, lng: defaultAddr.lng });
          setDeliveryAddress(defaultAddr.addressText);
          computeFee({ lat: defaultAddr.lat, lng: defaultAddr.lng });
        }
      }
    });
    // Run only once when user is authenticated
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authLoading, user]);

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
      paymentMethod,
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

    setOrderPlaced(true);
    clearCart();

    // Save the delivery address if user opted in
    if (saveNewAddress && deliveryLocation && deliveryAddress) {
      await createAddress({
        label: "Delivery",
        addressText: deliveryAddress,
        lat: deliveryLocation.lat,
        lng: deliveryLocation.lng,
      });
    }

    // For eSewa: redirect to eSewa payment page via hidden form POST
    if (result.data.esewaForm) {
      setEsewaForm(result.data.esewaForm);
      return;
    }

    // For Khalti: redirect to Khalti payment URL (API-based, not form POST)
    if (result.data.khaltiPayment) {
      window.location.href = result.data.khaltiPayment.paymentUrl;
      return;
    }

    // For connectIPS: redirect via hidden form POST
    if (result.data.connectipsForm) {
      setConnectipsForm(result.data.connectipsForm);
      return;
    }

    // For cash: go directly to order detail
    router.push(`/${locale}/orders/${result.data.orderId}`);
  };

  if (authLoading || !user) return null;

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

        {/* Order summary — grouped by farmer */}
        <section className="mt-6">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            {t("orderSummary")}
          </h2>
          {(() => {
            // Group cart items by farmer
            const farmerGroups = new Map<string, typeof cart.items>();
            for (const item of cart.items) {
              const group = farmerGroups.get(item.farmerId) ?? [];
              group.push(item);
              farmerGroups.set(item.farmerId, group);
            }
            const isMultiFarmer = farmerGroups.size > 1;

            return (
              <div className="mt-3 space-y-4">
                {[...farmerGroups.entries()].map(([farmerId, items], groupIdx) => (
                  <div key={farmerId}>
                    {isMultiFarmer && (
                      <div className="mb-2 flex items-center gap-2">
                        <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-xs font-bold text-primary">
                          {groupIdx + 1}
                        </span>
                        <span className="text-xs font-semibold text-gray-600">
                          {t("pickupFrom", { farmer: items[0].farmerName })}
                        </span>
                      </div>
                    )}
                    <div className="space-y-2">
                      {items.map((item) => {
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
                                {!isMultiFarmer && `${item.farmerName} · `}
                                {item.quantityKg} {item.unit || "kg"} &times; NPR {item.pricePerKg}
                              </p>
                            </div>
                            <span className="text-sm font-bold">
                              NPR {(item.quantityKg * item.pricePerKg).toFixed(2)}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ))}
                {isMultiFarmer && (
                  <p className="text-xs text-gray-500 italic">
                    {t("multiFarmerNote", { count: farmerGroups.size })}
                  </p>
                )}
              </div>
            );
          })()}
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
          {savedAddresses.length > 0 && (
            <div className="mt-3 mb-4">
              <p className="mb-2 text-sm font-medium text-gray-700">{t("savedAddresses")}</p>
              <div className="flex flex-wrap gap-2">
                {savedAddresses.map((addr) => (
                  <button
                    key={addr.id}
                    onClick={() => {
                      setDeliveryLocation({ lat: addr.lat, lng: addr.lng });
                      setDeliveryAddress(addr.addressText);
                      computeFee({ lat: addr.lat, lng: addr.lng });
                    }}
                    className={`rounded-full border px-3 py-1.5 text-sm transition-colors ${
                      deliveryAddress === addr.addressText
                        ? "border-primary bg-primary/10 text-primary font-medium"
                        : "border-gray-300 text-gray-600 hover:border-primary/50"
                    }`}
                  >
                    {addr.label}{addr.isDefault ? " \u2605" : ""}
                  </button>
                ))}
              </div>
            </div>
          )}
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
          {deliveryLocation && !savedAddresses.some(a => a.lat === deliveryLocation.lat && a.lng === deliveryLocation.lng) && (
            <label className="mt-2 flex items-center gap-2 text-sm text-gray-600">
              <input type="checkbox" checked={saveNewAddress} onChange={(e) => setSaveNewAddress(e.target.checked)} className="rounded" />
              {t("saveAddress")}
            </label>
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

            {/* Khalti */}
            <button
              type="button"
              onClick={() => setPaymentMethod("khalti")}
              className={`w-full flex items-center gap-3 rounded-lg bg-white p-4 text-left transition-all ${
                paymentMethod === "khalti"
                  ? "ring-2 ring-primary border-primary"
                  : "border-2 border-gray-200 hover:border-gray-300"
              }`}
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-purple-100 shrink-0">
                <span className="text-lg font-bold text-purple-600">K</span>
              </div>
              <div className="flex-1">
                <p className="font-semibold text-foreground">{t("khaltiPayment")}</p>
                <p className="text-sm text-gray-500">{t("khaltiPaymentHint")}</p>
              </div>
              <div
                className={`h-5 w-5 rounded-full border-2 shrink-0 ${
                  paymentMethod === "khalti"
                    ? "border-primary bg-primary"
                    : "border-gray-300"
                }`}
              >
                {paymentMethod === "khalti" && (
                  <div className="flex h-full w-full items-center justify-center">
                    <div className="h-2 w-2 rounded-full bg-white" />
                  </div>
                )}
              </div>
            </button>

            {/* connectIPS */}
            <button
              type="button"
              onClick={() => setPaymentMethod("connectips")}
              className={`w-full flex items-center gap-3 rounded-lg bg-white p-4 text-left transition-all ${
                paymentMethod === "connectips"
                  ? "ring-2 ring-primary border-primary"
                  : "border-2 border-gray-200 hover:border-gray-300"
              }`}
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 shrink-0">
                <span className="text-sm font-bold text-blue-600">IPS</span>
              </div>
              <div className="flex-1">
                <p className="font-semibold text-foreground">{t("connectipsPayment")}</p>
                <p className="text-sm text-gray-500">{t("connectipsPaymentHint")}</p>
              </div>
              <div
                className={`h-5 w-5 rounded-full border-2 shrink-0 ${
                  paymentMethod === "connectips"
                    ? "border-primary bg-primary"
                    : "border-gray-300"
                }`}
              >
                {paymentMethod === "connectips" && (
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
                {paymentMethod === "cash" ? t("placing") : t("redirectingToPayment")}
              </>
            ) : paymentMethod === "esewa" ? (
              t("payWithEsewa")
            ) : paymentMethod === "khalti" ? (
              t("payWithKhalti")
            ) : paymentMethod === "connectips" ? (
              t("payWithConnectIPS")
            ) : (
              t("placeOrder")
            )}
          </Button>
          {!submitting && (!deliveryLocation || feeLoading || !feeEstimate) && (
            <p className="mt-2 text-center text-sm text-gray-500">
              {!deliveryLocation
                ? t("selectDeliveryLocation")
                : feeLoading
                  ? t("calculatingFee")
                  : t("feeError")}
            </p>
          )}
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

      {/* Hidden form for connectIPS redirect (POST to connectIPS gateway) */}
      {connectipsForm && (
        <form
          ref={connectipsFormRef}
          method="POST"
          action={connectipsForm.url}
          className="hidden"
        >
          {Object.entries(connectipsForm.fields).map(([key, value]) => (
            <input key={key} type="hidden" name={key} value={value} />
          ))}
        </form>
      )}
    </main>
  );
}
