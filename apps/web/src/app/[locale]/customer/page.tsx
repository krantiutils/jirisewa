import { setRequestLocale } from "next-intl/server";
import Link from "next/link";
import { listOrders } from "@/lib/actions/orders";
import { fetchProduceListings } from "@/lib/queries/produce";
import {
  ShoppingBag,
  ClipboardList,
  Wallet,
  PackageCheck,
  ArrowRight,
} from "lucide-react";

export const dynamic = "force-dynamic";

interface StatCardProps {
  label: string;
  value: number | string;
  icon: typeof Wallet;
  color: string;
}
function StatCard({ label, value, icon: Icon, color }: StatCardProps) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-5">
      <div className="flex items-center gap-3">
        <div className={`flex h-10 w-10 items-center justify-center rounded-lg ${color}`}>
          <Icon className="h-5 w-5 text-white" />
        </div>
        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-gray-500">{label}</p>
          <p className="text-2xl font-bold text-foreground">{value}</p>
        </div>
      </div>
    </div>
  );
}

const STATUS_LABEL: Record<string, string> = {
  pending: "Pending",
  matched: "Rider matched",
  picked_up: "Picked up",
  in_transit: "On the way",
  delivered: "Delivered",
  cancelled: "Cancelled",
  disputed: "Disputed",
};

const ACTIVE_STATUSES = ["pending", "matched", "picked_up", "in_transit"];

export default async function CustomerDashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const ordersRes = await listOrders();
  const orders = ordersRes.data ?? [];

  const open = orders.filter((o) => ACTIVE_STATUSES.includes(o.status)).length;
  const delivered = orders.filter((o) => o.status === "delivered").length;
  const totalSpent = orders
    .filter((o) => o.status !== "cancelled")
    .reduce((sum, o) => sum + Number(o.total_price ?? 0), 0);

  const recent = orders.slice(0, 5);

  // Fresh recommendations
  let recommended: Awaited<ReturnType<typeof fetchProduceListings>>["listings"] = [];
  try {
    const r = await fetchProduceListings({ sort_by: "freshness" });
    recommended = r.listings.slice(0, 4);
  } catch {
    /* ignore */
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Welcome back</h1>
          <p className="text-sm text-gray-500">
            Your fresh produce orders and what&rsquo;s new at the market.
          </p>
        </div>
        <Link
          href={`/${locale}/marketplace`}
          className="inline-flex items-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90"
        >
          <ShoppingBag className="h-4 w-4" />
          Browse market
        </Link>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-3">
        <StatCard
          label="Open orders"
          value={open}
          icon={ClipboardList}
          color="bg-blue-500"
        />
        <StatCard
          label="Delivered"
          value={delivered}
          icon={PackageCheck}
          color="bg-emerald-500"
        />
        <StatCard
          label="Total spent"
          value={`NPR ${totalSpent.toFixed(0)}`}
          icon={Wallet}
          color="bg-amber-500"
        />
      </div>

      {/* Recent orders */}
      <div className="rounded-xl border border-gray-200 bg-white">
        <div className="flex items-center justify-between border-b border-gray-100 px-5 py-3">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
            Recent orders
          </h2>
          <Link
            href={`/${locale}/orders`}
            className="inline-flex items-center gap-1 text-sm font-medium text-primary hover:text-primary/80"
          >
            See all <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
        {recent.length === 0 ? (
          <div className="px-5 py-6 text-sm text-gray-500">
            No orders yet.{" "}
            <Link href={`/${locale}/marketplace`} className="text-primary">
              Start shopping →
            </Link>
          </div>
        ) : (
          <ul className="divide-y divide-gray-100">
            {recent.map((o) => {
              const itemSummary = o.items
                .map((it) => `${it.quantity_kg} kg ${it.listing?.name_en ?? "produce"}`)
                .join(", ");
              return (
                <li key={o.id} className="flex items-center justify-between px-5 py-3">
                  <Link
                    href={`/${locale}/orders/${o.id}`}
                    className="flex-1 text-sm hover:text-primary"
                  >
                    <span className="font-medium">{itemSummary || "Order"}</span>
                    <span className="ml-2 text-gray-500">
                      · {new Date(o.created_at).toLocaleDateString()}
                    </span>
                  </Link>
                  <span className="ml-3 text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {STATUS_LABEL[o.status] ?? o.status}
                  </span>
                  <span className="ml-3 w-24 text-right text-sm font-semibold">
                    NPR {Number(o.total_price ?? 0).toFixed(0)}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      {/* Recommended produce */}
      {recommended.length > 0 && (
        <div className="rounded-xl border border-gray-200 bg-white">
          <div className="flex items-center justify-between border-b border-gray-100 px-5 py-3">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-500">
              Fresh from the farm
            </h2>
            <Link
              href={`/${locale}/marketplace`}
              className="inline-flex items-center gap-1 text-sm font-medium text-primary hover:text-primary/80"
            >
              Browse all <ArrowRight className="h-4 w-4" />
            </Link>
          </div>
          <div className="grid gap-4 p-5 sm:grid-cols-2 lg:grid-cols-4">
            {recommended.map((p) => (
              <Link
                key={p.id}
                href={`/${locale}/produce/${p.id}`}
                className="rounded-lg border border-gray-100 p-3 hover:border-primary"
              >
                <p className="font-semibold">{p.name_en}</p>
                <p className="text-xs text-gray-500">
                  {p.available_qty_kg} kg available
                </p>
                <p className="mt-1 text-sm font-bold text-primary">
                  NPR {Number(p.price_per_kg).toFixed(0)} / kg
                </p>
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
