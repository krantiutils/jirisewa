"use server";

import { SubscriptionStatus } from "@jirisewa/shared";
import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";

// TODO: Replace hardcoded consumer ID with authenticated user once auth is implemented
const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";
const DEMO_FARMER_ID = "00000000-0000-0000-0000-000000000002";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SubscriptionPlanItem {
  category_en: string;
  category_ne: string;
  approx_kg: number;
}

export interface SubscriptionPlanWithFarmer {
  id: string;
  farmer_id: string;
  name_en: string;
  name_ne: string;
  description_en: string | null;
  description_ne: string | null;
  price: number;
  frequency: "weekly" | "biweekly" | "monthly";
  items: SubscriptionPlanItem[];
  max_subscribers: number;
  delivery_day: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  farmer: {
    id: string;
    name: string;
    avatar_url: string | null;
    rating_avg: number;
    rating_count: number;
  };
  subscriber_count: number;
}

export interface SubscriptionWithPlan {
  id: string;
  plan_id: string;
  consumer_id: string;
  status: "active" | "paused" | "cancelled";
  next_delivery_date: string;
  payment_method: "cash" | "esewa" | "khalti";
  created_at: string;
  updated_at: string;
  paused_at: string | null;
  cancelled_at: string | null;
  plan: {
    id: string;
    name_en: string;
    name_ne: string;
    description_en: string | null;
    description_ne: string | null;
    price: number;
    frequency: "weekly" | "biweekly" | "monthly";
    items: SubscriptionPlanItem[];
    delivery_day: number;
    farmer: {
      id: string;
      name: string;
      avatar_url: string | null;
    };
  };
}

export interface CreatePlanInput {
  name_en: string;
  name_ne: string;
  description_en: string;
  description_ne: string;
  price: number;
  frequency: "weekly" | "biweekly" | "monthly";
  items: SubscriptionPlanItem[];
  max_subscribers: number;
  delivery_day: number;
}

// ---------------------------------------------------------------------------
// Farmer: Manage subscription plans
// ---------------------------------------------------------------------------

export async function getFarmerSubscriptionPlans(): Promise<
  ActionResult<SubscriptionPlanWithFarmer[]>
> {
  try {
    const supabase = createServiceRoleClient();
    const farmerId = DEMO_FARMER_ID;

    const { data: plans, error } = await supabase
      .from("subscription_plans")
      .select("*")
      .eq("farmer_id", farmerId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("getFarmerSubscriptionPlans: query failed:", error);
      return { error: "Failed to load subscription plans" };
    }

    // Get subscriber counts for each plan
    const planIds = (plans ?? []).map((p: { id: string }) => p.id);
    let subscriberCounts: Record<string, number> = {};

    if (planIds.length > 0) {
      const { data: subs } = await supabase
        .from("subscriptions")
        .select("plan_id")
        .in("plan_id", planIds)
        .neq("status", SubscriptionStatus.Cancelled);

      if (subs) {
        subscriberCounts = subs.reduce(
          (acc: Record<string, number>, s: { plan_id: string }) => {
            acc[s.plan_id] = (acc[s.plan_id] || 0) + 1;
            return acc;
          },
          {},
        );
      }
    }

    // Get farmer info
    const { data: farmer } = await supabase
      .from("users")
      .select("id, name, avatar_url, rating_avg, rating_count")
      .eq("id", farmerId)
      .single();

    const result = (plans ?? []).map(
      (plan: Record<string, unknown>) => ({
        ...plan,
        items: (plan.items as SubscriptionPlanItem[]) ?? [],
        farmer: farmer ?? {
          id: farmerId,
          name: "Unknown",
          avatar_url: null,
          rating_avg: 0,
          rating_count: 0,
        },
        subscriber_count: subscriberCounts[plan.id as string] || 0,
      }),
    );

    return { data: result as SubscriptionPlanWithFarmer[] };
  } catch (err) {
    console.error("getFarmerSubscriptionPlans: unexpected error:", err);
    return { error: "Unexpected error loading plans" };
  }
}

