"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useRef, useState, useEffect } from "react";
import { useTranslations } from "next-intl";
import { LogIn, User, Bell, LogOut, ChevronDown, MapPin, Settings } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { ChatBadge } from "@/components/chat/ChatBadge";
import { CartHeaderLink } from "@/components/cart/CartHeaderLink";
import { NotificationBell } from "@/components/notifications/NotificationBell";
import { LanguageSwitcher } from "@/components/LanguageSwitcher";

interface HeaderProps {
  locale: string;
}

export function Header({ locale }: HeaderProps) {
  const pathname = usePathname();
  const { user, profile, signOut } = useAuth();
  const t = useTranslations("nav");
  const tAddr = useTranslations("addresses");
  const tAcct = useTranslations("account");
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // Close dropdown on click outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    }
    if (menuOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () => document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [menuOpen]);

  const isAuthenticated = !!user;
  const role = profile?.role;

  // Minimal header for onboarding page
  if (pathname.includes("/onboarding")) {
    return (
      <header className="flex items-center justify-between border-b border-gray-200 px-6 py-3">
        <Link
          href={`/${locale}`}
          className="text-lg font-bold text-primary"
        >
          {locale === "ne" ? "जिरीसेवा" : "JiriSewa"}
        </Link>
        <LanguageSwitcher />
      </header>
    );
  }

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
          {/* Marketplace — customers + unauthenticated */}
          {(!isAuthenticated || role === "customer") && (
            <Link
              href={`/${locale}/marketplace`}
              className="text-gray-600 hover:text-primary transition-colors"
            >
              {t("marketplace")}
            </Link>
          )}

          {/* Customer orders */}
          {isAuthenticated && role === "customer" && (
            <Link
              href={`/${locale}/orders`}
              className="text-gray-600 hover:text-primary transition-colors"
            >
              {t("myOrders")}
            </Link>
          )}

          {/* Farmer dashboard + orders */}
          {isAuthenticated && role === "farmer" && (
            <>
              <Link
                href={`/${locale}/farmer/dashboard`}
                className="text-gray-600 hover:text-primary transition-colors"
              >
                {t("myDashboard")}
              </Link>
              <Link
                href={`/${locale}/farmer/orders`}
                className="text-gray-600 hover:text-primary transition-colors"
              >
                {t("myOrders")}
              </Link>
            </>
          )}

          {/* Rider dashboard */}
          {isAuthenticated && role === "rider" && (
            <Link
              href={`/${locale}/rider/dashboard`}
              className="text-gray-600 hover:text-primary transition-colors"
            >
              {t("myDashboard")}
            </Link>
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

        {/* Cart — customers + unauthenticated */}
        {(!isAuthenticated || role === "customer") && (
          <CartHeaderLink locale={locale} />
        )}
        <LanguageSwitcher />

        {isAuthenticated ? (
          <div className="relative" ref={menuRef}>
            <button
              onClick={() => setMenuOpen((v) => !v)}
              className="flex items-center gap-1.5 rounded-full bg-primary px-3 py-1.5 text-sm font-medium text-white hover:bg-blue-600 transition-colors"
            >
              <User className="h-4 w-4" />
              <span className="hidden sm:inline max-w-[100px] truncate">
                {profile?.full_name || t("account")}
              </span>
              <ChevronDown className="h-3 w-3" />
            </button>

            {menuOpen && (
              <div className="absolute right-0 mt-2 w-56 rounded-lg border border-gray-200 bg-white py-1 shadow-lg z-50">
                {/* Name + role */}
                <div className="border-b border-gray-100 px-4 py-3">
                  <p className="text-sm font-semibold text-gray-900 truncate">
                    {profile?.full_name || user?.email || t("account")}
                  </p>
                  {role && (
                    <span className="mt-1 inline-block rounded-full bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary capitalize">
                      {role}
                    </span>
                  )}
                </div>

                {/* Notifications link */}
                <Link
                  href={`/${locale}/notifications`}
                  onClick={() => setMenuOpen(false)}
                  className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  <Bell className="h-4 w-4 text-gray-400" />
                  {t("notifications")}
                </Link>

                {/* Account Settings */}
                <Link
                  href={`/${locale}/settings/account`}
                  onClick={() => setMenuOpen(false)}
                  className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  <Settings className="h-4 w-4 text-gray-400" />
                  {tAcct("title")}
                </Link>

                {/* Saved Addresses */}
                <Link
                  href={`/${locale}/settings/addresses`}
                  onClick={() => setMenuOpen(false)}
                  className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  <MapPin className="h-4 w-4 text-gray-400" />
                  {tAddr("title")}
                </Link>

                {/* Sign Out */}
                <button
                  onClick={() => {
                    setMenuOpen(false);
                    signOut();
                  }}
                  className="flex w-full items-center gap-3 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors"
                >
                  <LogOut className="h-4 w-4" />
                  {t("signOut")}
                </button>
              </div>
            )}
          </div>
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
