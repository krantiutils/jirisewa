import { useTranslations } from "next-intl";
import { setRequestLocale } from "next-intl/server";
import { use } from "react";
import { Link } from "@/i18n/navigation";
import { SectionBlock, Button, IconCircle } from "@/components/ui";
import {
  Sprout,
  Route,
  ShoppingBag,
  Truck,
  Users,
  Percent,
  ArrowRight,
  Mail,
  MapPin,
  Phone,
} from "lucide-react";

const STEP_COLORS: Array<"secondary" | "accent" | "primary"> = [
  "secondary",
  "accent",
  "primary",
];

const STEP_ICONS = [Sprout, Route, ShoppingBag];

const STAT_COLORS = [
  "text-primary",
  "text-secondary",
  "text-accent",
  "text-primary",
];

const STAT_ICONS = [Users, Truck, Route, Percent];

export default function HomePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  setRequestLocale(locale);

  const hero = useTranslations("landing.hero");
  const how = useTranslations("landing.howItWorks");
  const stats = useTranslations("landing.stats");
  const farmers = useTranslations("landing.forFarmers");
  const riders = useTranslations("landing.forRiders");
  const cta = useTranslations("landing.cta");
  const footer = useTranslations("landing.footer");

  const steps = [
    { number: how("step1Number"), title: how("step1Title"), desc: how("step1Desc") },
    { number: how("step2Number"), title: how("step2Title"), desc: how("step2Desc") },
    { number: how("step3Number"), title: how("step3Title"), desc: how("step3Desc") },
  ];

  const statItems = [
    { value: stats("farmersValue"), label: stats("farmersLabel") },
    { value: stats("deliveredValue"), label: stats("deliveredLabel") },
    { value: stats("ridersValue"), label: stats("ridersLabel") },
    { value: stats("savingsValue"), label: stats("savingsLabel") },
  ];

  const farmerBenefits = [
    farmers("benefit1"),
    farmers("benefit2"),
    farmers("benefit3"),
    farmers("benefit4"),
  ];

  const riderBenefits = [
    riders("benefit1"),
    riders("benefit2"),
    riders("benefit3"),
    riders("benefit4"),
  ];

  const productLinks = [
    footer("productMarketplace"),
    footer("productFarmers"),
    footer("productRiders"),
    footer("productPricing"),
  ];

  const companyLinks = [
    footer("companyAbout"),
    footer("companyBlog"),
    footer("companyCareers"),
    footer("companyContact"),
  ];

  const legalLinks = [
    footer("legalPrivacy"),
    footer("legalTerms"),
    footer("legalCookies"),
  ];

  return (
    <main>
      {/* ─── HERO ─── */}
      <SectionBlock color="primary" decoration className="py-24 lg:py-32">
        <div
          className="absolute top-10 left-1/4 h-80 w-80 rounded-full bg-white/5"
          aria-hidden="true"
        />
        <div
          className="absolute -bottom-10 right-1/3 h-60 w-60 rotate-45 rounded-lg bg-white/5"
          aria-hidden="true"
        />
        <div
          className="absolute top-1/2 right-10 h-40 w-40 rounded-full bg-white/10"
          aria-hidden="true"
        />

        <div className="relative flex flex-col items-center text-center">
          <h1 className="text-4xl font-extrabold tracking-tight sm:text-5xl lg:text-7xl">
            {hero("heading")}
          </h1>
          <p className="mt-6 max-w-2xl text-lg font-medium text-white/90 sm:text-xl">
            {hero("subheading")}
          </p>
          <div className="mt-10 flex flex-col gap-4 sm:flex-row sm:flex-wrap">
            <Link href="/marketplace" className="inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 bg-white text-primary hover:bg-gray-100 hover:text-blue-700 transition-all">
              {hero("ctaBrowse")}
            </Link>
            <Link href="/farmer/dashboard" className="inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 bg-emerald-500 text-white hover:bg-emerald-600 transition-all">
              {hero("ctaFarmer")}
            </Link>
            <Link href="/rider/dashboard" className="inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 border-4 border-white bg-transparent text-white hover:bg-white hover:text-primary transition-all">
              {hero("ctaRider")}
            </Link>
          </div>

          {/* Abstract farmer → rider → consumer flow */}
          <div className="mt-16 flex items-center gap-6 sm:gap-10">
            <div className="flex flex-col items-center gap-2">
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-400">
                <Sprout className="h-8 w-8 text-white" strokeWidth={2.25} />
              </div>
              <span className="text-sm font-semibold text-white/80">
                {hero("farmer")}
              </span>
            </div>
            <ArrowRight className="h-8 w-8 text-white/60" strokeWidth={2.5} />
            <div className="flex flex-col items-center gap-2">
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-amber-400">
                <Truck className="h-8 w-8 text-white" strokeWidth={2.25} />
              </div>
              <span className="text-sm font-semibold text-white/80">
                {hero("rider")}
              </span>
            </div>
            <ArrowRight className="h-8 w-8 text-white/60" strokeWidth={2.5} />
            <div className="flex flex-col items-center gap-2">
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-blue-300">
                <ShoppingBag className="h-8 w-8 text-white" strokeWidth={2.25} />
              </div>
              <span className="text-sm font-semibold text-white/80">
                {hero("consumer")}
              </span>
            </div>
          </div>
        </div>
      </SectionBlock>

      {/* ─── HOW IT WORKS ─── */}
      <SectionBlock color="dark" decoration>
        <div className="text-center">
          <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl lg:text-5xl">
            {how("title")}
          </h2>
        </div>
        <div className="mt-14 grid gap-8 sm:grid-cols-3">
          {steps.map((step, i) => {
            const StepIcon = STEP_ICONS[i];
            return (
              <div
                key={i}
                className="group flex flex-col items-center text-center"
              >
                <div className="relative">
                  <IconCircle
                    icon={StepIcon}
                    color={STEP_COLORS[i]}
                    className="h-16 w-16"
                  />
                  <span className="absolute -top-2 -right-2 flex h-8 w-8 items-center justify-center rounded-full bg-white text-sm font-extrabold text-foreground">
                    {step.number}
                  </span>
                </div>
                <h3 className="mt-6 text-xl font-bold">{step.title}</h3>
                <p className="mt-3 max-w-xs text-gray-400">{step.desc}</p>
              </div>
            );
          })}
        </div>
      </SectionBlock>

      {/* ─── STATS ─── */}
      <SectionBlock color="white">
        <div className="text-center">
          <h2 className="text-3xl font-extrabold tracking-tight text-foreground sm:text-4xl lg:text-5xl">
            {stats("title")}
          </h2>
        </div>
        <div className="mt-14 grid grid-cols-2 gap-8 lg:grid-cols-4">
          {statItems.map((stat, i) => {
            const StatIcon = STAT_ICONS[i];
            return (
              <div
                key={i}
                className="group flex flex-col items-center text-center"
              >
                <div className="flex h-14 w-14 items-center justify-center rounded-full bg-muted">
                  <StatIcon
                    className={`h-7 w-7 ${STAT_COLORS[i]}`}
                    strokeWidth={2.25}
                  />
                </div>
                <span
                  className={`mt-4 text-4xl font-extrabold tracking-tight sm:text-5xl ${STAT_COLORS[i]}`}
                >
                  {stat.value}
                </span>
                <span className="mt-2 text-sm font-semibold uppercase tracking-wider text-gray-500">
                  {stat.label}
                </span>
              </div>
            );
          })}
        </div>
      </SectionBlock>

      {/* ─── FOR FARMERS ─── */}
      <SectionBlock color="secondary" decoration>
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl lg:text-5xl">
              {farmers("title")}
            </h2>
            <p className="mt-4 text-lg font-medium text-white/90">
              {farmers("subtitle")}
            </p>
            <ul className="mt-8 space-y-4">
              {farmerBenefits.map((benefit, i) => (
                <li key={i} className="flex items-start gap-3">
                  <span className="mt-1 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-white/20 text-xs font-bold">
                    ✓
                  </span>
                  <span className="text-white/95">{benefit}</span>
                </li>
              ))}
            </ul>
            <div className="mt-10">
              <Link href="/farmer/dashboard" className="inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 bg-white text-emerald-700 hover:bg-gray-100 transition-all">
                {farmers("cta")}
              </Link>
            </div>
          </div>
          {/* Geometric illustration */}
          <div
            className="flex items-center justify-center"
            aria-hidden="true"
          >
            <div className="relative">
              <div className="h-48 w-48 rounded-lg bg-white/10" />
              <div className="absolute -top-6 -right-6 h-32 w-32 rounded-full bg-white/15" />
              <div className="absolute -bottom-4 -left-4 h-24 w-24 rotate-12 rounded-lg bg-white/10" />
              <div className="absolute top-1/2 left-1/2 flex h-20 w-20 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-white/20">
                <Sprout className="h-10 w-10 text-white" strokeWidth={2} />
              </div>
            </div>
          </div>
        </div>
      </SectionBlock>

      {/* ─── FOR RIDERS ─── */}
      <SectionBlock color="accent" decoration>
        <div className="grid items-center gap-12 lg:grid-cols-2">
          {/* Geometric illustration */}
          <div
            className="order-2 flex items-center justify-center lg:order-1"
            aria-hidden="true"
          >
            <div className="relative">
              <div className="h-48 w-48 rounded-full bg-white/10" />
              <div className="absolute -top-4 -left-4 h-32 w-32 rotate-45 rounded-lg bg-white/15" />
              <div className="absolute -bottom-6 -right-6 h-28 w-28 rounded-full bg-white/10" />
              <div className="absolute top-1/2 left-1/2 flex h-20 w-20 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-white/20">
                <Truck
                  className="h-10 w-10 text-foreground"
                  strokeWidth={2}
                />
              </div>
            </div>
          </div>
          <div className="order-1 lg:order-2">
            <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl lg:text-5xl">
              {riders("title")}
            </h2>
            <p className="mt-4 text-lg font-medium text-foreground/80">
              {riders("subtitle")}
            </p>
            <ul className="mt-8 space-y-4">
              {riderBenefits.map((benefit, i) => (
                <li key={i} className="flex items-start gap-3">
                  <span className="mt-1 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-foreground/15 text-xs font-bold">
                    ✓
                  </span>
                  <span className="text-foreground/90">{benefit}</span>
                </li>
              ))}
            </ul>
            <div className="mt-10">
              <Link href="/rider/dashboard" className="inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 bg-foreground text-white hover:bg-gray-800 transition-all">
                {riders("cta")}
              </Link>
            </div>
          </div>
        </div>
      </SectionBlock>

      {/* ─── CTA SECTION ─── */}
      <SectionBlock color="primary" decoration className="py-24">
        <div
          className="absolute bottom-0 left-1/4 h-72 w-72 rounded-full bg-white/5"
          aria-hidden="true"
        />
        <div className="relative flex flex-col items-center text-center">
          <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl lg:text-5xl">
            {cta("title")}
          </h2>
          <p className="mt-6 max-w-xl text-lg font-medium text-white/90">
            {cta("subtitle")}
          </p>
          <div className="mt-10 flex flex-col gap-4 sm:flex-row">
            <Link href="/auth/login" className="inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 bg-white text-primary hover:bg-gray-100 hover:text-blue-700 transition-all">
              {cta("ctaPrimary")}
            </Link>
            <Link href="/marketplace" className="inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 border-4 border-white bg-transparent text-white hover:bg-white hover:text-primary transition-all">
              {cta("ctaSecondary")}
            </Link>
          </div>
        </div>
      </SectionBlock>

      {/* ─── FOOTER ─── */}
      <SectionBlock color="dark" className="py-12">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-5">
          {/* Brand column */}
          <div className="lg:col-span-2">
            <h3 className="text-2xl font-extrabold">{footer("brand")}</h3>
            <p className="mt-3 max-w-xs text-gray-400">{footer("tagline")}</p>
            {/* Social placeholders */}
            <div className="mt-6 flex gap-4">
              {["Facebook", "Twitter", "Instagram"].map((social) => (
                <div
                  key={social}
                  className="flex h-10 w-10 items-center justify-center rounded-md bg-white/10 text-xs font-semibold text-gray-400 transition-colors duration-200 hover:bg-white/20"
                >
                  {social[0]}
                </div>
              ))}
            </div>
          </div>

          {/* Product links */}
          <div>
            <h4 className="text-sm font-bold uppercase tracking-wider text-gray-400">
              {footer("productTitle")}
            </h4>
            <ul className="mt-4 space-y-2">
              {productLinks.map((item) => (
                <li key={item}>
                  <span className="cursor-pointer text-gray-400 transition-colors duration-200 hover:text-white">
                    {item}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          {/* Company links */}
          <div>
            <h4 className="text-sm font-bold uppercase tracking-wider text-gray-400">
              {footer("companyTitle")}
            </h4>
            <ul className="mt-4 space-y-2">
              {companyLinks.map((item) => (
                <li key={item}>
                  <span className="cursor-pointer text-gray-400 transition-colors duration-200 hover:text-white">
                    {item}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal links */}
          <div>
            <h4 className="text-sm font-bold uppercase tracking-wider text-gray-400">
              {footer("legalTitle")}
            </h4>
            <ul className="mt-4 space-y-2">
              {legalLinks.map((item) => (
                <li key={item}>
                  <span className="cursor-pointer text-gray-400 transition-colors duration-200 hover:text-white">
                    {item}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Contact + attribution */}
        <div className="mt-12 flex flex-col gap-4 border-t-2 border-white/10 pt-8 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-wrap gap-6 text-sm text-gray-500">
            <span className="inline-flex items-center gap-1.5">
              <Mail className="h-4 w-4" strokeWidth={2} />
              {footer("email")}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Phone className="h-4 w-4" strokeWidth={2} />
              {footer("phone")}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <MapPin className="h-4 w-4" strokeWidth={2} />
              {footer("address")}
            </span>
          </div>
          <p className="text-sm text-gray-600">{footer("mapAttribution")}</p>
        </div>

        <div className="mt-6 text-center text-sm text-gray-600">
          &copy; {new Date().getFullYear()} {footer("copyright")}
        </div>
      </SectionBlock>
    </main>
  );
}