export async function createSubscriptionPlan(
  input: CreatePlanInput,
): Promise<ActionResult<{ id: string }>> {
  try {
    if (!input.name_en || !input.name_ne) {
      return { error: "Plan name is required in both languages" };
    }

    if (input.price <= 0) {
      return { error: "Price must be greater than 0" };
    }

    if (input.max_subscribers <= 0) {
      return { error: "Max subscribers must be greater than 0" };
    }

    if (input.delivery_day < 0 || input.delivery_day > 6) {
      return { error: "Invalid delivery day (0=Sunday, 6=Saturday)" };
    }

    const supabase = createServiceRoleClient();
    const farmerId = DEMO_FARMER_ID;

    const { data, error } = await supabase
      .from("subscription_plans")
      .insert({
        farmer_id: farmerId,
        name_en: input.name_en,
        name_ne: input.name_ne,
        description_en: input.description_en || null,
        description_ne: input.description_ne || null,
        price: input.price,
        frequency: input.frequency,
        items: input.items as unknown as Record<string, unknown>[],
        max_subscribers: input.max_subscribers,
        delivery_day: input.delivery_day,
      })
      .select("id")
      .single();

    if (error) {
      console.error("createSubscriptionPlan: insert failed:", error);
      return { error: "Failed to create subscription plan" };
    }

    return { data: { id: (data as { id: string }).id } };
  } catch (err) {
    console.error("createSubscriptionPlan: unexpected error:", err);
    return { error: "Unexpected error creating plan" };
  }
}

export async function toggleSubscriptionPlan(
  planId: string,
  isActive: boolean,
): Promise<ActionResult<void>> {
  try {
    const supabase = createServiceRoleClient();
    const farmerId = DEMO_FARMER_ID;

    const { error } = await supabase
      .from("subscription_plans")
      .update({ is_active: isActive })
      .eq("id", planId)
      .eq("farmer_id", farmerId);

    if (error) {
      console.error("toggleSubscriptionPlan: update failed:", error);
      return { error: "Failed to update plan" };
    }

    return { data: undefined };
  } catch (err) {
    console.error("toggleSubscriptionPlan: unexpected error:", err);
    return { error: "Unexpected error updating plan" };
  }
}

// ---------------------------------------------------------------------------
// Consumer: Browse & manage subscriptions
// ---------------------------------------------------------------------------

export async function listSubscriptionPlans(): Promise<
  ActionResult<SubscriptionPlanWithFarmer[]>
> {
  try {
    const supabase = createServiceRoleClient();

    const { data: plans, error } = await supabase
      .from("subscription_plans")
      .select("*")
      .eq("is_active", true)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("listSubscriptionPlans: query failed:", error);
      return { error: "Failed to load subscription plans" };
    }

    // Get farmer info and subscriber counts
    const farmerIds = [...new Set((plans ?? []).map((p: { farmer_id: string }) => p.farmer_id))];
    const planIds = (plans ?? []).map((p: { id: string }) => p.id);

    const [farmersResult, subsResult] = await Promise.all([
      farmerIds.length > 0
        ? supabase
            .from("users")
            .select("id, name, avatar_url, rating_avg, rating_count")
            .in("id", farmerIds)
        : Promise.resolve({ data: [] }),
      planIds.length > 0
        ? supabase
            .from("subscriptions")
            .select("plan_id")
            .in("plan_id", planIds)
            .neq("status", SubscriptionStatus.Cancelled)
        : Promise.resolve({ data: [] }),
    ]);

    const farmerMap = new Map(
      (farmersResult.data ?? []).map((f: { id: string }) => [f.id, f]),
    );

    const subscriberCounts = (subsResult.data ?? []).reduce(
      (acc: Record<string, number>, s: { plan_id: string }) => {
        acc[s.plan_id] = (acc[s.plan_id] || 0) + 1;
        return acc;
      },
      {} as Record<string, number>,
    );

    const result = (plans ?? []).map(
      (plan: Record<string, unknown>) => ({
        ...plan,
        items: (plan.items as SubscriptionPlanItem[]) ?? [],
        farmer: farmerMap.get(plan.farmer_id as string) ?? {
          id: plan.farmer_id,
          name: "Unknown",
          avatar_url: null,
          rating_avg: 0,
          rating_count: 0,
        },
        subscriber_count: subscriberCounts[plan.id as string] || 0,
      }),
    );

    return { data: result as SubscriptionPlanWithFarmer[] };
  } catch (err) {
    console.error("listSubscriptionPlans: unexpected error:", err);
    return { error: "Unexpected error loading plans" };
  }
}

