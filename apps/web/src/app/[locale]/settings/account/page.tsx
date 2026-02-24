"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Settings, Loader2, Check, Eye, EyeOff } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { updateProfile, changePassword } from "@/lib/actions/profile";
import type { Locale } from "@/lib/i18n";

export default function AccountSettingsPage() {
  const params = useParams();
  const locale = params.locale as Locale;
  const router = useRouter();
  const t = useTranslations("account");
  const { user, profile, loading: authLoading, refreshProfile } = useAuth();

  // Profile form
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [bio, setBio] = useState("");
  const [savingProfile, setSavingProfile] = useState(false);
  const [profileSuccess, setProfileSuccess] = useState(false);
  const [profileError, setProfileError] = useState("");

  // Password form
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [changingPassword, setChangingPassword] = useState(false);
  const [passwordSuccess, setPasswordSuccess] = useState(false);
  const [passwordError, setPasswordError] = useState("");
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);

  const isEmailUser = !!user?.email && user.app_metadata?.provider === "email";

  // Auth guard
  useEffect(() => {
    if (!authLoading && !user) {
      router.replace(`/${locale}/auth/login`);
    }
  }, [authLoading, user, router, locale]);

  // Populate form from profile
  useEffect(() => {
    if (profile) {
      setFullName(profile.full_name || "");
      setPhone(profile.phone || "");
      setBio(profile.bio || "");
    }
  }, [profile]);

  const handleSaveProfile = async () => {
    setSavingProfile(true);
    setProfileError("");
    setProfileSuccess(false);

    const result = await updateProfile({ fullName, phone, bio });

    if (result.error) {
      setProfileError(result.error);
    } else {
      setProfileSuccess(true);
      await refreshProfile();
      setTimeout(() => setProfileSuccess(false), 3000);
    }
    setSavingProfile(false);
  };

  const handleChangePassword = async () => {
    setPasswordError("");
    setPasswordSuccess(false);

    if (newPassword.length < 6) {
      setPasswordError(t("passwordTooShort"));
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError(t("passwordMismatch"));
      return;
    }

    setChangingPassword(true);

    const result = await changePassword({
      currentPassword,
      newPassword,
    });

    if (result.error) {
      setPasswordError(result.error);
    } else {
      setPasswordSuccess(true);
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setTimeout(() => setPasswordSuccess(false), 3000);
    }
    setChangingPassword(false);
  };

  if (authLoading || !user) return null;

  return (
    <main className="min-h-screen bg-muted">
      <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
            <Settings className="h-6 w-6 text-primary" />
          </div>
          <h1 className="text-2xl font-bold text-foreground">{t("title")}</h1>
        </div>

        {/* Profile Section */}
        <Card className="mb-6 cursor-default hover:scale-100">
          <h2 className="text-lg font-semibold text-foreground mb-4">
            {t("profileSection")}
          </h2>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {t("fullName")}
              </label>
              <input
                type="text"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                placeholder={t("fullNamePlaceholder")}
                className="w-full rounded-lg border-2 border-gray-200 px-4 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {t("phone")}
              </label>
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder={t("phonePlaceholder")}
                className="w-full rounded-lg border-2 border-gray-200 px-4 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
              />
            </div>

            {/* Bio — visible to farmers */}
            {profile?.role === "farmer" && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t("bio")}
                </label>
                <textarea
                  value={bio}
                  onChange={(e) => setBio(e.target.value)}
                  placeholder={t("bioPlaceholder")}
                  rows={4}
                  maxLength={1000}
                  className="w-full rounded-lg border-2 border-gray-200 px-4 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none resize-none"
                />
                <p className="mt-1 text-xs text-gray-400">{bio.length}/1000</p>
              </div>
            )}

            {profileError && (
              <p className="text-sm text-red-600">{profileError}</p>
            )}

            {profileSuccess && (
              <p className="flex items-center gap-1.5 text-sm text-green-600">
                <Check className="h-4 w-4" />
                {t("profileUpdated")}
              </p>
            )}

            <Button
              onClick={handleSaveProfile}
              disabled={savingProfile || !fullName.trim()}
              className="h-10 px-6 text-sm"
            >
              {savingProfile ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  {t("saving")}
                </>
              ) : (
                t("saveProfile")
              )}
            </Button>
          </div>
        </Card>

        {/* Password Section — only for email users */}
        {isEmailUser && (
          <Card className="mb-6 cursor-default hover:scale-100">
            <h2 className="text-lg font-semibold text-foreground mb-4">
              {t("passwordSection")}
            </h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t("currentPassword")}
                </label>
                <div className="relative">
                  <input
                    type={showCurrentPassword ? "text" : "password"}
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    placeholder={t("currentPasswordPlaceholder")}
                    className="w-full rounded-lg border-2 border-gray-200 px-4 py-2.5 pr-10 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
                  />
                  <button
                    type="button"
                    onClick={() => setShowCurrentPassword((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showCurrentPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t("newPassword")}
                </label>
                <div className="relative">
                  <input
                    type={showNewPassword ? "text" : "password"}
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder={t("newPasswordPlaceholder")}
                    className="w-full rounded-lg border-2 border-gray-200 px-4 py-2.5 pr-10 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPassword((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showNewPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t("confirmPassword")}
                </label>
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder={t("confirmPasswordPlaceholder")}
                  className="w-full rounded-lg border-2 border-gray-200 px-4 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:border-primary focus:outline-none"
                />
              </div>

              {passwordError && (
                <p className="text-sm text-red-600">{passwordError}</p>
              )}

              {passwordSuccess && (
                <p className="flex items-center gap-1.5 text-sm text-green-600">
                  <Check className="h-4 w-4" />
                  {t("passwordChanged")}
                </p>
              )}

              <Button
                onClick={handleChangePassword}
                disabled={
                  changingPassword || !currentPassword || !newPassword || !confirmPassword
                }
                className="h-10 px-6 text-sm"
              >
                {changingPassword ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    {t("changing")}
                  </>
                ) : (
                  t("changePassword")
                )}
              </Button>
            </div>
          </Card>
        )}

        {/* Account Info Section */}
        <Card className="cursor-default hover:scale-100">
          <h2 className="text-lg font-semibold text-foreground mb-4">
            {t("accountInfo")}
          </h2>

          <dl className="space-y-3">
            {user.email && (
              <div className="flex items-center justify-between">
                <dt className="text-sm text-gray-500">{t("email")}</dt>
                <dd className="text-sm font-medium text-gray-900">
                  {user.email}
                </dd>
              </div>
            )}

            {profile?.role && (
              <div className="flex items-center justify-between">
                <dt className="text-sm text-gray-500">{t("role")}</dt>
                <dd>
                  <span className="inline-block rounded-full bg-primary/10 px-2.5 py-0.5 text-xs font-medium text-primary capitalize">
                    {profile.role}
                  </span>
                </dd>
              </div>
            )}

            {user.created_at && (
              <div className="flex items-center justify-between">
                <dt className="text-sm text-gray-500">{t("memberSince")}</dt>
                <dd className="text-sm font-medium text-gray-900">
                  {new Date(user.created_at).toLocaleDateString(
                    locale === "ne" ? "ne-NP" : "en-US",
                    { year: "numeric", month: "long", day: "numeric" },
                  )}
                </dd>
              </div>
            )}
          </dl>
        </Card>
      </div>
    </main>
  );
}
