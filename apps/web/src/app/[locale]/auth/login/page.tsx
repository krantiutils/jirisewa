"use client";

import { useState, useEffect, useCallback } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { useAuth } from "@/components/AuthProvider";
import { isValidNepalPhone, toE164, normalizePhone } from "@jirisewa/shared";
import { Button, Input, Card } from "@/components/ui";

type Step = "phone" | "otp";

export default function LoginPage() {
  const t = useTranslations("auth");
  const router = useRouter();
  const { signInWithOtp, verifyOtp, user } = useAuth();

  const [step, setStep] = useState<Step>("phone");
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [resendCooldown, setResendCooldown] = useState(0);
  const [verifyAttempts, setVerifyAttempts] = useState(0);

  // Redirect if already logged in
  useEffect(() => {
    if (user) {
      router.replace("/");
    }
  }, [user, router]);

  // Resend cooldown timer
  useEffect(() => {
    if (resendCooldown <= 0) return;
    const timer = setTimeout(() => setResendCooldown((c) => c - 1), 1000);
    return () => clearTimeout(timer);
  }, [resendCooldown]);

  const handleSendOtp = useCallback(async () => {
    const normalized = normalizePhone(phone);
    if (!isValidNepalPhone(normalized)) {
      setError(t("invalidPhone"));
      return;
    }

    setError("");
    setLoading(true);

    const { error: sendError } = await signInWithOtp(toE164(phone));

    setLoading(false);

    if (sendError) {
      setError(t("otpError"));
      return;
    }

    setStep("otp");
    setResendCooldown(60);
  }, [phone, signInWithOtp, t]);

  const handleVerifyOtp = useCallback(async () => {
    if (otp.length !== 6) return;
    if (verifyAttempts >= 5) {
      setError(t("verifyError"));
      return;
    }

    setError("");
    setLoading(true);

    const { error: verifyError } = await verifyOtp(toE164(phone), otp);

    setLoading(false);

    if (verifyError) {
      setVerifyAttempts((a) => a + 1);
      setError(t("verifyError"));
      return;
    }

    // Auth state change will trigger redirect via useEffect
  }, [otp, phone, verifyOtp, verifyAttempts, t]);

  const handleResend = useCallback(async () => {
    if (resendCooldown > 0) return;
    if (!isValidNepalPhone(phone)) {
      setError(t("invalidPhone"));
      return;
    }

    setError("");
    setLoading(true);
    setVerifyAttempts(0);
    setOtp("");

    const { error: sendError } = await signInWithOtp(toE164(phone));

    setLoading(false);

    if (sendError) {
      setError(t("otpError"));
      return;
    }

    setResendCooldown(60);
  }, [resendCooldown, phone, signInWithOtp, t]);

  const handleBack = useCallback(() => {
    setStep("phone");
    setOtp("");
    setError("");
  }, []);

  return (
    <div className="flex min-h-[calc(100vh-57px)] flex-col items-center justify-center p-6">
      <Card className="w-full max-w-sm cursor-default hover:scale-100">
        {step === "phone" ? (
          <>
            <h1 className="text-2xl font-bold text-foreground">
              {t("loginTitle")}
            </h1>
            <p className="mt-1 text-sm text-gray-500">{t("loginSubtitle")}</p>

            <div className="mt-6">
              <label
                htmlFor="phone"
                className="mb-1.5 block text-sm font-medium text-foreground"
              >
                {t("phoneLabel")}
              </label>
              <div className="flex items-center gap-2">
                <span className="flex h-14 items-center rounded-md bg-gray-100 px-3 text-sm font-medium text-gray-600">
                  +977
                </span>
                <Input
                  id="phone"
                  type="tel"
                  inputMode="numeric"
                  placeholder={t("phonePlaceholder")}
                  value={phone}
                  onChange={(e) => {
                    setPhone(e.target.value.replace(/\D/g, "").slice(0, 10));
                    setError("");
                  }}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleSendOtp();
                  }}
                  autoFocus
                />
              </div>
              <p className="mt-1.5 text-xs text-gray-400">{t("phoneHint")}</p>
            </div>

            {error && (
              <p className="mt-3 text-sm font-medium text-red-600">{error}</p>
            )}

            <Button
              className="mt-6 w-full"
              onClick={handleSendOtp}
              disabled={loading || phone.length < 10}
            >
              {loading ? t("sending") : t("sendOtp")}
            </Button>
          </>
        ) : (
          <>
            <h1 className="text-2xl font-bold text-foreground">
              {t("otpTitle")}
            </h1>
            <p className="mt-1 text-sm text-gray-500">
              {t("otpSubtitle", { phone: `+977${normalizePhone(phone)}` })}
            </p>

            <div className="mt-6">
              <Input
                type="text"
                inputMode="numeric"
                placeholder={t("otpPlaceholder")}
                value={otp}
                onChange={(e) => {
                  setOtp(e.target.value.replace(/\D/g, "").slice(0, 6));
                  setError("");
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleVerifyOtp();
                }}
                autoFocus
                maxLength={6}
                className="text-center text-2xl tracking-[0.5em]"
              />
            </div>

            {error && (
              <p className="mt-3 text-sm font-medium text-red-600">{error}</p>
            )}

            <Button
              className="mt-6 w-full"
              onClick={handleVerifyOtp}
              disabled={loading || otp.length !== 6}
            >
              {loading ? t("verifying") : t("verifyOtp")}
            </Button>

            <div className="mt-4 flex items-center justify-between">
              <button
                type="button"
                onClick={handleBack}
                className="text-sm text-gray-500 hover:text-foreground"
              >
                {t("changePhone")}
              </button>
              <button
                type="button"
                onClick={handleResend}
                disabled={resendCooldown > 0}
                className="text-sm font-medium text-primary hover:text-blue-700 disabled:text-gray-400"
              >
                {resendCooldown > 0
                  ? t("resendIn", { seconds: resendCooldown })
                  : t("resendOtp")}
              </button>
            </div>
          </>
        )}
      </Card>
    </div>
  );
}