export async function getMySubscriptions(): Promise<
  ActionResult<SubscriptionWithPlan[]>
> {
  try {
    const supabase = createServiceRoleClient();
    const consumerId = DEMO_CONSUMER_ID;

    const { data: subs, error } = await supabase
      .from("subscriptions")
      .select(
        "*, subscription_plans(id, name_en, name_ne, description_en, description_ne, price, frequency, items, delivery_day, farmer_id)",
      )
      .eq("consumer_id", consumerId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("getMySubscriptions: query failed:", error);
      return { error: "Failed to load subscriptions" };
    }

    // Get farmer info for each plan
    const farmerIds = [
      ...new Set(
        (subs ?? [])
          .map((s: Record<string, unknown>) => {
            const plan = s.subscription_plans as Record<string, unknown> | null;
            return plan?.farmer_id as string | undefined;
          })
          .filter(Boolean),
      ),
    ];

    let farmerMap = new Map();
    if (farmerIds.length > 0) {
      const { data: farmers } = await supabase
        .from("users")
        .select("id, name, avatar_url")
        .in("id", farmerIds);

      if (farmers) {
        farmerMap = new Map(
          farmers.map((f: { id: string }) => [f.id, f]),
        );
      }
    }

    const result = (subs ?? []).map((sub: Record<string, unknown>) => {
      const plan = sub.subscription_plans as Record<string, unknown>;
      const farmer = farmerMap.get(plan?.farmer_id as string) ?? {
        id: plan?.farmer_id,
        name: "Unknown",
        avatar_url: null,
      };

      return {
        id: sub.id,
        plan_id: sub.plan_id,
        consumer_id: sub.consumer_id,
        status: sub.status,
        next_delivery_date: sub.next_delivery_date,
        payment_method: sub.payment_method,
        created_at: sub.created_at,
        updated_at: sub.updated_at,
        paused_at: sub.paused_at,
        cancelled_at: sub.cancelled_at,
        plan: {
          ...plan,
          items: (plan?.items as SubscriptionPlanItem[]) ?? [],
          farmer,
        },
      };
    });

    return { data: result as SubscriptionWithPlan[] };
  } catch (err) {
    console.error("getMySubscriptions: unexpected error:", err);
    return { error: "Unexpected error loading subscriptions" };
  }
}

function getNextDeliveryDate(deliveryDay: number): string {
  const now = new Date();
  const currentDay = now.getDay();
  let daysUntil = deliveryDay - currentDay;
  if (daysUntil <= 0) daysUntil += 7;
  const nextDate = new Date(now);
  nextDate.setDate(now.getDate() + daysUntil);
  return nextDate.toISOString().split("T")[0];
}

