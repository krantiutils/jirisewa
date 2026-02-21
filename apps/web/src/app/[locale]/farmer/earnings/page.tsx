"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  Loader2,
  ArrowLeft,
  Wallet,
  TrendingUp,
  CheckCircle2,
  Banknote,
  Clock,
} from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import {
  getEarningsSummary,
  listEarnings,
  requestPayout,
} from "@/lib/actions/earnings";
import type { EarningsSummary, EarningItem } from "@/lib/actions/earnings";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import type { Locale } from "@/lib/i18n";

const STATUS_BADGE: Record<string, "warning" | "success" | "danger"> = {
  pending: "warning",
  settled: "success",
  disputed: "danger",
};

export default function FarmerEarningsPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("earnings");
  const { user, loading: authLoading } = useAuth();

  const [summary, setSummary] = useState<EarningsSummary | null>(null);
  const [earnings, setEarnings] = useState<EarningItem[]>([]);
  const [totalEarnings, setTotalEarnings] = useState(0);
  const [loading, setLoading] = useState(true);

  // Payout form state
  const [showPayoutForm, setShowPayoutForm] = useState(false);
  const [payoutAmount, setPayoutAmount] = useState("");
  const [payoutMethod, setPayoutMethod] = useState<"esewa" | "khalti" | "bank">("esewa");
  const [payoutPhone, setPayoutPhone] = useState("");
  const [payoutBankName, setPayoutBankName] = useState("");
  const [payoutBankAccount, setPayoutBankAccount] = useState("");
  const [payoutSubmitting, setPayoutSubmitting] = useState(false);
  const [payoutError, setPayoutError] = useState("");
  const [payoutSuccess, setPayoutSuccess] = useState("");

  // Auth guard
  useEffect(() => {
    if (!authLoading && !user) {
      router.replace(`/${locale}/auth/login`);
    }
  }, [authLoading, user, router, locale]);

  // Load data
  useEffect(() => {
    if (authLoading || !user) return;

    async function load() {
      const [summaryResult, earningsResult] = await Promise.all([
        getEarningsSummary(),
        listEarnings(1),
      ]);

      if (summaryResult.data) {
        setSummary(summaryResult.data);
      }
      if (earningsResult.data) {
        setEarnings(earningsResult.data.items);
        setTotalEarnings(earningsResult.data.total);
      }
      setLoading(false);
    }
    load();
  }, [authLoading, user]);

  const availableBalance = summary
    ? Math.round((summary.pendingBalance - summary.totalRequested) * 100) / 100
    : 0;

  const handlePayoutSubmit = async () => {
    setPayoutError("");
    setPayoutSuccess("");

    const amount = parseFloat(payoutAmount);
    if (isNaN(amount) || amount <= 0) {
      setPayoutError("Amount must be greater than 0");
      return;
    }
    if (amount > availableBalance) {
      setPayoutError(`Amount exceeds available balance (NPR ${availableBalance.toFixed(2)})`);
      return;
    }

    const accountDetails: Record<string, string> = {};
    if (payoutMethod === "esewa" || payoutMethod === "khalti") {
      if (!payoutPhone.trim()) {
        setPayoutError("Phone number is required");
        return;
      }
      accountDetails.phone = payoutPhone.trim();
    } else {
      if (!payoutBankName.trim() || !payoutBankAccount.trim()) {
        setPayoutError("Bank name and account number are required");
        return;
      }
      accountDetails.bankName = payoutBankName.trim();
      accountDetails.accountNumber = payoutBankAccount.trim();
    }

    setPayoutSubmitting(true);
    const result = await requestPayout({
      amount,
      method: payoutMethod,
      accountDetails,
    });

    if (result.error) {
      setPayoutError(result.error);
      setPayoutSubmitting(false);
      return;
    }

    setPayoutSuccess(t("payoutSuccess"));
    setPayoutSubmitting(false);
    setShowPayoutForm(false);
    setPayoutAmount("");
    setPayoutPhone("");
    setPayoutBankName("");
    setPayoutBankAccount("");

    // Reload summary
    const updated = await getEarningsSummary();
    if (updated.data) {
      setSummary(updated.data);
    }
  };

  if (authLoading || !user) return null;

  if (loading) {
    return (
      <main className="min-h-screen bg-muted flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
        {/* Back link */}
        <button
          onClick={() => router.push(`/${locale}/farmer/dashboard`)}
          className="mb-4 flex items-center gap-1 text-sm text-gray-500 hover:text-primary transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("backToDashboard")}
        </button>

        {/* Page header */}
        <div className="flex items-center gap-3 mb-6">
          <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-emerald-100">
            <Wallet className="h-6 w-6 text-emerald-600" />
          </div>
          <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
        </div>

        {/* Summary cards */}
        {summary && (
          <div className="grid grid-cols-2 gap-3 mb-6 sm:grid-cols-4">
            {/* Total Earned */}
            <div className="rounded-lg bg-white p-4">
              <div className="flex items-center gap-2 mb-1">
                <TrendingUp className="h-4 w-4 text-emerald-500" />
                <span className="text-xs font-medium text-gray-500">
                  {t("totalEarned")}
                </span>
              </div>
              <p className="text-lg font-bold text-emerald-600">
                NPR {summary.totalEarned.toLocaleString()}
              </p>
            </div>

            {/* Available Balance */}
            <div className="rounded-lg bg-white p-4">
              <div className="flex items-center gap-2 mb-1">
                <Wallet className="h-4 w-4 text-amber-500" />
                <span className="text-xs font-medium text-gray-500">
                  {t("pendingBalance")}
                </span>
              </div>
              <p className="text-lg font-bold text-amber-600">
                NPR {availableBalance.toLocaleString()}
              </p>
            </div>

            {/* Settled */}
            <div className="rounded-lg bg-white p-4">
              <div className="flex items-center gap-2 mb-1">
                <CheckCircle2 className="h-4 w-4 text-gray-500" />
                <span className="text-xs font-medium text-gray-500">
                  {t("settled")}
                </span>
              </div>
              <p className="text-lg font-bold text-gray-700">
                NPR {summary.settledBalance.toLocaleString()}
              </p>
            </div>

            {/* Withdrawn */}
            <div className="rounded-lg bg-white p-4">
              <div className="flex items-center gap-2 mb-1">
                <Banknote className="h-4 w-4 text-blue-500" />
                <span className="text-xs font-medium text-gray-500">
                  {t("withdrawn")}
                </span>
              </div>
              <p className="text-lg font-bold text-blue-600">
                NPR {summary.totalWithdrawn.toLocaleString()}
              </p>
            </div>
          </div>
        )}

        {/* Success message */}
        {payoutSuccess && (
          <div className="mb-4 rounded-lg bg-green-50 border border-green-200 p-3 text-sm text-green-700">
            {payoutSuccess}
          </div>
        )}

        {/* Request Payout button */}
        {!showPayoutForm && availableBalance > 0 && (
          <div className="mb-6">
            <Button
              onClick={() => {
                setShowPayoutForm(true);
                setPayoutSuccess("");
              }}
              className="w-full sm:w-auto"
            >
              <Banknote className="h-5 w-5 mr-2" />
              {t("requestPayout")}
            </Button>
          </div>
        )}

        {/* Payout form */}
        {showPayoutForm && (
          <div className="mb-6 rounded-lg bg-white p-6">
            <h2 className="text-lg font-semibold text-foreground mb-4">
              {t("requestPayout")}
            </h2>

            {/* Amount */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {t("amount")}
              </label>
              <input
                type="number"
                min={1}
                max={availableBalance}
                step={0.01}
                value={payoutAmount}
                onChange={(e) => setPayoutAmount(e.target.value)}
                placeholder="0.00"
                className="w-full rounded-md border-2 border-gray-200 px-3 py-2 text-sm focus:border-primary focus:outline-none"
              />
              <p className="mt-1 text-xs text-gray-500">
                {t("maxAmount", { amount: availableBalance.toFixed(2) })}
              </p>
            </div>

            {/* Payment method */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                {t("method")}
              </label>
              <div className="flex gap-3">
                {(["esewa", "khalti", "bank"] as const).map((method) => (
                  <label
                    key={method}
                    className={`flex items-center gap-2 rounded-md border-2 px-4 py-2 cursor-pointer transition-colors ${
                      payoutMethod === method
                        ? "border-primary bg-blue-50"
                        : "border-gray-200 hover:border-gray-300"
                    }`}
                  >
                    <input
                      type="radio"
                      name="payoutMethod"
                      value={method}
                      checked={payoutMethod === method}
                      onChange={() => setPayoutMethod(method)}
                      className="sr-only"
                    />
                    <span className="text-sm font-medium">
                      {t(method)}
                    </span>
                  </label>
                ))}
              </div>
            </div>

            {/* Account details - conditional */}
            {(payoutMethod === "esewa" || payoutMethod === "khalti") && (
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t("phone")}
                </label>
                <input
                  type="tel"
                  value={payoutPhone}
                  onChange={(e) => setPayoutPhone(e.target.value)}
                  placeholder="98XXXXXXXX"
                  className="w-full rounded-md border-2 border-gray-200 px-3 py-2 text-sm focus:border-primary focus:outline-none"
                />
              </div>
            )}

            {payoutMethod === "bank" && (
              <>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    {t("bankName")}
                  </label>
                  <input
                    type="text"
                    value={payoutBankName}
                    onChange={(e) => setPayoutBankName(e.target.value)}
                    className="w-full rounded-md border-2 border-gray-200 px-3 py-2 text-sm focus:border-primary focus:outline-none"
                  />
                </div>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    {t("bankAccount")}
                  </label>
                  <input
                    type="text"
                    value={payoutBankAccount}
                    onChange={(e) => setPayoutBankAccount(e.target.value)}
                    className="w-full rounded-md border-2 border-gray-200 px-3 py-2 text-sm focus:border-primary focus:outline-none"
                  />
                </div>
              </>
            )}

            {/* Error */}
            {payoutError && (
              <div className="mb-4 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">
                {payoutError}
              </div>
            )}

            {/* Actions */}
            <div className="flex gap-3">
              <Button
                onClick={handlePayoutSubmit}
                disabled={payoutSubmitting}
              >
                {payoutSubmitting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    {t("submitting")}
                  </>
                ) : (
                  t("submit")
                )}
              </Button>
              <Button
                variant="secondary"
                onClick={() => {
                  setShowPayoutForm(false);
                  setPayoutError("");
                }}
              >
                {t("backToDashboard")}
              </Button>
            </div>
          </div>
        )}

        {/* Earnings list */}
        <h2 className="text-lg font-semibold text-foreground mb-3">
          {t("title")}
        </h2>

        {earnings.length === 0 ? (
          <div className="rounded-lg bg-white p-12 text-center">
            <Clock className="mx-auto h-12 w-12 text-gray-300" />
            <p className="mt-4 text-gray-500">{t("noEarnings")}</p>
            <p className="mt-1 text-sm text-gray-400">{t("noEarningsHint")}</p>
          </div>
        ) : (
          <div className="space-y-3">
            {earnings.map((item) => {
              const dateStr = new Date(item.createdAt).toLocaleDateString(
                locale === "ne" ? "ne-NP" : "en-US",
                { month: "short", day: "numeric", year: "numeric" },
              );

              return (
                <div
                  key={item.id}
                  className="rounded-lg bg-white p-4 flex items-center justify-between"
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-mono text-gray-500">
                        {t("orderId")} #{item.orderId.slice(0, 8)}
                      </span>
                      <Badge
                        color={STATUS_BADGE[item.status] ?? "warning"}
                      >
                        {t(`status.${item.status}`)}
                      </Badge>
                      <Badge color={item.role === "farmer" ? "secondary" : "primary"}>
                        {t(item.role as "farmer" | "rider")}
                      </Badge>
                    </div>
                    <p className="mt-1 text-xs text-gray-500">{dateStr}</p>
                  </div>
                  <div className="text-right shrink-0 ml-4">
                    <p className="text-lg font-bold text-foreground">
                      NPR {item.amount.toLocaleString()}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </main>
  );
}
