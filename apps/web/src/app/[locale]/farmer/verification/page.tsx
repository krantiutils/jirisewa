import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { redirect } from "next/navigation";
import { ShieldCheck } from "lucide-react";
import { Link } from "@/i18n/navigation";
import { getVerificationStatus } from "../verification-actions";
import { VerificationForm } from "../_components/VerificationForm";

export default async function FarmerVerificationPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("farmer");

  const result = await getVerificationStatus();
  if (!result.success) {
    redirect(`/${locale}/auth/login`);
  }

  const { verificationStatus, documents } = result.data;

  // If already approved, redirect to dashboard
  if (verificationStatus === "approved") {
    redirect(`/${locale}/farmer/dashboard`);
  }

  // If pending, show a status page
  if (verificationStatus === "pending") {
    return (
      <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
        <div className="mb-6 flex items-center gap-3">
          <ShieldCheck className="h-6 w-6 text-amber-500" />
          <h1 className="text-2xl font-bold text-foreground">
            {t("verification.title")}
          </h1>
        </div>

        <div className="rounded-lg bg-amber-50 p-8 text-center">
          <ShieldCheck className="mx-auto h-12 w-12 text-amber-500" />
          <p className="mt-4 text-lg font-medium text-amber-800">
            {t("verification.statusPending")}
          </p>
          <Link
            href="/farmer/dashboard"
            className="mt-6 inline-flex items-center rounded-md bg-muted px-6 py-3 font-medium text-foreground transition-colors hover:bg-gray-200"
          >
            {t("dashboard.title")}
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
      <div className="mb-6 flex items-center gap-3">
        <ShieldCheck className="h-6 w-6 text-primary" />
        <h1 className="text-2xl font-bold text-foreground">
          {t("verification.title")}
        </h1>
      </div>

      <p className="mb-6 text-gray-500">{t("verification.description")}</p>

      {verificationStatus === "rejected" && documents?.admin_notes && (
        <div className="mb-6 rounded-lg bg-red-50 p-4">
          <p className="text-sm font-medium text-red-800">
            {t("verification.rejectionReason")}: {documents.admin_notes}
          </p>
        </div>
      )}

      <VerificationForm />
    </div>
  );
}
