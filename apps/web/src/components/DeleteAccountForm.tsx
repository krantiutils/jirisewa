"use client";

import { useState } from "react";
import { useAuth } from "@/components/AuthProvider";
import { deleteAccount } from "@/lib/actions/account";
import { Link } from "@/i18n/navigation";

export default function DeleteAccountForm() {
  const { user, profile, loading, signOut } = useAuth();
  const [step, setStep] = useState<"idle" | "confirm" | "deleting" | "done">(
    "idle",
  );
  const [error, setError] = useState<string | null>(null);

  if (loading) {
    return (
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-6 text-center text-gray-500">
        Loading...
      </div>
    );
  }

  if (!user) {
    return (
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-6">
        <p className="text-gray-700">
          Sign in to delete your account.
        </p>
        <Link
          href="/login"
          className="mt-3 inline-block rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
        >
          Sign in
        </Link>
      </div>
    );
  }

  if (step === "done") {
    return (
      <div className="rounded-lg border border-green-200 bg-green-50 p-6">
        <p className="font-semibold text-green-800">
          Your account has been deleted.
        </p>
        <p className="mt-2 text-sm text-green-700">
          All your personal data has been permanently removed.
        </p>
      </div>
    );
  }

  const displayName =
    profile?.full_name || user.email || user.phone || "your account";

  async function handleDelete() {
    setStep("deleting");
    setError(null);
    const result = await deleteAccount();
    if (result.error) {
      setError(result.error);
      setStep("confirm");
      return;
    }
    setStep("done");
    await signOut();
  }

  return (
    <div className="rounded-lg border border-red-200 bg-red-50 p-6">
      <p className="text-sm text-gray-700">
        Signed in as <strong>{displayName}</strong>
      </p>

      {step === "idle" && (
        <button
          onClick={() => setStep("confirm")}
          className="mt-4 rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
        >
          Delete My Account
        </button>
      )}

      {step === "confirm" && (
        <div className="mt-4 space-y-3">
          <p className="text-sm font-semibold text-red-800">
            This action is permanent and cannot be undone. All your data will be
            deleted.
          </p>
          {error && (
            <p className="text-sm text-red-600">Error: {error}</p>
          )}
          <div className="flex gap-3">
            <button
              onClick={handleDelete}
              className="rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
            >
              Yes, permanently delete my account
            </button>
            <button
              onClick={() => setStep("idle")}
              className="rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {step === "deleting" && (
        <p className="mt-4 text-sm text-gray-600">
          Deleting your account...
        </p>
      )}
    </div>
  );
}
