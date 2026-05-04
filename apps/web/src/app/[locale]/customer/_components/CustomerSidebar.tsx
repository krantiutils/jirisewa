"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  ShoppingBag,
  ClipboardList,
  Repeat,
  MessageSquare,
  Bell,
} from "lucide-react";

interface CustomerSidebarProps {
  locale: string;
}

const navItems = [
  { key: "dashboard", label: "Dashboard", href: `/customer`, icon: LayoutDashboard },
  { key: "marketplace", label: "Browse market", href: `/marketplace`, icon: ShoppingBag },
  { key: "orders", label: "My orders", href: `/orders`, icon: ClipboardList },
  { key: "subscriptions", label: "Subscriptions", href: `/subscriptions`, icon: Repeat },
  { key: "messages", label: "Messages", href: `/messages`, icon: MessageSquare },
  { key: "notifications", label: "Notifications", href: `/notifications`, icon: Bell },
] as const;

export function CustomerSidebar({ locale }: CustomerSidebarProps) {
  const pathname = usePathname();

  return (
    <aside className="w-60 border-r border-gray-200 bg-white">
      <div className="px-5 py-5">
        <h2 className="text-sm font-bold uppercase tracking-wider text-gray-400">
          My JiriSewa
        </h2>
      </div>
      <nav className="space-y-1 px-3">
        {navItems.map(({ key, label, href, icon: Icon }) => {
          const fullHref = `/${locale}${href}`;
          const isActive =
            href === "/customer"
              ? pathname === fullHref || pathname === `${fullHref}/`
              : pathname.startsWith(fullHref);

          return (
            <Link
              key={key}
              href={fullHref}
              className={`flex items-center gap-3 rounded-md px-3 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? "bg-primary text-white"
                  : "text-gray-600 hover:bg-gray-100 hover:text-foreground"
              }`}
            >
              <Icon className="h-5 w-5" />
              {label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
