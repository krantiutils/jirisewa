"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { LogIn, User, ShoppingCart } from "lucide-react";
import { ChatBadge } from "@/components/chat/ChatBadge";
import { CartHeaderLink } from "@/components/cart/CartHeaderLink";
import { NotificationBell } from "@/components/notifications/NotificationBell";
import { LanguageSwitcher } from "@/components/LanguageSwitcher";
import { Button } from "@/components/ui/Button";

interface HeaderProps {
  locale: string;
}

export function Header({ locale }: HeaderProps) {
  const router = useRouter();
  const params = useParams();
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const t = useTranslations("nav");

  // Check auth state by trying to get session
  useEffect(() => {
    async function checkAuth() {
      try {
        const res = await fetch("/api/auth/session");
        if (res.ok) {
          const data = await res.json();
          setIsAuthenticated(!!data.user);
        } else {
          setIsAuthenticated(false);
        }
      } catch {
        setIsAuthenticated(false);
      }
    }
    checkAuth();
  }, []);

  return (
    <header className="flex items-center justify-between border-b border-gray-200 px-6 py-3">
      <div className="flex items-center gap-6">
        <Link
          href={`/${locale}`}
          className="text-lg font-bold text-primary"
        >
          {locale === "ne" ? "जिरीसेवा" : "JiriSewa"}
        </Link>
        <nav className="hidden items-center gap-4 text-sm sm:flex">
          {/* Available to everyone */}
          <Link
            href={`/${locale}/marketplace`}
            className="text-gray-600 hover:text-primary transition-colors"
          >
            {t("marketplace")}
          </Link>

          {/* Only for authenticated users */}
          {isAuthenticated && (
            <>
              <Link
                href={`/${locale}/orders`}
                className="text-gray-600 hover:text-primary transition-colors"
              >
                {t("orders")}
              </Link>
              <Link
                href={`/${locale}/customer`}
                className="text-gray-600 hover:text-primary transition-colors"
              >
                Shop
              </Link>
              <Link
                href={`/${locale}/farmer/dashboard`}
                className="text-gray-600 hover:text-primary transition-colors"
              >
                {t("business")}
              </Link>
              <Link
                href={`/${locale}/rider/dashboard`}
                className="text-gray-600 hover:text-primary transition-colors"
              >
                {t("rider")}
              </Link>
            </>
          )}
        </nav>
      </div>
      <div className="flex items-center gap-3">
        {/* Chat and notifications only for authenticated users */}
        {isAuthenticated && (
          <>
            <ChatBadge locale={locale} />
            <NotificationBell />
          </>
        )}

        {/* Cart available to everyone */}
        <CartHeaderLink locale={locale} />
        <LanguageSwitcher />

        {isAuthenticated ? (
          <Link
            href={`/${locale}/notifications`}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-white hover:bg-blue-600"
          >
            <User className="h-4 w-4" />
          </Link>
        ) : (
          <Link
            href={`/${locale}/auth/login`}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-md hover:bg-blue-600 transition-colors"
          >
            <LogIn className="h-4 w-4" />
            {locale === "ne" ? "लग इन" : "Sign In"}
          </Link>
        )}
      </div>
    </header>
  );
}
