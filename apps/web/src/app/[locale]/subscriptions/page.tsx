"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useParams } from "next/navigation";
import {
  Package,
  Calendar,
  Users,
  Star,
  Pause,
  Play,
  XCircle,
} from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui";
import {
  listSubscriptionPlans,
  getMySubscriptions,
  subscribeToPlan,
  pauseSubscription,
  resumeSubscription,
  cancelSubscription,
} from "@/lib/actions/subscriptions";
import type {
  SubscriptionPlanWithFarmer,
  SubscriptionWithPlan,
} from "@/lib/actions/subscriptions";
import type { Locale } from "@/lib/i18n";

const DAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

const DAYS_NE = [
  "आइतबार",
  "सोमबार",
  "मङ्गलबार",
  "बुधबार",
  "बिहिबार",
  "शुक्रबार",
  "शनिबार",
];

type TabKey = "browse" | "my";

export default function SubscriptionsPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const t = useTranslations("subscriptions");

  const [activeTab, setActiveTab] = useState<TabKey>("browse");
  const [plans, setPlans] = useState<SubscriptionPlanWithFarmer[]>([]);
  const [mySubscriptions, setMySubscriptions] = useState<SubscriptionWithPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionInProgress, setActionInProgress] = useState<string | null>(null);

  const dayNames = locale === "ne" ? DAYS_NE : DAYS;

  const loadData = async () => {
    setLoading(true);
    setError(null);

    const [plansResult, subsResult] = await Promise.all([
      listSubscriptionPlans(),
      getMySubscriptions(),
    ]);

    if (plansResult.error) {
      setError(plansResult.error);
    } else if (plansResult.data) {
      setPlans(plansResult.data);
    }

    if (subsResult.data) {
      setMySubscriptions(subsResult.data);
    }

    setLoading(false);
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial data load
    loadData();
  }, []);

  const subscribedPlanIds = new Set(
    mySubscriptions
      .filter((s) => s.status !== "cancelled")
      .map((s) => s.plan_id),
  );

  async function handleSubscribe(planId: string) {
    setActionInProgress(planId);
    setError(null);

    const result = await subscribeToPlan(planId, "cash");
    if (result.error) {
      setError(result.error);
    } else {
      await loadData();
    }
    setActionInProgress(null);
  }

  async function handlePause(subId: string) {
    setActionInProgress(subId);
    setError(null);

    const result = await pauseSubscription(subId);
    if (result.error) {
      setError(result.error);
    } else {
      await loadData();
    }
    setActionInProgress(null);
  }

  async function handleResume(subId: string) {
    setActionInProgress(subId);
    setError(null);

    const result = await resumeSubscription(subId);
    if (result.error) {
      setError(result.error);
    } else {
      await loadData();
    }
    setActionInProgress(null);
  }

  async function handleCancel(subId: string) {
    setActionInProgress(subId);
    setError(null);

    const result = await cancelSubscription(subId);
    if (result.error) {
      setError(result.error);
    } else {
      await loadData();
    }
    setActionInProgress(null);
  }

  const tabs: { key: TabKey; label: string }[] = [
    { key: "browse", label: t("tabs.browse") },
    { key: "my", label: t("tabs.my") },
  ];

  const activeSubscriptions = mySubscriptions.filter(
    (s) => s.status !== "cancelled",
  );

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
        <p className="mt-1 text-sm text-gray-500">{t("subtitle")}</p>

        {error && (
          <div className="mt-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Tabs */}
        <div className="mt-6 flex gap-1 rounded-lg bg-white p-1">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex-1 rounded-md px-4 py-2.5 text-sm font-medium transition-colors ${
                activeTab === tab.key
                  ? "bg-primary text-white"
                  : "text-gray-600 hover:bg-gray-100"
              }`}
            >
              {tab.label}
              {tab.key === "my" && activeSubscriptions.length > 0 && (
                <span className="ml-1.5 inline-flex h-5 w-5 items-center justify-center rounded-full bg-white/20 text-xs">
                  {activeSubscriptions.length}
                </span>
              )}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="py-12 text-center text-gray-500">
            {t("loading")}
          </div>
        ) : activeTab === "browse" ? (
          /* Browse plans */
          plans.length === 0 ? (
            <div className="py-12 text-center">
              <Package className="mx-auto h-12 w-12 text-gray-300" />
              <p className="mt-3 text-gray-500">{t("noPlans")}</p>
            </div>
          ) : (
            <div className="mt-4 space-y-4">
              {plans.map((plan) => (
                <BrowsePlanCard
                  key={plan.id}
                  plan={plan}
                  locale={locale}
                  dayNames={dayNames}
                  isSubscribed={subscribedPlanIds.has(plan.id)}
                  subscribing={actionInProgress === plan.id}
                  onSubscribe={() => handleSubscribe(plan.id)}
                />
              ))}
            </div>
          )
        ) : /* My subscriptions */
        activeSubscriptions.length === 0 ? (
          <div className="py-12 text-center">
            <Package className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-3 text-gray-500">{t("noSubscriptions")}</p>
            <Button
              variant="outline"
              className="mt-4"
              onClick={() => setActiveTab("browse")}
            >
              {t("browseButton")}
            </Button>
          </div>
        ) : (
          <div className="mt-4 space-y-4">
            {activeSubscriptions.map((sub) => (
              <MySubscriptionCard
                key={sub.id}
                subscription={sub}
                locale={locale}
                actionInProgress={actionInProgress === sub.id}
                onPause={() => handlePause(sub.id)}
                onResume={() => handleResume(sub.id)}
                onCancel={() => handleCancel(sub.id)}
              />
            ))}
          </div>
        )}
      </div>
    </main>
  );
}

function BrowsePlanCard({
  plan,
  locale,
  dayNames,
  isSubscribed,
  subscribing,
  onSubscribe,
}: {
  plan: SubscriptionPlanWithFarmer;
  locale: Locale;
  dayNames: string[];
  isSubscribed: boolean;
  subscribing: boolean;
  onSubscribe: () => void;
}) {
  const t = useTranslations("subscriptions");
  const name = locale === "ne" ? plan.name_ne : plan.name_en;
  const desc = locale === "ne" ? plan.description_ne : plan.description_en;

  const spotsLeft = plan.max_subscribers - plan.subscriber_count;
  const isFull = spotsLeft <= 0;

  return (
    <Card className="border-2 border-border">
      <div className="flex flex-col gap-3">
        <div className="flex items-start justify-between">
          <div>
            <h3 className="font-semibold text-foreground">{name}</h3>
            <p className="text-sm text-gray-500">
              {t("byFarmer", { name: plan.farmer.name })}
            </p>
          </div>
          <div className="text-right">
            <p className="text-lg font-bold text-foreground">
              NPR {Number(plan.price).toLocaleString()}
            </p>
            <p className="text-xs text-gray-500">
              /{t(`frequency.${plan.frequency}`)}
            </p>
          </div>
        </div>

        {desc && <p className="text-sm text-gray-600">{desc}</p>}

        {/* Box contents */}
        {plan.items.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {plan.items.map((item, i) => (
              <span
                key={i}
                className="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-medium text-emerald-700"
              >
                {locale === "ne" ? item.category_ne : item.category_en}{" "}
                (~{item.approx_kg}kg)
              </span>
            ))}
          </div>
        )}

        {/* Meta */}
        <div className="flex flex-wrap items-center gap-4 text-xs text-gray-500">
          <span className="flex items-center gap-1">
            <Calendar className="h-3.5 w-3.5" />
            {t("deliveryOn", { day: dayNames[plan.delivery_day] })}
          </span>
          <span className="flex items-center gap-1">
            <Users className="h-3.5 w-3.5" />
            {t("spotsLeft", { count: spotsLeft })}
          </span>
          {plan.farmer.rating_avg > 0 && (
            <span className="flex items-center gap-1">
              <Star className="h-3.5 w-3.5 text-amber-500" />
              {plan.farmer.rating_avg.toFixed(1)}
            </span>
          )}
        </div>

        {/* Subscribe button */}
        <div className="mt-1">
          {isSubscribed ? (
            <Badge color="success">{t("subscribed")}</Badge>
          ) : (
            <Button
              variant="primary"
              onClick={onSubscribe}
              disabled={isFull || subscribing}
              className="w-full"
            >
              {subscribing
                ? t("subscribing")
                : isFull
                  ? t("full")
                  : t("subscribe")}
            </Button>
          )}
        </div>
      </div>
    </Card>
  );
}

function MySubscriptionCard({
  subscription,
  locale,
  actionInProgress,
  onPause,
  onResume,
  onCancel,
}: {
  subscription: SubscriptionWithPlan;
  locale: Locale;
  actionInProgress: boolean;
  onPause: () => void;
  onResume: () => void;
  onCancel: () => void;
}) {
  const t = useTranslations("subscriptions");
  const plan = subscription.plan;
  const name = locale === "ne" ? plan.name_ne : plan.name_en;

  const deliveryDate = new Date(subscription.next_delivery_date).toLocaleDateString(
    locale === "ne" ? "ne-NP" : "en-US",
    { month: "short", day: "numeric", year: "numeric" },
  );

  const statusColors = {
    active: "success",
    paused: "warning",
    cancelled: "danger",
  } as const;

  return (
    <Card className="border-2 border-border">
      <div className="flex flex-col gap-3">
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-semibold text-foreground">{name}</h3>
              <Badge color={statusColors[subscription.status as keyof typeof statusColors] ?? "primary"}>
                {t(`status.${subscription.status}`)}
              </Badge>
            </div>
            <p className="text-sm text-gray-500">
              {t("byFarmer", { name: plan.farmer.name })}
            </p>
          </div>
          <p className="font-bold text-foreground">
            NPR {Number(plan.price).toLocaleString()}
          </p>
        </div>

        {/* Box contents */}
        {plan.items.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {plan.items.map((item, i) => (
              <span
                key={i}
                className="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-medium text-emerald-700"
              >
                {locale === "ne" ? item.category_ne : item.category_en}{" "}
                (~{item.approx_kg}kg)
              </span>
            ))}
          </div>
        )}

        {/* Next delivery */}
        {subscription.status === "active" && (
          <div className="flex items-center gap-2 rounded-md bg-blue-50 px-3 py-2 text-sm text-blue-700">
            <Calendar className="h-4 w-4" />
            {t("nextDelivery", { date: deliveryDate })}
          </div>
        )}

        {subscription.status === "paused" && (
          <div className="flex items-center gap-2 rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-700">
            <Pause className="h-4 w-4" />
            {t("pausedMessage")}
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-2">
          {subscription.status === "active" && (
            <>
              <button
                onClick={onPause}
                disabled={actionInProgress}
                className="inline-flex items-center gap-1 rounded-md bg-amber-100 px-3 py-2 text-sm font-medium text-amber-700 hover:bg-amber-200 transition-colors disabled:opacity-50"
              >
                <Pause className="h-4 w-4" />
                {t("pause")}
              </button>
              <button
                onClick={onCancel}
                disabled={actionInProgress}
                className="inline-flex items-center gap-1 rounded-md bg-red-100 px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-200 transition-colors disabled:opacity-50"
              >
                <XCircle className="h-4 w-4" />
                {t("cancel")}
              </button>
            </>
          )}
          {subscription.status === "paused" && (
            <>
              <button
                onClick={onResume}
                disabled={actionInProgress}
                className="inline-flex items-center gap-1 rounded-md bg-emerald-100 px-3 py-2 text-sm font-medium text-emerald-700 hover:bg-emerald-200 transition-colors disabled:opacity-50"
              >
                <Play className="h-4 w-4" />
                {t("resume")}
              </button>
              <button
                onClick={onCancel}
                disabled={actionInProgress}
                className="inline-flex items-center gap-1 rounded-md bg-red-100 px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-200 transition-colors disabled:opacity-50"
              >
                <XCircle className="h-4 w-4" />
                {t("cancel")}
              </button>
            </>
          )}
        </div>
      </div>
    </Card>
  );
}
