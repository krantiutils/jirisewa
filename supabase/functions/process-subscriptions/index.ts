import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

/**
 * Process subscription deliveries — create orders for active subscriptions
 * whose next_delivery_date is today.
 *
 * Intended to be called daily via pg_cron or an external scheduler:
 *   curl -X POST https://<project>.supabase.co/functions/v1/process-subscriptions \
 *     -H "Authorization: Bearer <service_role_key>"
 *
 * Flow:
 * 1. Find active subscriptions where next_delivery_date <= today
 * 2. For each, create a subscription_deliveries record
 * 3. Advance next_delivery_date based on frequency
 * 4. Send notification to farmer, consumer
 */

interface ActiveSubscription {
  id: string;
  plan_id: string;
  consumer_id: string;
  next_delivery_date: string;
  payment_method: string;
  plan: {
    id: string;
    farmer_id: string;
    name_en: string;
    name_ne: string;
    price: number;
    frequency: string;
    delivery_day: number;
    items: Array<{ category_en: string; category_ne: string; approx_kg: number }>;
  };
}

function advanceDeliveryDate(
  currentDate: string,
  frequency: string,
): string {
  const date = new Date(currentDate);
  switch (frequency) {
    case "weekly":
      date.setDate(date.getDate() + 7);
      break;
    case "biweekly":
      date.setDate(date.getDate() + 14);
      break;
    case "monthly":
      date.setMonth(date.getMonth() + 1);
      break;
    default:
      date.setDate(date.getDate() + 7);
  }
  return date.toISOString().split("T")[0];
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || authHeader !== `Bearer ${supabaseServiceKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const today = new Date().toISOString().split("T")[0];

  // Find active subscriptions due for delivery today or earlier
  const { data: subscriptions, error: fetchError } = await supabase
    .from("subscriptions")
    .select(
      "id, plan_id, consumer_id, next_delivery_date, payment_method, subscription_plans(id, farmer_id, name_en, name_ne, price, frequency, delivery_day, items)",
    )
    .eq("status", "active")
    .lte("next_delivery_date", today);

  if (fetchError) {
    console.error("Failed to fetch subscriptions:", fetchError);
    return new Response(
      JSON.stringify({ error: "Failed to fetch subscriptions" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!subscriptions || subscriptions.length === 0) {
    return new Response(
      JSON.stringify({ status: "ok", processed: 0, message: "No subscriptions due today" }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

  let processed = 0;
  const errors: string[] = [];

  for (const raw of subscriptions) {
    const sub = raw as unknown as ActiveSubscription;
    const plan = sub.plan;

    if (!plan) {
      errors.push(`Subscription ${sub.id}: plan not found`);
      continue;
    }

    try {
      // Create subscription_deliveries record
      const { error: deliveryError } = await supabase
        .from("subscription_deliveries")
        .insert({
          subscription_id: sub.id,
          scheduled_date: sub.next_delivery_date,
          actual_items: plan.items as unknown as Record<string, unknown>[],
          status: "scheduled",
        });

      if (deliveryError) {
        errors.push(`Subscription ${sub.id}: failed to create delivery — ${deliveryError.message}`);
        continue;
      }

      // Advance next_delivery_date
      const nextDate = advanceDeliveryDate(
        sub.next_delivery_date,
        plan.frequency,
      );

      const { error: updateError } = await supabase
        .from("subscriptions")
        .update({ next_delivery_date: nextDate })
        .eq("id", sub.id);

      if (updateError) {
        errors.push(`Subscription ${sub.id}: failed to update next_delivery_date — ${updateError.message}`);
        continue;
      }

      // Send notification to consumer
      try {
        await supabase.rpc("create_notification", {
          p_user_id: sub.consumer_id,
          p_category: "new_order_for_farmer",
          p_title_en: "Subscription Delivery Scheduled",
          p_title_ne: "सदस्यता डेलिभरी तालिका",
          p_body_en: `Your ${plan.name_en} box is scheduled for delivery on ${sub.next_delivery_date}.`,
          p_body_ne: `तपाईंको ${plan.name_ne} बाकस ${sub.next_delivery_date} मा डेलिभरीको लागि तालिका गरिएको छ।`,
          p_data: { subscription_id: sub.id, plan_id: plan.id },
        });
      } catch (notifErr) {
        // Non-critical — log but don't fail
        console.error(`Notification error for sub ${sub.id}:`, notifErr);
      }

      // Send notification to farmer
      try {
        await supabase.rpc("create_notification", {
          p_user_id: plan.farmer_id,
          p_category: "new_order_for_farmer",
          p_title_en: "Subscription Box to Prepare",
          p_title_ne: "तयार गर्नुपर्ने सदस्यता बाकस",
          p_body_en: `Please prepare a ${plan.name_en} box for delivery on ${sub.next_delivery_date}.`,
          p_body_ne: `कृपया ${sub.next_delivery_date} मा डेलिभरीको लागि ${plan.name_ne} बाकस तयार गर्नुहोस्।`,
          p_data: { subscription_id: sub.id, plan_id: plan.id },
        });
      } catch (notifErr) {
        console.error(`Farmer notification error for sub ${sub.id}:`, notifErr);
      }

      processed++;
    } catch (err) {
      errors.push(`Subscription ${sub.id}: unexpected error — ${err}`);
    }
  }

  return new Response(
    JSON.stringify({
      status: "ok",
      processed,
      total: subscriptions.length,
      errors: errors.length > 0 ? errors : undefined,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
