import { useTranslations } from "next-intl";
import { setRequestLocale } from "next-intl/server";
import { use } from "react";
import { SectionBlock, IconCircle } from "@/components/ui";
import {
  Smartphone,
  Download,
  ShoppingBag,
  Sprout,
  Truck,
  Wifi,
  ShieldCheck,
} from "lucide-react";

export const APK_DOWNLOAD_URL =
  "https://github.com/krantiutils/jirisewa/releases/latest/download/jirisewa.apk";

const FEATURE_ICONS = [ShoppingBag, Sprout, Truck, Wifi];
const FEATURE_COLORS: Array<"primary" | "secondary" | "accent" | "primary"> = [
  "primary",
  "secondary",
  "accent",
  "primary",
];

export default function AndroidPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  setRequestLocale(locale);

  const t = useTranslations("landing.android");

  const features = [
    { title: t("feature1Title"), desc: t("feature1Desc") },
    { title: t("feature2Title"), desc: t("feature2Desc") },
    { title: t("feature3Title"), desc: t("feature3Desc") },
    { title: t("feature4Title"), desc: t("feature4Desc") },
  ];

  const installSteps = [
    t("installStep1"),
    t("installStep2"),
    t("installStep3"),
    t("installStep4"),
  ];

  return (
    <main>
      {/* ─── HERO ─── */}
      <SectionBlock color="primary" decoration className="py-24 lg:py-28">
        <div
          className="absolute top-10 left-1/4 h-72 w-72 rounded-full bg-white/5"
          aria-hidden="true"
        />
        <div
          className="absolute -bottom-10 right-1/4 h-56 w-56 rotate-45 rounded-lg bg-white/5"
          aria-hidden="true"
        />

        <div className="relative grid items-center gap-12 lg:grid-cols-2">
          <div>
            <span className="inline-flex items-center gap-2 rounded-full bg-white/15 px-4 py-1.5 text-sm font-semibold text-white">
              <Smartphone className="h-4 w-4" strokeWidth={2.25} />
              {t("playStoreBadge")}
            </span>
            <h1 className="mt-6 text-4xl font-extrabold tracking-tight sm:text-5xl lg:text-6xl">
              {t("title")}
            </h1>
            <p className="mt-4 text-xl font-semibold text-white/90">
              {t("tagline")}
            </p>
            <p className="mt-6 max-w-xl text-base text-white/80">
              {t("description")}
            </p>
            <div className="mt-10 flex flex-col gap-3 sm:flex-row sm:items-center">
              <a
                href={APK_DOWNLOAD_URL}
                className="inline-flex items-center justify-center gap-2 rounded-md bg-white px-8 h-14 font-semibold text-primary hover:bg-gray-100 hover:text-blue-700 transition-all"
              >
                <Download className="h-5 w-5" strokeWidth={2.5} />
                {t("downloadCta")}
              </a>
              <span className="text-sm font-medium text-white/75">
                {t("downloadHint")}
              </span>
            </div>
            <p className="mt-4 max-w-md text-sm text-white/70">
              {t("playStoreNote")}
            </p>
          </div>

          {/* Phone mockup */}
          <div className="flex items-center justify-center" aria-hidden="true">
            <div className="relative">
              <div className="relative h-96 w-56 rounded-[2.5rem] border-8 border-white/20 bg-white/10 backdrop-blur-sm shadow-2xl">
                <div className="absolute left-1/2 top-3 h-1.5 w-16 -translate-x-1/2 rounded-full bg-white/30" />
                <div className="flex h-full w-full flex-col items-center justify-center gap-4 p-6">
                  <div className="flex h-20 w-20 items-center justify-center rounded-2xl bg-white/25">
                    <Sprout className="h-10 w-10 text-white" strokeWidth={2.25} />
                  </div>
                  <div className="h-3 w-32 rounded-full bg-white/30" />
                  <div className="h-3 w-24 rounded-full bg-white/20" />
                  <div className="mt-4 h-12 w-40 rounded-md bg-white/30" />
                  <div className="h-12 w-40 rounded-md bg-white/20" />
                </div>
              </div>
              <div className="absolute -right-6 -top-4 h-20 w-20 rounded-full bg-white/15" />
              <div className="absolute -left-8 -bottom-4 h-24 w-24 rotate-12 rounded-lg bg-white/10" />
            </div>
          </div>
        </div>
      </SectionBlock>

      {/* ─── FEATURES ─── */}
      <SectionBlock color="white">
        <div className="text-center">
          <h2 className="text-3xl font-extrabold tracking-tight text-foreground sm:text-4xl lg:text-5xl">
            {t("featuresTitle")}
          </h2>
        </div>
        <div className="mt-14 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((f, i) => {
            const Icon = FEATURE_ICONS[i];
            return (
              <div
                key={i}
                className="flex flex-col items-center text-center"
              >
                <IconCircle
                  icon={Icon}
                  color={FEATURE_COLORS[i]}
                  className="h-16 w-16"
                />
                <h3 className="mt-6 text-xl font-bold">{f.title}</h3>
                <p className="mt-3 text-gray-600">{f.desc}</p>
              </div>
            );
          })}
        </div>
      </SectionBlock>

      {/* ─── INSTALL STEPS ─── */}
      <SectionBlock color="dark">
        <div className="grid items-start gap-12 lg:grid-cols-2">
          <div>
            <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl">
              {t("installTitle")}
            </h2>
            <ol className="mt-8 space-y-5">
              {installSteps.map((step, i) => (
                <li key={i} className="flex items-start gap-4">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white/15 text-base font-extrabold text-white">
                    {i + 1}
                  </span>
                  <span className="pt-1 text-white/90">{step}</span>
                </li>
              ))}
            </ol>
          </div>

          <div className="rounded-2xl border-2 border-white/15 bg-white/5 p-8">
            <div className="flex items-center gap-3">
              <ShieldCheck
                className="h-6 w-6 text-emerald-400"
                strokeWidth={2.25}
              />
              <h3 className="text-lg font-bold">{t("playStoreBadge")}</h3>
            </div>
            <p className="mt-4 text-sm leading-relaxed text-white/75">
              {t("securityNote")}
            </p>
            <a
              href={APK_DOWNLOAD_URL}
              className="mt-8 inline-flex w-full items-center justify-center gap-2 rounded-md bg-white px-6 h-12 font-semibold text-foreground hover:bg-gray-200 transition-all"
            >
              <Download className="h-5 w-5" strokeWidth={2.5} />
              {t("downloadCta")}
            </a>
          </div>
        </div>
      </SectionBlock>
    </main>
  );
}