export async function subscribeToPlan(
  planId: string,
  paymentMethod: "cash" | "esewa" | "khalti",
): Promise<ActionResult<{ id: string }>> {
  try {
    const supabase = createServiceRoleClient();
    const consumerId = DEMO_CONSUMER_ID;

    // Verify plan exists and is active
    const { data: plan, error: planError } = await supabase
      .from("subscription_plans")
      .select("id, max_subscribers, delivery_day, is_active")
      .eq("id", planId)
      .single();

    if (planError || !plan) {
      return { error: "Subscription plan not found" };
    }

    if (!(plan as { is_active: boolean }).is_active) {
      return { error: "This plan is no longer accepting subscribers" };
    }

    // Check subscriber cap
    const { count } = await supabase
      .from("subscriptions")
      .select("id", { count: "exact", head: true })
      .eq("plan_id", planId)
      .neq("status", SubscriptionStatus.Cancelled);

    if (
      count !== null &&
      count >= (plan as { max_subscribers: number }).max_subscribers
    ) {
      return { error: "This plan has reached its maximum number of subscribers" };
    }

    // Check for existing active subscription to same plan
    const { data: existing } = await supabase
      .from("subscriptions")
      .select("id, status")
      .eq("plan_id", planId)
      .eq("consumer_id", consumerId)
      .neq("status", SubscriptionStatus.Cancelled)
      .maybeSingle();

    if (existing) {
      return { error: "You already have an active subscription to this plan" };
    }

    const nextDeliveryDate = getNextDeliveryDate(
      (plan as { delivery_day: number }).delivery_day,
    );

    const { data, error } = await supabase
      .from("subscriptions")
      .insert({
        plan_id: planId,
        consumer_id: consumerId,
        status: "active",
        next_delivery_date: nextDeliveryDate,
        payment_method: paymentMethod,
      })
      .select("id")
      .single();

    if (error) {
      console.error("subscribeToPlan: insert failed:", error);
      return { error: "Failed to create subscription" };
    }

    return { data: { id: (data as { id: string }).id } };
  } catch (err) {
    console.error("subscribeToPlan: unexpected error:", err);
    return { error: "Unexpected error subscribing" };
  }
}

export async function pauseSubscription(
  subscriptionId: string,
): Promise<ActionResult<void>> {
  try {
    const supabase = createServiceRoleClient();
    const consumerId = DEMO_CONSUMER_ID;

    const { error } = await supabase
      .from("subscriptions")
      .update({
        status: SubscriptionStatus.Paused,
        paused_at: new Date().toISOString(),
      })
      .eq("id", subscriptionId)
      .eq("consumer_id", consumerId)
      .eq("status", SubscriptionStatus.Active);

    if (error) {
      console.error("pauseSubscription: update failed:", error);
      return { error: "Failed to pause subscription" };
    }

    return { data: undefined };
  } catch (err) {
    console.error("pauseSubscription: unexpected error:", err);
    return { error: "Unexpected error pausing subscription" };
  }
}

export async function resumeSubscription(
  subscriptionId: string,
): Promise<ActionResult<void>> {
  try {
    const supabase = createServiceRoleClient();
    const consumerId = DEMO_CONSUMER_ID;

    // Get plan delivery_day to recalculate next delivery
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("plan_id, subscription_plans(delivery_day)")
      .eq("id", subscriptionId)
      .eq("consumer_id", consumerId)
      .single();

    if (!sub) {
      return { error: "Subscription not found" };
    }

    const plan = (sub as Record<string, unknown>).subscription_plans as {
      delivery_day: number;
    };
    const nextDeliveryDate = getNextDeliveryDate(plan.delivery_day);

    const { error } = await supabase
      .from("subscriptions")
      .update({
        status: SubscriptionStatus.Active,
        paused_at: null,
        next_delivery_date: nextDeliveryDate,
      })
      .eq("id", subscriptionId)
      .eq("consumer_id", consumerId)
      .eq("status", SubscriptionStatus.Paused);

    if (error) {
      console.error("resumeSubscription: update failed:", error);
      return { error: "Failed to resume subscription" };
    }

    return { data: undefined };
  } catch (err) {
    console.error("resumeSubscription: unexpected error:", err);
    return { error: "Unexpected error resuming subscription" };
  }
}

export async function cancelSubscription(
  subscriptionId: string,
): Promise<ActionResult<void>> {
  try {
    const supabase = createServiceRoleClient();
    const consumerId = DEMO_CONSUMER_ID;

    const { error } = await supabase
      .from("subscriptions")
      .update({
        status: SubscriptionStatus.Cancelled,
        cancelled_at: new Date().toISOString(),
      })
      .eq("id", subscriptionId)
      .eq("consumer_id", consumerId)
      .neq("status", SubscriptionStatus.Cancelled);

    if (error) {
      console.error("cancelSubscription: update failed:", error);
      return { error: "Failed to cancel subscription" };
    }

    return { data: undefined };
  } catch (err) {
    console.error("cancelSubscription: unexpected error:", err);
    return { error: "Unexpected error cancelling subscription" };
  }
}
