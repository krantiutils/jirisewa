"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Package,
  Inbox,
  Truck,
} from "lucide-react";

interface HubSidebarProps {
  locale: string;
  hubName: string | null;
}

const navItems = [
  { key: "dashboard", label: "Dashboard", href: "", icon: LayoutDashboard },
  { key: "inventory", label: "Inventory", href: "/inventory", icon: Package },
  { key: "dropoffs", label: "Drop-offs", href: "/dropoffs", icon: Inbox },
  { key: "dispatched", label: "Dispatched", href: "/dispatched", icon: Truck },
] as const;

export function HubSidebar({ locale, hubName }: HubSidebarProps) {
  const pathname = usePathname();
  const basePath = `/${locale}/hub`;

  return (
    <aside className="w-60 border-r border-gray-200 bg-white">
      <div className="px-5 py-5">
        <h2 className="text-sm font-bold uppercase tracking-wider text-gray-400">
          Hub Panel
        </h2>
        {hubName && (
          <p className="mt-1 truncate text-sm font-medium text-foreground">
            {hubName}
          </p>
        )}
      </div>
      <nav className="space-y-1 px-3">
        {navItems.map(({ key, label, href, icon: Icon }) => {
          const fullHref = `${basePath}${href}`;
          const isActive =
            href === ""
              ? pathname === basePath || pathname === `${basePath}/`
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
