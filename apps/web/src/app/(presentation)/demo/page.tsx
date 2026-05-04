import type { Metadata } from "next";
import Image from "next/image";
import { ShoppingBag, Sprout, Smartphone, Building2, ClipboardCheck, CheckCircle2 } from "lucide-react";
import { SlideStage, type Slide } from "../SlideStage";

export const metadata: Metadata = {
  title: "JiriSewa — Demo Walkthrough",
};

const CAPTURES = "/deck-assets/captures";

type ShotProps = {
  chapter: string;
  chapterNe: string;
  step: string;
  titleNe: string;
  titleEn: string;
  description: string;
  src: string;
  alt: string;
  kind?: "desktop" | "mobile";
  accent?: "primary" | "secondary" | "accent";
};

function ShotSlide({
  chapter,
  chapterNe,
  step,
  titleNe,
  titleEn,
  description,
  src,
  alt,
  kind = "desktop",
  accent = "primary",
}: ShotProps) {
  const accentBg = {
    primary: "bg-primary",
    secondary: "bg-secondary",
    accent: "bg-accent",
  }[accent];
  const accentText = {
    primary: "text-primary",
    secondary: "text-secondary",
    accent: "text-amber-600",
  }[accent];

  return (
    <div className="grid h-full grid-cols-[1fr_1.4fr]">
      {/* Left: text panel */}
      <div className="flex flex-col justify-between bg-muted px-14 py-12">
        <div>
          <div className="flex items-center gap-2">
            <span
              className={`inline-flex h-7 items-center rounded-md ${accentBg} px-2.5 text-[11px] font-bold uppercase tracking-wider text-white`}
            >
              {chapter}
            </span>
            <span className={`np text-sm font-semibold ${accentText}`}>
              {chapterNe}
            </span>
          </div>
          <div className="mt-10 font-mono text-sm font-bold text-gray-400">
            {step}
          </div>
          <h2 className="np-display np mt-2 text-[2.6rem] font-bold leading-tight text-foreground">
            {titleNe}
          </h2>
          <div className="mt-2 text-lg font-medium text-gray-500">
            {titleEn}
          </div>
          <p className="mt-8 text-base leading-relaxed text-gray-700">
            {description}
          </p>
        </div>
        <div className="flex items-center gap-2 text-xs font-medium uppercase tracking-wider text-gray-400">
          <Sprout className="h-3.5 w-3.5" strokeWidth={2.25} />
          khetbata.xyz · jirisewa.com
        </div>
      </div>

      {/* Right: screenshot */}
      <div className="relative flex items-center justify-center bg-foreground p-10">
        {kind === "mobile" ? (
          <div className="relative h-[600px] w-[300px] overflow-hidden rounded-[2.5rem] border-[14px] border-white/10 bg-black">
            <Image
              src={src}
              alt={alt}
              fill
              className="object-cover object-top"
              sizes="300px"
            />
          </div>
        ) : (
          <div className="relative h-full w-full overflow-hidden rounded-md border border-white/10 bg-white">
            <Image
              src={src}
              alt={alt}
              fill
              className="object-contain"
              sizes="800px"
            />
          </div>
        )}
      </div>
    </div>
  );
}

