import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { getUsers } from "@/lib/admin/queries";
import { Badge } from "@/components/ui";
import Link from "next/link";
import { UserSearch } from "../_components/UserSearch";

export default async function AdminUsersPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ page?: string; search?: string; role?: string }>;
}) {
  const { locale } = await params;
  const sp = await searchParams;
  setRequestLocale(locale);

  const t = await getTranslations("admin");

  const page = Number(sp.page) || 1;
  const { users, total } = await getUsers(locale, {
    page,
    search: sp.search,
    role: sp.role,
  });

  const totalPages = Math.ceil(total / 20);

  const roleBadgeColor = (role: string) => {
    switch (role) {
      case "farmer":
        return "secondary" as const;
      case "rider":
        return "accent" as const;
      default:
        return "primary" as const;
    }
  };

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">
          {t("users.title")}
        </h1>
        <span className="text-sm text-gray-500">
          {total} {t("users.totalUsers")}
        </span>
      </div>

      <UserSearch locale={locale} initialSearch={sp.search} initialRole={sp.role} />

      <div className="mt-4 rounded-lg bg-white">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.name")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.phone")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.role")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.rating")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.joined")}
                </th>
                <th className="px-4 py-3 font-medium text-gray-500">
                  {t("users.actions")}
                </th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr
                  key={user.id}
                  className="border-b border-gray-50 last:border-0"
                >
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-foreground">
                        {user.name}
                      </span>
                      {user.is_admin && (
                        <Badge color="danger">Admin</Badge>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-gray-600">{user.phone}</td>
                  <td className="px-4 py-3">
                    <Badge color={roleBadgeColor(user.role)}>
                      {user.role}
                    </Badge>
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {user.rating_avg > 0
                      ? `${user.rating_avg} (${user.rating_count})`
                      : "—"}
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/${locale}/admin/users/${user.id}`}
                      className="text-primary font-medium hover:underline"
                    >
                      {t("users.view")}
                    </Link>
                  </td>
                </tr>
              ))}
              {users.length === 0 && (
                <tr>
                  <td
                    colSpan={6}
                    className="px-4 py-12 text-center text-gray-500"
                  >
                    {t("users.noResults")}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-gray-100 px-4 py-3">
            <span className="text-sm text-gray-500">
              {t("pagination.showing", {
                from: (page - 1) * 20 + 1,
                to: Math.min(page * 20, total),
                total,
              })}
            </span>
            <div className="flex gap-2">
              {page > 1 && (
                <Link
                  href={`/${locale}/admin/users?page=${page - 1}${sp.search ? `&search=${sp.search}` : ""}${sp.role ? `&role=${sp.role}` : ""}`}
                  className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
                >
                  {t("pagination.prev")}
                </Link>
              )}
              {page < totalPages && (
                <Link
                  href={`/${locale}/admin/users?page=${page + 1}${sp.search ? `&search=${sp.search}` : ""}${sp.role ? `&role=${sp.role}` : ""}`}
                  className="rounded-md bg-muted px-3 py-1.5 text-sm font-medium text-foreground hover:bg-gray-200"
                >
                  {t("pagination.next")}
                </Link>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
