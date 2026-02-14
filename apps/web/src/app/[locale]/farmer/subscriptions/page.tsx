"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useParams } from "next/navigation";
import { Package, Plus, Users, Calendar, Pause, Play, X } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui";
import {
  getFarmerSubscriptionPlans,
  createSubscriptionPlan,
  toggleSubscriptionPlan,
} from "@/lib/actions/subscriptions";
import type {
  SubscriptionPlanWithFarmer,
  CreatePlanInput,
  SubscriptionPlanItem,
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

export default function FarmerSubscriptionsPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const t = useTranslations("farmerSubscriptions");

  const [plans, setPlans] = useState<SubscriptionPlanWithFarmer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [creating, setCreating] = useState(false);

  // Form state
  const [nameEn, setNameEn] = useState("");
  const [nameNe, setNameNe] = useState("");
  const [descEn, setDescEn] = useState("");
  const [descNe, setDescNe] = useState("");
  const [price, setPrice] = useState("");
  const [frequency, setFrequency] = useState<"weekly" | "biweekly" | "monthly">("weekly");
  const [maxSubscribers, setMaxSubscribers] = useState("50");
  const [deliveryDay, setDeliveryDay] = useState("6"); // Saturday
  const [items, setItems] = useState<SubscriptionPlanItem[]>([
    { category_en: "", category_ne: "", approx_kg: 0 },
  ]);

  const loadPlans = async () => {
    setLoading(true);
    setError(null);
    const result = await getFarmerSubscriptionPlans();
    if (result.error) {
      setError(result.error);
    } else if (result.data) {
      setPlans(result.data);
    }
    setLoading(false);
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial data load
    loadPlans();
  }, []);

  function resetForm() {
    setNameEn("");
    setNameNe("");
    setDescEn("");
    setDescNe("");
    setPrice("");
    setFrequency("weekly");
    setMaxSubscribers("50");
    setDeliveryDay("6");
    setItems([{ category_en: "", category_ne: "", approx_kg: 0 }]);
  }

  async function handleCreate() {
    if (!nameEn || !nameNe) {
      setError(t("errors.nameRequired"));
      return;
    }
    const priceNum = parseFloat(price);
    if (isNaN(priceNum) || priceNum <= 0) {
      setError(t("errors.priceInvalid"));
      return;
    }

    const validItems = items.filter((item) => item.category_en && item.approx_kg > 0);

    setCreating(true);
    setError(null);

    const input: CreatePlanInput = {
      name_en: nameEn,
      name_ne: nameNe,
      description_en: descEn,
      description_ne: descNe,
      price: priceNum,
      frequency,
      items: validItems,
      max_subscribers: parseInt(maxSubscribers) || 50,
      delivery_day: parseInt(deliveryDay),
    };

    const result = await createSubscriptionPlan(input);
    if (result.error) {
      setError(result.error);
    } else {
      setShowCreateForm(false);
      resetForm();
      await loadPlans();
    }
    setCreating(false);
  }

  async function handleToggle(planId: string, isActive: boolean) {
    const result = await toggleSubscriptionPlan(planId, !isActive);
    if (result.error) {
      setError(result.error);
    } else {
      await loadPlans();
    }
  }

  function addItem() {
    setItems([...items, { category_en: "", category_ne: "", approx_kg: 0 }]);
  }

  function removeItem(index: number) {
    setItems(items.filter((_, i) => i !== index));
  }

  function updateItem(index: number, field: keyof SubscriptionPlanItem, value: string | number) {
    const updated = [...items];
    if (field === "approx_kg") {
      updated[index] = { ...updated[index], [field]: parseFloat(value as string) || 0 };
    } else {
      updated[index] = { ...updated[index], [field]: value };
    }
    setItems(updated);
  }

  const dayNames = locale === "ne" ? DAYS_NE : DAYS;

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6">
        {/* Header */}
        <div className="mb-8 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-foreground">
            {t("title")}
          </h1>
          <Button
            variant="primary"
            onClick={() => setShowCreateForm(!showCreateForm)}
          >
            <Plus className="mr-2 h-5 w-5" />
            {t("createPlan")}
          </Button>
        </div>

        {error && (
          <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Create form */}
        {showCreateForm && (
          <div className="mb-8 rounded-lg bg-white p-6">
            <h2 className="mb-4 text-lg font-semibold text-foreground">
              {t("newPlan")}
            </h2>

            <div className="space-y-4">
              {/* Names */}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("nameEn")}
                  </label>
                  <input
                    type="text"
                    value={nameEn}
                    onChange={(e) => setNameEn(e.target.value)}
                    placeholder={t("nameEnPlaceholder")}
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("nameNe")}
                  </label>
                  <input
                    type="text"
                    value={nameNe}
                    onChange={(e) => setNameNe(e.target.value)}
                    placeholder={t("nameNePlaceholder")}
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  />
                </div>
              </div>

              {/* Descriptions */}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("descriptionEn")}
                  </label>
                  <textarea
                    value={descEn}
                    onChange={(e) => setDescEn(e.target.value)}
                    placeholder={t("descriptionPlaceholder")}
                    rows={2}
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("descriptionNe")}
                  </label>
                  <textarea
                    value={descNe}
                    onChange={(e) => setDescNe(e.target.value)}
                    placeholder={t("descriptionPlaceholder")}
                    rows={2}
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  />
                </div>
              </div>

              {/* Price, frequency, max subscribers, delivery day */}
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("price")}
                  </label>
                  <input
                    type="number"
                    value={price}
                    onChange={(e) => setPrice(e.target.value)}
                    placeholder="500"
                    min="1"
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("frequency")}
                  </label>
                  <select
                    value={frequency}
                    onChange={(e) => setFrequency(e.target.value as "weekly" | "biweekly" | "monthly")}
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  >
                    <option value="weekly">{t("frequencyWeekly")}</option>
                    <option value="biweekly">{t("frequencyBiweekly")}</option>
                    <option value="monthly">{t("frequencyMonthly")}</option>
                  </select>
                </div>
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("maxSubscribers")}
                  </label>
                  <input
                    type="number"
                    value={maxSubscribers}
                    onChange={(e) => setMaxSubscribers(e.target.value)}
                    min="1"
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("deliveryDay")}
                  </label>
                  <select
                    value={deliveryDay}
                    onChange={(e) => setDeliveryDay(e.target.value)}
                    className="mt-1 w-full rounded-md bg-gray-100 px-3 py-2.5 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                  >
                    {dayNames.map((day, i) => (
                      <option key={i} value={i}>
                        {day}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Box items */}
              <div>
                <div className="flex items-center justify-between">
                  <label className="text-xs font-semibold uppercase tracking-wider text-gray-500">
                    {t("boxItems")}
                  </label>
                  <button
                    type="button"
                    onClick={addItem}
                    className="text-sm font-medium text-primary hover:underline"
                  >
                    + {t("addItem")}
                  </button>
                </div>
                <div className="mt-2 space-y-2">
                  {items.map((item, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <input
                        type="text"
                        value={item.category_en}
                        onChange={(e) => updateItem(i, "category_en", e.target.value)}
                        placeholder={t("itemNameEn")}
                        className="flex-1 rounded-md bg-gray-100 px-3 py-2 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                      />
                      <input
                        type="text"
                        value={item.category_ne}
                        onChange={(e) => updateItem(i, "category_ne", e.target.value)}
                        placeholder={t("itemNameNe")}
                        className="flex-1 rounded-md bg-gray-100 px-3 py-2 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                      />
                      <input
                        type="number"
                        value={item.approx_kg || ""}
                        onChange={(e) => updateItem(i, "approx_kg", e.target.value)}
                        placeholder="kg"
                        min="0.1"
                        step="0.1"
                        className="w-20 rounded-md bg-gray-100 px-3 py-2 text-sm border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all"
                      />
                      {items.length > 1 && (
                        <button
                          type="button"
                          onClick={() => removeItem(i)}
                          className="p-1 text-red-500 hover:text-red-700"
                        >
                          <X className="h-4 w-4" />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Actions */}
              <div className="flex justify-end gap-3">
                <Button
                  variant="outline"
                  onClick={() => {
                    setShowCreateForm(false);
                    resetForm();
                  }}
                >
                  {t("cancel")}
                </Button>
                <Button variant="primary" onClick={handleCreate} disabled={creating}>
                  {creating ? t("saving") : t("createPlanButton")}
                </Button>
              </div>
            </div>
          </div>
        )}

        {/* Plans list */}
        {loading ? (
          <div className="py-12 text-center text-gray-500">{t("loading")}</div>
        ) : plans.length === 0 ? (
          <div className="rounded-lg bg-white p-12 text-center">
            <Package className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-4 text-gray-500">{t("noPlans")}</p>
            <Button
              variant="primary"
              className="mt-4"
              onClick={() => setShowCreateForm(true)}
            >
              <Plus className="mr-2 h-5 w-5" />
              {t("createFirstPlan")}
            </Button>
          </div>
        ) : (
          <div className="space-y-4">
            {plans.map((plan) => (
              <PlanCard
                key={plan.id}
                plan={plan}
                locale={locale}
                dayNames={dayNames}
                onToggle={() => handleToggle(plan.id, plan.is_active)}
              />
            ))}
          </div>
        )}
      </div>
    </main>
  );
}

function PlanCard({
  plan,
  locale,
  dayNames,
  onToggle,
}: {
  plan: SubscriptionPlanWithFarmer;
  locale: Locale;
  dayNames: string[];
  onToggle: () => void;
}) {
  const t = useTranslations("farmerSubscriptions");
  const name = locale === "ne" ? plan.name_ne : plan.name_en;
  const desc = locale === "ne" ? plan.description_ne : plan.description_en;

  return (
    <Card className="border-2 border-border">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <h3 className="font-semibold text-foreground">{name}</h3>
            <Badge color={plan.is_active ? "success" : "warning"}>
              {plan.is_active ? t("active") : t("inactive")}
            </Badge>
          </div>
          {desc && <p className="mt-1 text-sm text-gray-500">{desc}</p>}

          {/* Items */}
          {plan.items.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1.5">
              {plan.items.map((item, i) => (
                <span
                  key={i}
                  className="inline-flex items-center rounded-full bg-blue-50 px-2.5 py-0.5 text-xs font-medium text-blue-700"
                >
                  {locale === "ne" ? item.category_ne : item.category_en}{" "}
                  ({item.approx_kg}kg)
                </span>
              ))}
            </div>
          )}

          {/* Stats */}
          <div className="mt-3 flex flex-wrap items-center gap-4 text-sm text-gray-500">
            <span className="font-bold text-foreground">
              NPR {Number(plan.price).toLocaleString()}
            </span>
            <span className="flex items-center gap-1">
              <Calendar className="h-3.5 w-3.5" />
              {t(`frequency.${plan.frequency}`)} — {dayNames[plan.delivery_day]}
            </span>
            <span className="flex items-center gap-1">
              <Users className="h-3.5 w-3.5" />
              {plan.subscriber_count}/{plan.max_subscribers} {t("subscribers")}
            </span>
          </div>
        </div>

        <div className="flex gap-2">
          <button
            onClick={onToggle}
            className={`inline-flex items-center gap-1 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
              plan.is_active
                ? "bg-amber-100 text-amber-700 hover:bg-amber-200"
                : "bg-emerald-100 text-emerald-700 hover:bg-emerald-200"
            }`}
          >
            {plan.is_active ? (
              <>
                <Pause className="h-4 w-4" />
                {t("deactivate")}
              </>
            ) : (
              <>
                <Play className="h-4 w-4" />
                {t("activate")}
              </>
            )}
          </button>
        </div>
      </div>
    </Card>
  );
}
