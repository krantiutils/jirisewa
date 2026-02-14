"use client";

import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { Trash2, Minus, Plus, ShoppingBag, ArrowLeft } from "lucide-react";
import { useCart, getCartSubtotal } from "@/lib/cart";
import { Button } from "@/components/ui/Button";
import type { Locale } from "@/lib/i18n";

export default function CartPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("cart");
  const { cart, hydrated, removeItem, updateQuantity, clearCart } = useCart();

  const subtotal = getCartSubtotal(cart);

  if (!hydrated) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <ShoppingBag className="h-8 w-8 animate-pulse text-gray-300" />
      </main>
    );
  }

  if (cart.items.length === 0) {
    return (
      <main className="min-h-screen bg-muted">
        <div className="mx-auto max-w-2xl px-4 py-16 text-center">
          <ShoppingBag className="mx-auto h-16 w-16 text-gray-300" />
          <h1 className="mt-4 text-2xl font-bold text-foreground">
            {t("empty")}
          </h1>
          <p className="mt-2 text-gray-500">{t("emptyHint")}</p>
          <Button
            variant="primary"
            className="mt-6"
            onClick={() => router.push(`/${locale}/marketplace`)}
          >
            {t("browseMarketplace")}
          </Button>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-3xl px-4 py-6 sm:px-6">
        <button
          onClick={() => router.push(`/${locale}/marketplace`)}
          className="mb-4 inline-flex items-center gap-2 text-sm font-medium text-gray-500 hover:text-primary transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("continueShopping")}
        </button>

        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-foreground">
            {t("title")} ({cart.items.length})
          </h1>
          <button
            onClick={clearCart}
            className="text-sm text-red-500 hover:text-red-700 transition-colors"
          >
            {t("clearAll")}
          </button>
        </div>

        <div className="mt-6 space-y-3">
          {cart.items.map((item) => {
            const name = locale === "ne" ? item.nameNe : item.nameEn;
            const itemTotal = (item.quantityKg * item.pricePerKg).toFixed(2);
            return (
              <div
                key={item.listingId}
                className="flex gap-4 rounded-lg bg-white p-4"
              >
                {/* Photo */}
                <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-md bg-gray-100">
                  {item.photo ? (
                    <Image
                      src={item.photo}
                      alt={name}
                      fill
                      sizes="80px"
                      className="object-cover"
                      unoptimized
                    />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-2xl text-gray-300">
                      🌿
                    </div>
                  )}
                </div>

                {/* Details */}
                <div className="flex flex-1 flex-col justify-between">
                  <div>
                    <p className="font-semibold text-foreground">{name}</p>
                    <p className="text-sm text-gray-500">
                      {t("fromFarmer", { farmer: item.farmerName })}
                    </p>
                    <p className="text-sm text-gray-500">
                      NPR {item.pricePerKg}/kg
                    </p>
                  </div>

                  <div className="mt-2 flex items-center justify-between">
                    {/* Quantity controls */}
                    <div className="flex items-center gap-1 rounded-md border border-gray-200">
                      <button
                        onClick={() =>
                          updateQuantity(
                            item.listingId,
                            Math.max(0.5, item.quantityKg - 0.5),
                          )
                        }
                        className="flex h-8 w-8 items-center justify-center hover:bg-gray-100 transition-colors"
                        disabled={item.quantityKg <= 0.5}
                      >
                        <Minus className="h-3 w-3" />
                      </button>
                      <span className="w-12 text-center text-sm font-semibold">
                        {item.quantityKg} kg
                      </span>
                      <button
                        onClick={() =>
                          updateQuantity(item.listingId, item.quantityKg + 0.5)
                        }
                        className="flex h-8 w-8 items-center justify-center hover:bg-gray-100 transition-colors"
                      >
                        <Plus className="h-3 w-3" />
                      </button>
                    </div>

                    <div className="flex items-center gap-3">
                      <span className="font-bold text-foreground">
                        NPR {itemTotal}
                      </span>
                      <button
                        onClick={() => removeItem(item.listingId)}
                        className="text-gray-400 hover:text-red-500 transition-colors"
                        aria-label={t("remove")}
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Summary */}
        <div className="mt-6 rounded-lg bg-white p-6">
          <div className="flex items-center justify-between text-lg font-bold">
            <span>{t("subtotal")}</span>
            <span>NPR {subtotal.toFixed(2)}</span>
          </div>
          <p className="mt-1 text-sm text-gray-500">{t("deliveryFeeNote")}</p>

          <Button
            variant="primary"
            className="mt-4 w-full h-14 text-base"
            onClick={() => router.push(`/${locale}/checkout`)}
          >
            {t("proceedToCheckout")}
          </Button>
        </div>
      </div>
    </main>
  );
}