const slides: Slide[] = [
  // Cover
  {
    id: "cover",
    bg: "bg-foreground deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <div className="text-sm font-bold uppercase tracking-[0.3em] text-white/50">
          JiriSewa
        </div>
        <h1 className="np-display np mt-6 text-[5.5rem] font-extrabold leading-none">
          प्लेटफर्म <span className="text-primary">walkthrough</span>
        </h1>
        <p className="mt-6 max-w-3xl text-xl text-white/70">
          A guided tour of every screen in the platform — consumer, farmer,
          rider, and pickup-hub operator.
        </p>

        <div className="mt-16 grid grid-cols-5 gap-4 text-sm">
          {[
            { i: ShoppingBag, label: "Consumer", count: "3 screens" },
            { i: Sprout, label: "Farmer", count: "1 screen" },
            { i: Smartphone, label: "Rider", count: "5 screens" },
            { i: Building2, label: "Drop off", count: "4 screens" },
            { i: ClipboardCheck, label: "Operator", count: "4 screens" },
          ].map(({ i: Icon, label, count }) => (
            <div
              key={label}
              className="flex flex-col items-center gap-2 rounded-lg bg-white/5 px-5 py-5"
            >
              <Icon className="h-6 w-6 text-primary" strokeWidth={2.25} />
              <div className="font-semibold">{label}</div>
              <div className="text-xs text-white/50">{count}</div>
            </div>
          ))}
        </div>

        <div className="mt-14 inline-flex items-center gap-3 rounded-md bg-white/5 px-5 py-3 text-xs font-medium text-white/60">
          <kbd className="rounded bg-white/10 px-2 py-0.5 font-mono">→</kbd>
          to advance ·
          <kbd className="rounded bg-white/10 px-2 py-0.5 font-mono">F</kbd>
          for fullscreen ·
          <kbd className="rounded bg-white/10 px-2 py-0.5 font-mono">?</kbd>
          for shortcuts
        </div>
      </div>
    ),
  },

  // CONSUMER — Chapter divider
  {
    id: "ch-consumer",
    bg: "bg-primary deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <ShoppingBag className="h-20 w-20 text-amber-300" strokeWidth={2} />
        <div className="mt-6 text-sm font-bold uppercase tracking-[0.4em] text-white/60">
          Chapter 1 / 5
        </div>
        <h2 className="np-display np mt-3 text-[5rem] font-extrabold leading-none">
          ग्राहकको यात्रा
        </h2>
        <div className="mt-3 text-2xl text-white/80">
          The consumer journey — Kathmandu kitchen to cart
        </div>
      </div>
    ),
  },
  {
    id: "consumer-marketplace",
    body: (
      <ShotSlide
        chapter="Consumer"
        chapterNe="ग्राहक"
        step="01 / 03"
        titleNe="बजार ब्राउज"
        titleEn="Browse the marketplace in Nepali"
        description="Filter by district, category, freshness, or distance. Listings come from real farmers — name + ward visible on every card. The Nepali UI is the default; English is one toggle away."
        src={`${CAPTURES}/04-consumer/01-marketplace-ne.png`}
        alt="Marketplace in Nepali"
        accent="primary"
      />
    ),
  },
  {
    id: "consumer-listing",
    body: (
      <ShotSlide
        chapter="Consumer"
        chapterNe="ग्राहक"
        step="02 / 03"
        titleNe="लिस्टिङ विवरण"
        titleEn="Listing detail — farmer, ward, freshness"
        description="Every listing shows the farmer behind it, the ward they farm in, the freshness date, and live availability. Photos come from the farmer's phone, not stock libraries."
        src={`${CAPTURES}/04-consumer/02-listing-detail.png`}
        alt="Produce listing detail"
        accent="primary"
      />
    ),
  },
  {
    id: "consumer-cart",
    body: (
      <ShotSlide
        chapter="Consumer"
        chapterNe="ग्राहक"
        step="03 / 03"
        titleNe="कार्ट र चेकआउट"
        titleEn="Cart, checkout, and cash-on-delivery"
        description="Multi-farmer carts are normal — one consumer order can pull from three different Jiri growers. Payment options include eSewa, Khalti, connectIPS, and cash on delivery."
        src={`${CAPTURES}/04-consumer/03-cart.png`}
        alt="Cart view"
        accent="primary"
      />
    ),
  },

  // FARMER — Chapter divider
  {
    id: "ch-farmer",
    bg: "bg-secondary deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <Sprout className="h-20 w-20 text-amber-300" strokeWidth={2} />
        <div className="mt-6 text-sm font-bold uppercase tracking-[0.4em] text-white/60">
          Chapter 2 / 5
        </div>
        <h2 className="np-display np mt-3 text-[5rem] font-extrabold leading-none">
          किसानको फोन
        </h2>
        <div className="mt-3 text-2xl text-white/85">
          What the farmer sees on their phone
        </div>
      </div>
    ),
  },
  {
    id: "farmer-dashboard",
    body: (
      <ShotSlide
        chapter="Farmer"
        chapterNe="किसान"
        step="01 / 01"
        titleNe="किसान ड्यासबोर्ड"
        titleEn="Farmer dashboard — orders, earnings, listings"
        description="One screen shows pending orders, earnings to date, and active listings. Toggle the language at any time — every label, button, and message renders in Nepali. Built for low-literacy farmers: icons + words, never icons alone."
        src={`${CAPTURES}/05-farmer/01-dashboard.png`}
        alt="Farmer dashboard"
        accent="secondary"
      />
    ),
  },

  // RIDER — Chapter divider
  {
    id: "ch-rider",
    bg: "bg-accent deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center">
        <Smartphone className="h-20 w-20 text-foreground" strokeWidth={2} />
        <div className="mt-6 text-sm font-bold uppercase tracking-[0.4em] text-foreground/60">
          Chapter 3 / 5
        </div>
        <h2 className="np-display np mt-3 text-[5rem] font-extrabold leading-none text-foreground">
          राइडरको एप
        </h2>
        <div className="mt-3 text-2xl text-foreground/80">
          The rider&apos;s Android app — Jiri ↔ Kathmandu
        </div>
      </div>
    ),
  },
  {
    id: "rider-launch",
    body: (
      <ShotSlide
        chapter="Rider"
        chapterNe="राइडर"
        step="01 / 05"
        titleNe="एप खोल्दा"
        titleEn="App launched — first screen"
        description="The rider opens the app on their Android phone. Sign-in supports phone OTP or Google. Built native: works on a 3G connection, caches routes offline."
        src={`${CAPTURES}/06-rider/00-app-launched.png`}
        alt="Rider app launched"
        kind="mobile"
        accent="accent"
      />
    ),
  },
  {
    id: "rider-email",
    body: (
      <ShotSlide
        chapter="Rider"
        chapterNe="राइडर"
        step="02 / 05"
        titleNe="साइन इन"
        titleEn="Sign in — phone OTP or Google"
        description="Two paths — phone OTP for riders without an email, Google for those who already have one. Either way, no password to forget, no SIM-card friction."
        src={`${CAPTURES}/06-rider/01-email-tab.png`}
        alt="Email sign-in"
        kind="mobile"
        accent="accent"
      />
    ),
  },
  {
    id: "rider-after-signin",
    body: (
      <ShotSlide
        chapter="Rider"
        chapterNe="राइडर"
        step="03 / 05"
        titleNe="साइन इन पछि"
        titleEn="Signed-in home — matched orders"
        description="The rider sees orders that match their scheduled trip route. OSRM-routed pickup sequence, estimated earnings, and detour distance are all visible up-front."
        src={`${CAPTURES}/06-rider/02-after-signin.png`}
        alt="Rider home after sign-in"
        kind="mobile"
        accent="accent"
      />
    ),
  },
  {
    id: "rider-farmer-home",
    body: (
      <ShotSlide
        chapter="Rider"
        chapterNe="राइडर"
        step="04 / 05"
        titleNe="किसानको ठाउँमा"
        titleEn="At the farmer's location"
        description="Multi-stop trips show every farmer pickup in order, with map navigation and a one-tap confirmation per stop. Capacity (kg) is tracked live."
        src={`${CAPTURES}/06-rider/03-farmer-home.png`}
        alt="Rider at farmer location"
        kind="mobile"
        accent="accent"
      />
    ),
  },
  {
    id: "rider-profile",
    body: (
      <ShotSlide
        chapter="Rider"
        chapterNe="राइडर"
        step="05 / 05"
        titleNe="प्रोफाइल"
        titleEn="Rider profile — earnings, ratings, vehicle"
        description="Earnings to date, average consumer rating, and vehicle capacity all in one place. Verified-rider badge appears once documents are reviewed."
        src={`${CAPTURES}/06-rider/04-profile.png`}
        alt="Rider profile"
        kind="mobile"
        accent="accent"
      />
    ),
  },

  // DROP OFF — Chapter divider
  {
    id: "ch-dropoff",
    bg: "bg-foreground deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <Building2 className="h-20 w-20 text-secondary" strokeWidth={2} />
        <div className="mt-6 text-sm font-bold uppercase tracking-[0.4em] text-white/60">
          Chapter 4 / 5
        </div>
        <h2 className="np-display np mt-3 text-[5rem] font-extrabold leading-none">
          हबमा छाड्ने
        </h2>
        <div className="mt-3 text-2xl text-white/80">
          Farmer drops off at the Koseli Ghar pickup hub
        </div>
      </div>
    ),
  },
  {
    id: "dropoff-form-mobile",
    body: (
      <ShotSlide
        chapter="Drop off"
        chapterNe="हबमा छाड्ने"
        step="01 / 04"
        titleNe="फारम — मोबाइल"
        titleEn="Drop-off form on the farmer's phone"
        description="Hub pre-selected to जिरी बजार हब. Farmer enters quantity in kg, selects produce, and submits. Three fields, one button — designed for thumb-typing in a field."
        src={`${CAPTURES}/mobile-08-dropoff/01-form.png`}
        alt="Drop-off form on mobile"
        kind="mobile"
        accent="primary"
      />
    ),
  },
  {
    id: "dropoff-success-mobile",
    body: (
      <ShotSlide
        chapter="Drop off"
        chapterNe="हबमा छाड्ने"
        step="02 / 04"
        titleNe="लट कोड — मोबाइल"
        titleEn="Lot code on the farmer's phone"
        description="Three seconds after submit, a printable lot code appears (e.g. NYGJ38). Farmer takes it to the Koseli Ghar counter — paper or screen, both work."
        src={`${CAPTURES}/mobile-08-dropoff/02-success.png`}
        alt="Lot code success on mobile"
        kind="mobile"
        accent="primary"
      />
    ),
  },
  {
    id: "dropoff-form-desktop",
    body: (
      <ShotSlide
        chapter="Drop off"
        chapterNe="हबमा छाड्ने"
        step="03 / 04"
        titleNe="फारम — डेस्कटप"
        titleEn="Drop-off form on a tablet"
        description="The same form on a hub tablet — used when the farmer prefers to dictate the entry to the operator. Same pre-selected hub, same lot-code output."
        src={`${CAPTURES}/08-dropoff/01-form.png`}
        alt="Drop-off form on desktop"
        accent="primary"
      />
    ),
  },
  {
    id: "dropoff-success-desktop",
    body: (
      <ShotSlide
        chapter="Drop off"
        chapterNe="हबमा छाड्ने"
        step="04 / 04"
        titleNe="लट कोड — डेस्कटप"
        titleEn="Lot code printable from the tablet"
        description="From the tablet, the lot code can be printed directly to a thermal label printer at the counter. Same code, same farmer record, paper trail intact."
        src={`${CAPTURES}/08-dropoff/02-success.png`}
        alt="Lot code success on desktop"
        accent="primary"
      />
    ),
  },

  // OPERATOR — Chapter divider
  {
    id: "ch-operator",
    bg: "bg-primary deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <ClipboardCheck className="h-20 w-20 text-amber-300" strokeWidth={2} />
        <div className="mt-6 text-sm font-bold uppercase tracking-[0.4em] text-white/60">
          Chapter 5 / 5
        </div>
        <h2 className="np-display np mt-3 text-[5rem] font-extrabold leading-none">
          सञ्चालकको पैनल
        </h2>
        <div className="mt-3 text-2xl text-white/85">
          The Koseli Ghar operator confirms inventory
        </div>
      </div>
    ),
  },
  {
    id: "operator-all",
    body: (
      <ShotSlide
        chapter="Operator"
        chapterNe="सञ्चालक"
        step="01 / 04"
        titleNe="सबै इन्भेन्टरी"
        titleEn="Inventory — all rows at a glance"
        description="The operator's home view. Every drop-off across every farmer, with status, weight, and timestamp. Filterable by ward, by farmer, by produce."
        src={`${CAPTURES}/09-operator/01-inventory-all.png`}
        alt="Operator inventory all"
        accent="primary"
      />
    ),
  },
  {
    id: "operator-awaiting",
    body: (
      <ShotSlide
        chapter="Operator"
        chapterNe="सञ्चालक"
        step="02 / 04"
        titleNe="स्वीकृति बाँकी"
        titleEn="Pending acceptance — the queue"
        description="Drop-offs waiting for the operator's physical confirmation. The operator weighs the bag, matches the lot code, and clicks Accept."
        src={`${CAPTURES}/09-operator/02-awaiting.png`}
        alt="Operator awaiting acceptance"
        accent="primary"
      />
    ),
  },
  {
    id: "operator-accepted",
    body: (
      <ShotSlide
        chapter="Operator"
        chapterNe="सञ्चालक"
        step="03 / 04"
        titleNe="स्वीकार पछि"
        titleEn="After accepting — farmer gets a notification"
        description="The instant the operator accepts, the farmer's phone buzzes: तपाईंको कोशेली घरमा प्राप्त भयो. The platform now has live, audited weight."
        src={`${CAPTURES}/09-operator/03-after-mark-received.png`}
        alt="Operator after mark received"
        accent="primary"
      />
    ),
  },
  {
    id: "operator-in-inventory",
    body: (
      <ShotSlide
        chapter="Operator"
        chapterNe="सञ्चालक"
        step="04 / 04"
        titleNe="इन्भेन्टरीमा"
        titleEn="Now in inventory — visible to consumers"
        description="The bag is in inventory and listed for Kathmandu consumers within seconds. The same row is also exported nightly to the municipality data dashboard."
        src={`${CAPTURES}/09-operator/04-in-inventory.png`}
        alt="Operator in inventory"
        accent="primary"
      />
    ),
  },

  // Closing
  {
    id: "closing",
    bg: "bg-secondary deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <CheckCircle2 className="h-20 w-20 text-amber-300" strokeWidth={2} />
        <h2 className="np-display np mt-8 text-[4.5rem] font-extrabold leading-tight">
          जिरीदेखि <span className="text-amber-300">घरसम्म</span>
        </h2>
        <div className="mt-4 text-2xl text-white/85">
          From the Koseli Ghar counter to the Kathmandu doorstep — every step,
          on one platform.
        </div>

        <div className="mt-14 flex items-center gap-8 text-white/85">
          <div className="flex items-center gap-2">
            <Sprout className="h-6 w-6" strokeWidth={2.25} />
            <span className="np text-base font-semibold">किसान</span>
          </div>
          <span className="text-white/40">→</span>
          <div className="flex items-center gap-2">
            <Building2 className="h-6 w-6" strokeWidth={2.25} />
            <span className="np text-base font-semibold">कोशेली घर</span>
          </div>
          <span className="text-white/40">→</span>
          <div className="flex items-center gap-2">
            <Smartphone className="h-6 w-6" strokeWidth={2.25} />
            <span className="np text-base font-semibold">राइडर</span>
          </div>
          <span className="text-white/40">→</span>
          <div className="flex items-center gap-2">
            <ShoppingBag className="h-6 w-6" strokeWidth={2.25} />
            <span className="np text-base font-semibold">ग्राहक</span>
          </div>
        </div>

        <div className="mt-16 inline-flex items-center gap-3 rounded-md bg-white/10 px-6 py-3 font-mono text-sm">
          khetbata.xyz / jirisewa.com
        </div>
      </div>
    ),
  },
];

export default function DemoPage() {
  return <SlideStage slides={slides} />;
}
