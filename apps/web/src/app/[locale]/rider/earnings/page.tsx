"use client";

import { useEffect, useState, useCallback } from "react";
import { useTranslations } from "next-intl";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Wallet, DollarSign, CheckCircle, ArrowUpRight } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { useAuth } from "@/components/AuthProvider";
import {
  getEarningsSummary,
  listEarnings,
  requestPayout,
  type EarningsSummary,
  type EarningItem,
} from "@/lib/actions/earnings";

type PayoutMethod = "esewa" | "khalti" | "bank";

export default function RiderEarningsPage() {
  const t = useTranslations("earnings");
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string;
  const { user, loading: authLoading } = useAuth();

  const isAuthenticated = !!user;
  const authChecked = !authLoading;

  const [summary, setSummary] = useState<EarningsSummary | null>(null);
  const [earnings, setEarnings] = useState<EarningItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Payout form state
  const [showPayoutForm, setShowPayoutForm] = useState(false);
  const [payoutAmount, setPayoutAmount] = useState("");
  const [payoutMethod, setPayoutMethod] = useState<PayoutMethod>("esewa");
  const [payoutAccount, setPayoutAccount] = useState("");
  const [payoutBankName, setPayoutBankName] = useState("");
  const [payoutSubmitting, setPayoutSubmitting] = useState(false);
  const [payoutSuccess, setPayoutSuccess] = useState<string | null>(null);
  const [payoutError, setPayoutError] = useState<string | null>(null);

  // Redirect if not authenticated
  useEffect(() => {
    if (authChecked && !isAuthenticated) {
      router.replace(`/${locale}/auth/login`);
    }
  }, [authChecked, isAuthenticated, locale, router]);

  // Load data
  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);

    const [summaryResult, earningsResult] = await Promise.all([
      getEarningsSummary(),
      listEarnings(page),
    ]);

    if (summaryResult.error) {
      setError(summaryResult.error);
    } else if (summaryResult.data) {
      setSummary(summaryResult.data);
    }

    if (earningsResult.error) {
      setError(earningsResult.error);
    } else if (earningsResult.data) {
      setEarnings(earningsResult.data.items);
      setTotal(earningsResult.data.total);
    }

    setLoading(false);
  }, [page]);

  useEffect(() => {
    if (!authChecked || !isAuthenticated) return;
    void Promise.resolve().then(loadData);
  }, [authChecked, isAuthenticated, loadData]);

  const handleRequestPayout = async () => {
    setPayoutSubmitting(true);
    setPayoutError(null);
    setPayoutSuccess(null);

    const amount = parseFloat(payoutAmount);
    if (isNaN(amount) || amount <= 0) {
      setPayoutError("Please enter a valid amount.");
      setPayoutSubmitting(false);
      return;
    }

    const accountDetails: Record<string, string> = {};
    if (payoutMethod === "esewa" || payoutMethod === "khalti") {
      accountDetails.phone = payoutAccount;
    } else {
      accountDetails.bankName = payoutBankName;
      accountDetails.accountNumber = payoutAccount;
    }

    const result = await requestPayout({
      amount,
      method: payoutMethod,
      accountDetails,
    });

    if (result.error) {
      setPayoutError(result.error);
    } else {
      setPayoutSuccess(t("payoutSuccess"));
      setPayoutAmount("");
      setPayoutAccount("");
      setPayoutBankName("");
      setShowPayoutForm(false);
      // Refresh data
      loadData();
    }

    setPayoutSubmitting(false);
  };

  const totalPages = Math.ceil(total / 20);

  const statusBadgeClass = (status: string) => {
    switch (status) {
      case "pending":
        return "bg-amber-100 text-amber-700";
      case "settled":
        return "bg-emerald-100 text-emerald-700";
      case "disputed":
        return "bg-red-100 text-red-700";
      default:
        return "bg-gray-100 text-gray-700";
    }
  };

  if (!authChecked) return null;

  if (!isAuthenticated) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-muted">
        <p className="text-gray-500">Please log in...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8">
        {/* Header */}
        <div className="mb-6 flex items-center gap-4">
          <button
            onClick={() => router.push(`/${locale}/rider/dashboard`)}
            className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
            {t("backToDashboard")}
          </button>
        </div>

        <h1 className="mb-6 text-2xl font-bold text-foreground">{t("title")}</h1>

        {error && (
          <div className="mb-4 rounded-md border-2 border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {payoutSuccess && (
          <div className="mb-4 rounded-md border-2 border-emerald-300 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
            {payoutSuccess}
          </div>
        )}

        {loading ? (
          <div className="py-12 text-center text-gray-500">{t("title")}...</div>
        ) : (
          <>
            {/* Summary Cards */}
            {summary && (
              <div className="mb-8 grid grid-cols-2 gap-4">
                <Card className="border-2 border-border cursor-default hover:scale-100">
                  <div className="flex items-center gap-3">
                    <div className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-blue-100">
                      <DollarSign className="h-5 w-5 text-blue-600" />
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">{t("totalEarned")}</p>
                      <p className="text-lg font-bold text-foreground">
                        NPR {summary.totalEarned.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </Card>

                <Card className="border-2 border-border cursor-default hover:scale-100">
                  <div className="flex items-center gap-3">
                    <div className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-amber-100">
                      <Wallet className="h-5 w-5 text-amber-600" />
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">{t("pendingBalance")}</p>
                      <p className="text-lg font-bold text-foreground">
                        NPR {summary.pendingBalance.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </Card>

                <Card className="border-2 border-border cursor-default hover:scale-100">
                  <div className="flex items-center gap-3">
                    <div className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-emerald-100">
                      <CheckCircle className="h-5 w-5 text-emerald-600" />
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">{t("settled")}</p>
                      <p className="text-lg font-bold text-foreground">
                        NPR {summary.settledBalance.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </Card>

                <Card className="border-2 border-border cursor-default hover:scale-100">
                  <div className="flex items-center gap-3">
                    <div className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-purple-100">
                      <ArrowUpRight className="h-5 w-5 text-purple-600" />
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">{t("withdrawn")}</p>
                      <p className="text-lg font-bold text-foreground">
                        NPR {summary.totalWithdrawn.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </Card>
              </div>
            )}

            {/* Request Payout Button */}
            {summary && summary.pendingBalance > 0 && !showPayoutForm && (
              <div className="mb-6">
                <Button onClick={() => setShowPayoutForm(true)}>
                  {t("requestPayout")}
                </Button>
              </div>
            )}

            {/* Payout Form */}
            {showPayoutForm && summary && (
              <div className="mb-8 rounded-lg bg-white p-6">
                <h2 className="mb-4 text-lg font-semibold text-foreground">
                  {t("requestPayout")}
                </h2>

                {payoutError && (
                  <div className="mb-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
                    {payoutError}
                  </div>
                )}

                <div className="space-y-4">
                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700">
                      {t("amount")}
                    </label>
                    <p className="mb-1 text-xs text-gray-500">
                      {t("maxAmount", {
                        amount: (
                          summary.pendingBalance - summary.totalRequested
                        ).toFixed(2),
                      })}
                    </p>
                    <input
                      type="number"
                      value={payoutAmount}
                      onChange={(e) => setPayoutAmount(e.target.value)}
                      className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                      placeholder="0.00"
                      min="1"
                      max={summary.pendingBalance - summary.totalRequested}
                    />
                  </div>

                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700">
                      {t("method")}
                    </label>
                    <select
                      value={payoutMethod}
                      onChange={(e) =>
                        setPayoutMethod(e.target.value as PayoutMethod)
                      }
                      className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                    >
                      <option value="esewa">{t("esewa")}</option>
                      <option value="khalti">{t("khalti")}</option>
                      <option value="bank">{t("bank")}</option>
                    </select>
                  </div>

                  {payoutMethod === "bank" && (
                    <div>
                      <label className="mb-1 block text-sm font-medium text-gray-700">
                        {t("bankName")}
                      </label>
                      <input
                        type="text"
                        value={payoutBankName}
                        onChange={(e) => setPayoutBankName(e.target.value)}
                        className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                      />
                    </div>
                  )}

                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700">
                      {payoutMethod === "bank" ? t("bankAccount") : t("phone")}
                    </label>
                    <input
                      type="text"
                      value={payoutAccount}
                      onChange={(e) => setPayoutAccount(e.target.value)}
                      className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                    />
                  </div>

                  <div className="flex gap-3">
                    <Button
                      onClick={handleRequestPayout}
                      disabled={payoutSubmitting}
                    >
                      {payoutSubmitting ? t("submitting") : t("submit")}
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => {
                        setShowPayoutForm(false);
                        setPayoutError(null);
                      }}
                    >
                      {t("backToDashboard")}
                    </Button>
                  </div>
                </div>
              </div>
            )}

            {/* Earnings List */}
            <div>
              <h2 className="mb-4 text-lg font-semibold text-foreground">
                {t("title")}
              </h2>

              {earnings.length === 0 ? (
                <div className="rounded-lg bg-white p-8 text-center">
                  <Wallet className="mx-auto h-10 w-10 text-gray-300" />
                  <p className="mt-3 text-gray-500">{t("noEarnings")}</p>
                  <p className="mt-1 text-sm text-gray-400">
                    {t("noEarningsHint")}
                  </p>
                </div>
              ) : (
                <div className="space-y-3">
                  {earnings.map((item) => (
                    <Card
                      key={item.id}
                      className="border-2 border-border cursor-default hover:scale-100"
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium text-foreground">
                            {t("orderId")} #{item.orderId.slice(0, 8)}
                          </p>
                          <p className="text-xs text-gray-500">
                            {item.role === "farmer" ? t("farmer") : t("rider")}
                            {" \u00b7 "}
                            {new Date(item.createdAt).toLocaleDateString(
                              locale === "ne" ? "ne-NP" : "en-US",
                              {
                                month: "short",
                                day: "numeric",
                                year: "numeric",
                              },
                            )}
                          </p>
                        </div>
                        <div className="text-right">
                          <p className="font-semibold text-foreground">
                            NPR {item.amount.toLocaleString()}
                          </p>
                          <span
                            className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${statusBadgeClass(item.status)}`}
                          >
                            {t(`status.${item.status}` as "status.pending" | "status.settled" | "status.disputed")}
                          </span>
                        </div>
                      </div>
                    </Card>
                  ))}
                </div>
              )}

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="mt-6 flex items-center justify-between">
                  <Button
                    variant="outline"
                    disabled={page <= 1}
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    className="text-sm"
                  >
                    &larr;
                  </Button>
                  <span className="text-sm text-gray-500">
                    {page} / {totalPages}
                  </span>
                  <Button
                    variant="outline"
                    disabled={page >= totalPages}
                    onClick={() => setPage((p) => p + 1)}
                    className="text-sm"
                  >
                    &rarr;
                  </Button>
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
