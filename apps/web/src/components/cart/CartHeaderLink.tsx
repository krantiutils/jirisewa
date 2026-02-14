"use client";

import Link from "next/link";
import { ShoppingCart } from "lucide-react";
import { useCart } from "@/lib/cart";

export function CartHeaderLink({ locale }: { locale: string }) {
  const { itemCount, hydrated } = useCart();

  return (
    <Link
      href={`/${locale}/cart`}
      className="relative text-gray-600 hover:text-primary transition-colors"
      aria-label="Cart"
    >
      <ShoppingCart className="h-5 w-5" />
      {hydrated && itemCount > 0 && (
        <span className="absolute -right-2 -top-2 flex h-4 w-4 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-white">
          {itemCount > 9 ? "9+" : itemCount}
        </span>
      )}
    </Link>
  );
}
