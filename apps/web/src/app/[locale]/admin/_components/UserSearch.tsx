"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Search } from "lucide-react";
import { useTranslations } from "next-intl";

interface UserSearchProps {
  locale: string;
  initialSearch?: string;
  initialRole?: string;
}

export function UserSearch({
  locale,
  initialSearch,
  initialRole,
}: UserSearchProps) {
  const router = useRouter();
  const t = useTranslations("admin");
  const [search, setSearch] = useState(initialSearch ?? "");
  const [role, setRole] = useState(initialRole ?? "all");

  function applyFilters() {
    const params = new URLSearchParams();
    if (search) params.set("search", search);
    if (role && role !== "all") params.set("role", role);
    router.push(`/${locale}/admin/users?${params.toString()}`);
  }

  return (
    <div className="flex flex-wrap gap-3">
      <div className="relative flex-1 min-w-[200px]">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && applyFilters()}
          placeholder={t("users.searchPlaceholder")}
          className="w-full rounded-md bg-gray-100 py-2.5 pl-10 pr-4 text-sm text-foreground placeholder:text-gray-400 focus:border-2 focus:border-primary focus:outline-none"
        />
      </div>
      <select
        value={role}
        onChange={(e) => {
          setRole(e.target.value);
          const params = new URLSearchParams();
          if (search) params.set("search", search);
          if (e.target.value !== "all") params.set("role", e.target.value);
          router.push(`/${locale}/admin/users?${params.toString()}`);
        }}
        className="rounded-md bg-gray-100 px-4 py-2.5 text-sm text-foreground focus:border-2 focus:border-primary focus:outline-none"
      >
        <option value="all">{t("users.allRoles")}</option>
        <option value="farmer">{t("users.roleFarmer")}</option>
        <option value="consumer">{t("users.roleConsumer")}</option>
        <option value="rider">{t("users.roleRider")}</option>
      </select>
    </div>
  );
}
