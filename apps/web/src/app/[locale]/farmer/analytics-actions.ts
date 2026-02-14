"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type ActionResult<T> =
  | { success: true; data: T }
  | { success: false; error: string };

async function getAuthenticatedFarmer() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    return { supabase, user: null, error: "Not authenticated" } as const;
  }

  const { data: userRole } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", user.id)
    .eq("role", "farmer")
    .single();

  if (!userRole) {
    return { supabase, user: null, error: "Not a farmer" } as const;
  }

  return { supabase, user, error: null } as const;
}

export type SalesByCategory = {
  category_id: string;
  category_name_en: string;
  category_name_ne: string;
  category_icon: string | null;
  total_qty_kg: number;
  total_revenue: number;
  order_count: number;
};

export type RevenueTrend = {
  day: string;
  revenue: number;
  order_count: number;
};

export type TopProduct = {
  listing_id: string;
  name_en: string;
  name_ne: string;
  category_name_en: string;
  total_qty_kg: number;
  total_revenue: number;
  order_count: number;
};

export type PriceBenchmark = {
  category_id: string;
  category_name_en: string;
  category_name_ne: string;
  my_avg_price: number;
  market_avg_price: number;
  my_listing_count: number;
  market_listing_count: number;
};

export type FulfillmentRate = {
  total_orders: number;
  delivered: number;
  cancelled: number;
  fulfillment_pct: number;
};

export type RatingDistribution = {
  score: number;
  count: number;
};

export type AnalyticsData = {
  salesByCategory: SalesByCategory[];
  revenueTrend: RevenueTrend[];
  topProducts: TopProduct[];
  priceBenchmarks: PriceBenchmark[];
  fulfillment: FulfillmentRate;
  ratingDistribution: RatingDistribution[];
  ratingAvg: number;
  ratingCount: number;
};

export async function getFarmerAnalytics(
  days: number = 30,
): Promise<ActionResult<AnalyticsData>> {
  const { supabase, user, error: authError } = await getAuthenticatedFarmer();
  if (!user) {
    return { success: false, error: authError };
  }

  const [
    salesResult,
    revenueResult,
    topProductsResult,
    benchmarkResult,
    fulfillmentResult,
    ratingResult,
    userResult,
  ] = await Promise.all([
    supabase.rpc("farmer_sales_by_category", {
      p_farmer_id: user.id,
      p_days: days,
    }),
    supabase.rpc("farmer_revenue_trend", {
      p_farmer_id: user.id,
      p_days: days,
    }),
    supabase.rpc("farmer_top_products", {
      p_farmer_id: user.id,
      p_days: days,
      p_limit: 10,
    }),
    supabase.rpc("farmer_price_benchmarks", {
      p_farmer_id: user.id,
    }),
    supabase.rpc("farmer_fulfillment_rate", {
      p_farmer_id: user.id,
      p_days: days,
    }),
    supabase.rpc("farmer_rating_distribution", {
      p_farmer_id: user.id,
    }),
    supabase
      .from("users")
      .select("rating_avg, rating_count")
      .eq("id", user.id)
      .single(),
  ]);

  if (salesResult.error) {
    return { success: false, error: salesResult.error.message };
  }
  if (revenueResult.error) {
    return { success: false, error: revenueResult.error.message };
  }
  if (topProductsResult.error) {
    return { success: false, error: topProductsResult.error.message };
  }
  if (benchmarkResult.error) {
    return { success: false, error: benchmarkResult.error.message };
  }
  if (fulfillmentResult.error) {
    return { success: false, error: fulfillmentResult.error.message };
  }
  if (ratingResult.error) {
    return { success: false, error: ratingResult.error.message };
  }

  const fulfillmentRow = (fulfillmentResult.data as FulfillmentRate[])?.[0] ?? {
    total_orders: 0,
    delivered: 0,
    cancelled: 0,
    fulfillment_pct: 0,
  };

  return {
    success: true,
    data: {
      salesByCategory: salesResult.data as SalesByCategory[],
      revenueTrend: revenueResult.data as RevenueTrend[],
      topProducts: topProductsResult.data as TopProduct[],
      priceBenchmarks: benchmarkResult.data as PriceBenchmark[],
      fulfillment: fulfillmentRow,
      ratingDistribution: ratingResult.data as RatingDistribution[],
      ratingAvg: userResult.data?.rating_avg ?? 0,
      ratingCount: userResult.data?.rating_count ?? 0,
    },
  };
}
