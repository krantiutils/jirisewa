"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  ShoppingCart,
  AlertTriangle,
  UserCheck,
} from "lucide-react";
import { useTranslations } from "next-intl";

interface AdminSidebarProps {
  locale: string;
}

const navItems = [
  { key: "dashboard", href: "", icon: LayoutDashboard },
  { key: "users", href: "/users", icon: Users },
  { key: "orders", href: "/orders", icon: ShoppingCart },
  { key: "disputes", href: "/disputes", icon: AlertTriangle },
  { key: "farmers", href: "/farmers", icon: UserCheck },
] as const;

export function AdminSidebar({ locale }: AdminSidebarProps) {
  const pathname = usePathname();
  const t = useTranslations("admin.nav");

  const basePath = `/${locale}/admin`;

  return (
    <aside className="w-60 border-r border-gray-200 bg-white">
      <div className="px-5 py-5">
        <h2 className="text-sm font-bold uppercase tracking-wider text-gray-400">
          {t("title")}
        </h2>
      </div>
      <nav className="space-y-1 px-3">
        {navItems.map(({ key, href, icon: Icon }) => {
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
              {t(key)}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
