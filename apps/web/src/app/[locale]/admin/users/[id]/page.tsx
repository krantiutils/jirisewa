import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { requireAdmin } from "@/lib/admin/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { getUserRoles } from "@/lib/admin/queries";
import { Badge } from "@/components/ui";
import { notFound } from "next/navigation";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

export default async function AdminUserDetailPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale, id } = await params;
  setRequestLocale(locale);

  await requireAdmin(locale);
  const t = await getTranslations("admin");
  const supabase = await createSupabaseServerClient();

  const { data: user, error } = await supabase
    .from("users")
    .select(
      "id, phone, name, role, avatar_url, address, municipality, lang, rating_avg, rating_count, is_admin, created_at",
    )
    .eq("id", id)
    .single();

  if (error || !user) {
    notFound();
  }

  const roles = await getUserRoles(locale, id);

  // Get user's recent orders
  const { data: orders } = await supabase
    .from("orders")
    .select("id, status, total_price, delivery_fee, created_at")
    .or(`consumer_id.eq.${id},rider_id.eq.${id}`)
    .order("created_at", { ascending: false })
    .limit(10);

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
    <div className="mx-auto max-w-3xl">
      <Link
        href={`/${locale}/admin/users`}
        className="mb-4 inline-flex items-center gap-1 text-sm text-gray-500 hover:text-primary"
      >
        <ArrowLeft className="h-4 w-4" />
        {t("users.backToUsers")}
      </Link>

      {/* Profile header */}
      <div className="mb-6 rounded-lg bg-white p-6">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-2xl font-bold text-foreground">{user.name}</h1>
            <p className="mt-1 text-gray-500">{user.phone}</p>
            {user.address && (
              <p className="mt-1 text-sm text-gray-400">{user.address}</p>
            )}
            {user.municipality && (
              <p className="text-sm text-gray-400">{user.municipality}</p>
            )}
          </div>
          <div className="flex flex-col items-end gap-2">
            <Badge color={roleBadgeColor(user.role)}>{user.role}</Badge>
            {user.is_admin && <Badge color="danger">Admin</Badge>}
          </div>
        </div>
        <div className="mt-4 flex gap-6 text-sm text-gray-500">
          <span>
            {t("users.rating")}: {user.rating_avg > 0 ? `${user.rating_avg}/5 (${user.rating_count})` : "—"}
          </span>
          <span>
            {t("users.joined")}: {new Date(user.created_at).toLocaleDateString()}
          </span>
          <span>
            {t("users.language")}: {user.lang === "ne" ? "नेपाली" : "English"}
          </span>
        </div>
      </div>

      {/* Roles */}
      <div className="mb-6 rounded-lg bg-white p-6">
        <h2 className="mb-4 text-lg font-semibold text-foreground">
          {t("users.roles")}
        </h2>
        {roles.length === 0 ? (
          <p className="text-gray-500">{t("users.noRoles")}</p>
        ) : (
          <div className="space-y-3">
            {roles.map((role) => (
              <div
                key={role.id}
                className="flex items-center justify-between rounded-md bg-gray-50 p-4"
              >
                <div>
                  <div className="flex items-center gap-2">
                    <Badge color={roleBadgeColor(role.role)}>
                      {role.role}
                    </Badge>
                    {role.verified ? (
                      <Badge color="success">{t("users.verified")}</Badge>
                    ) : (
                      <Badge color="warning">{t("users.unverified")}</Badge>
                    )}
                  </div>
                  {role.farm_name && (
                    <p className="mt-1 text-sm text-gray-500">
                      {t("users.farmName")}: {role.farm_name}
                    </p>
                  )}
                  {role.vehicle_type && (
                    <p className="mt-1 text-sm text-gray-500">
                      {t("users.vehicle")}: {role.vehicle_type}{" "}
                      {role.vehicle_capacity_kg
                        ? `(${role.vehicle_capacity_kg} kg)`
                        : ""}
                    </p>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Recent orders */}
      <div className="rounded-lg bg-white p-6">
        <h2 className="mb-4 text-lg font-semibold text-foreground">
          {t("users.recentOrders")}
        </h2>
        {!orders || orders.length === 0 ? (
          <p className="text-gray-500">{t("users.noOrders")}</p>
        ) : (
          <div className="space-y-2">
            {orders.map((order) => (
              <Link
                key={order.id}
                href={`/${locale}/admin/orders/${order.id}`}
                className="flex items-center justify-between rounded-md bg-gray-50 p-3 hover:bg-gray-100 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <Badge
                    color={
                      order.status === "delivered"
                        ? "success"
                        : order.status === "cancelled"
                          ? "danger"
                          : order.status === "disputed"
                            ? "warning"
                            : "primary"
                    }
                  >
                    {order.status}
                  </Badge>
                  <span className="text-sm text-gray-500">
                    {new Date(order.created_at).toLocaleDateString()}
                  </span>
                </div>
                <span className="font-medium text-foreground">
                  NPR {Number(order.total_price).toLocaleString()}
                </span>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
