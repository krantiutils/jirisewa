"use client";

import { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Upload, Loader2, FileText, CheckCircle2 } from "lucide-react";
import {
  uploadVerificationDocument,
  submitVerificationDocuments,
} from "../verification-actions";

interface DocumentSlot {
  label: string;
  hint: string;
  url: string | null;
  required: boolean;
}

export function VerificationForm() {
  const t = useTranslations("farmer.verification");
  const router = useRouter();

  const [citizenshipUrl, setCitizenshipUrl] = useState<string | null>(null);
  const [farmPhotoUrl, setFarmPhotoUrl] = useState<string | null>(null);
  const [municipalityUrl, setMunicipalityUrl] = useState<string | null>(null);
  const [uploading, setUploading] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const citizenshipRef = useRef<HTMLInputElement>(null);
  const farmRef = useRef<HTMLInputElement>(null);
  const municipalityRef = useRef<HTMLInputElement>(null);

  async function handleUpload(
    file: File,
    slotKey: string,
    setter: (url: string) => void,
  ) {
    if (file.size > 5242880) {
      setError(t("fileTooLarge"));
      return;
    }

    const allowedTypes = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
    if (!allowedTypes.includes(file.type)) {
      setError(t("invalidFileType"));
      return;
    }

    setUploading(slotKey);
    setError(null);

    const fd = new FormData();
    fd.append("file", file);
    const result = await uploadVerificationDocument(fd);

    setUploading(null);

    if (result.success) {
      setter(result.data.url);
    } else {
      setError(result.error);
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    if (!citizenshipUrl || !farmPhotoUrl) {
      setError(t("submitError"));
      return;
    }

    setSubmitting(true);
    setError(null);

    const result = await submitVerificationDocuments(
      citizenshipUrl,
      farmPhotoUrl,
      municipalityUrl,
    );

    setSubmitting(false);

    if (result.success) {
      setSuccess(true);
      router.refresh();
    } else {
      setError(result.error);
    }
  }

  if (success) {
    return (
      <div className="flex flex-col items-center gap-4 rounded-lg bg-emerald-50 p-8 text-center">
        <CheckCircle2 className="h-12 w-12 text-emerald-500" />
        <p className="text-lg font-medium text-emerald-800">{t("submitted")}</p>
      </div>
    );
  }

  const slots: (DocumentSlot & { key: string; url: string | null; setter: (url: string) => void; ref: React.RefObject<HTMLInputElement | null> })[] = [
    {
      key: "citizenship",
      label: t("citizenshipPhoto"),
      hint: t("citizenshipPhotoHint"),
      url: citizenshipUrl,
      setter: setCitizenshipUrl,
      required: true,
      ref: citizenshipRef,
    },
    {
      key: "farm",
      label: t("farmPhoto"),
      hint: t("farmPhotoHint"),
      url: farmPhotoUrl,
      setter: setFarmPhotoUrl,
      required: true,
      ref: farmRef,
    },
    {
      key: "municipality",
      label: t("municipalityLetter"),
      hint: t("municipalityLetterHint"),
      url: municipalityUrl,
      setter: setMunicipalityUrl,
      required: false,
      ref: municipalityRef,
    },
  ];

  const canSubmit = citizenshipUrl && farmPhotoUrl && !submitting && !uploading;

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {slots.map((slot) => (
        <div key={slot.key} className="rounded-lg bg-white p-5">
          <div className="mb-2 flex items-center gap-2">
            <FileText className="h-5 w-5 text-gray-400" />
            <span className="font-medium text-foreground">
              {slot.label}
              {slot.required && <span className="ml-1 text-red-500">*</span>}
            </span>
          </div>
          <p className="mb-3 text-sm text-gray-500">{slot.hint}</p>

          {slot.url ? (
            <div className="flex items-center gap-3 rounded-md bg-emerald-50 p-3">
              <CheckCircle2 className="h-5 w-5 text-emerald-500" />
              <span className="text-sm text-emerald-700">
                {t("citizenshipPhoto").split("/")[0]} uploaded
              </span>
              <button
                type="button"
                onClick={() => {
                  slot.setter("");
                  if (slot.ref.current) slot.ref.current.value = "";
                }}
                className="ml-auto text-sm text-gray-500 underline hover:text-gray-700"
              >
                Change
              </button>
            </div>
          ) : (
            <label className="flex cursor-pointer flex-col items-center gap-2 rounded-lg border-2 border-dashed border-gray-300 bg-muted p-6 transition-colors hover:border-primary hover:bg-gray-50">
              {uploading === slot.key ? (
                <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
              ) : (
                <>
                  <Upload className="h-8 w-8 text-gray-400" />
                  <span className="text-sm text-gray-500">{slot.label}</span>
                </>
              )}
              <input
                ref={slot.ref}
                type="file"
                accept="image/jpeg,image/png,image/webp,application/pdf"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) handleUpload(file, slot.key, slot.setter);
                }}
                disabled={uploading !== null}
                className="sr-only"
              />
            </label>
          )}
        </div>
      ))}

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button
        type="submit"
        disabled={!canSubmit}
        className="w-full rounded-md bg-primary px-6 py-3 font-semibold text-white transition-colors hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
      >
        {submitting ? t("submitting") : t("submitDocuments")}
      </button>
    </form>
  );
}
