import type { Metadata } from "next";
import Image from "next/image";
import { ArrowRight, Sprout, Truck, ShoppingBag } from "lucide-react";
import { SlideStage, type Slide } from "../SlideStage";

export const metadata: Metadata = {
  title: "JiriSewa — Jiri Nagarpalika Deck",
};

const CAPTURES = "/deck-assets/captures";

const slides: Slide[] = [
  // 1 — Title
  {
    id: "title",
    bg: "bg-primary deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <div className="text-sm font-bold uppercase tracking-[0.3em] text-white/70">
          JiriSewa
        </div>
        <h1 className="np-display np mt-6 text-[6rem] font-extrabold leading-none">
          जिरीदेखि सुरु,
          <br />
          <span className="text-amber-300">नेपालभर पुग्ने</span>
        </h1>
        <p className="mt-8 text-2xl font-medium text-white/80">
          starts in Jiri, scales to Nepal
        </p>
        <div className="mt-20 flex items-center gap-3 text-white/70">
          <span className="np text-base">
            जिरी नगरपालिकालाई प्रस्तुति • २०८३ बैशाख १७
          </span>
          <span className="text-white/30">·</span>
          <span className="text-base">Presentation to Jiri Nagarpalika · 30 April 2026</span>
        </div>
      </div>
    ),
    notes: (
      <p>
        Open in Nepali: &ldquo;नमस्ते। म आज तपाईंलाई एउटा वाक्य सुनाएर सुरु गर्न
        चाहन्छु — तपाईंकै वेबसाइटबाट लिएको।&rdquo;
        <br />
        Belief target: B (Jiri-first, Nepal-next). 0:30.
      </p>
    ),
  },

  // 2 — Quote from jirimun.gov.np
  {
    id: "quote",
    bg: "bg-background",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-32 text-center">
        <div className="absolute top-12 left-1/2 -translate-x-1/2 text-xs font-bold uppercase tracking-[0.4em] text-gray-400">
          From the source
        </div>
        <div className="np text-[3.6rem] font-semibold leading-[1.35] text-foreground">
          &ldquo;नगरमा आउने पर्यटकहरूले यस्ता कृषि उपजलाई खोजी खोजी उपहारको
          रूपमा लैजाने गरेका छन्।&rdquo;
        </div>
        <div className="mt-12 max-w-2xl text-xl text-gray-500">
          &ldquo;Tourists who come to the city actively seek out these
          agricultural products and take them as gifts.&rdquo;
        </div>
        <div className="mt-16 inline-flex items-center gap-2 rounded-md bg-muted px-5 py-3 text-sm font-medium text-gray-600">
          jirimun.gov.np <span className="text-gray-300">›</span> परिचय{" "}
          <span className="text-gray-300">›</span> संक्षिप्त परिचय
        </div>
      </div>
    ),
    notes: (
      <p>
        Read it once, pause, then pivot: &ldquo;the demand is real — but
        here&apos;s what blocks Jiri&apos;s farmers from capturing it.&rdquo;
        Set up the next slide. 1:00.
      </p>
    ),
  },

  // 3 — The middleman problem
  {
    id: "middleman-problem",
    bg: "bg-background",
    body: (
      <div className="flex h-full flex-col px-14 py-12">
        <div>
          <div className="np-display np text-5xl font-bold text-foreground">
            बीचमा बसेका बिचौलिया
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            The real problem isn&apos;t supply or demand — it&apos;s who sits
            between them
          </div>
        </div>

        {/* Chain */}
        <div className="mt-12 flex items-center justify-between gap-2">
          {/* Farmer */}
          <div className="flex w-[150px] flex-col items-center gap-1 rounded-md bg-secondary px-3 py-5 text-white">
            <div className="np text-base font-bold">किसान</div>
            <div className="text-[11px] uppercase tracking-wider opacity-80">
              Farmer
            </div>
            <div className="mt-2 text-2xl font-extrabold">रु. १००</div>
          </div>
          {/* Arrow + markup */}
          <div className="flex flex-col items-center gap-1 px-1">
            <ArrowRight className="h-5 w-5 text-gray-300" strokeWidth={2.5} />
            <span className="rounded-md bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-700">
              + ५०
            </span>
          </div>
          <div className="flex w-[150px] flex-col items-center gap-1 rounded-md bg-muted px-3 py-5">
            <div className="np text-base font-bold text-foreground">संकलक</div>
            <div className="text-[11px] uppercase tracking-wider text-gray-500">
              Aggregator
            </div>
          </div>
          <div className="flex flex-col items-center gap-1 px-1">
            <ArrowRight className="h-5 w-5 text-gray-300" strokeWidth={2.5} />
            <span className="rounded-md bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-700">
              + ५०
            </span>
          </div>
          <div className="flex w-[150px] flex-col items-center gap-1 rounded-md bg-muted px-3 py-5">
            <div className="np text-base font-bold text-foreground">थोक</div>
            <div className="text-[11px] uppercase tracking-wider text-gray-500">
              Wholesaler
            </div>
          </div>
          <div className="flex flex-col items-center gap-1 px-1">
            <ArrowRight className="h-5 w-5 text-gray-300" strokeWidth={2.5} />
            <span className="rounded-md bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-700">
              + १००
            </span>
          </div>
          <div className="flex w-[150px] flex-col items-center gap-1 rounded-md bg-muted px-3 py-5">
            <div className="np text-base font-bold text-foreground">खुद्रा</div>
            <div className="text-[11px] uppercase tracking-wider text-gray-500">
              Retailer
            </div>
          </div>
          <div className="flex flex-col items-center px-1">
            <ArrowRight className="h-5 w-5 text-gray-300" strokeWidth={2.5} />
          </div>
          <div className="flex w-[150px] flex-col items-center gap-1 rounded-md bg-foreground px-3 py-5 text-white">
            <div className="np text-base font-bold">ग्राहक</div>
            <div className="text-[11px] uppercase tracking-wider opacity-80">
              Consumer
            </div>
            <div className="mt-2 text-2xl font-extrabold">रु. ३००</div>
          </div>
        </div>

        <div className="mt-2 text-center text-[11px] uppercase tracking-wider text-gray-400">
          उदाहरण · illustrative — exact ratios vary by produce
        </div>

        {/* Stats */}
        <div className="mt-10 grid grid-cols-3 gap-6 text-center">
          <div className="rounded-md bg-emerald-50 p-5">
            <div className="text-5xl font-extrabold text-secondary">~33%</div>
            <div className="np mt-2 text-sm font-semibold text-foreground">
              किसानले पाउने
            </div>
            <div className="text-xs text-gray-500">What the farmer keeps</div>
          </div>
          <div className="rounded-md bg-amber-50 p-5">
            <div className="text-5xl font-extrabold text-amber-600">~67%</div>
            <div className="np mt-2 text-sm font-semibold text-foreground">
              बीचमा हराउने
            </div>
            <div className="text-xs text-gray-500">Lost to middlemen</div>
          </div>
          <div className="rounded-md bg-muted p-5">
            <div className="text-5xl font-extrabold text-foreground">3×</div>
            <div className="np mt-2 text-sm font-semibold text-foreground">
              ग्राहकको मूल्य
            </div>
            <div className="text-xs text-gray-500">What the consumer pays</div>
          </div>
        </div>

        <div className="mt-auto rounded-md bg-foreground px-6 py-4 text-center text-white">
          <div className="np text-xl font-bold">
            किसानले उत्पादन गर्छन्। बिचौलियाले मूल्य पाउँछन्।
          </div>
          <div className="text-sm text-white/70">
            Farmers grow it. Middlemen capture the value.
          </div>
        </div>
      </div>
    ),
    notes: (
      <p>
        Numbers are illustrative — the structure is what matters: 3+ layers
        between farm and plate, each taking a cut. If asked, soften: &ldquo;the
        ratios vary by crop and season, but the pattern is the same.&rdquo;
        Belief: A. 2:00.
      </p>
    ),
  },

  // 4 — The Pathao parable
  {
    id: "pathao-parable",
    bg: "bg-background",
    body: (
      <div className="flex h-full flex-col px-14 py-12">
        <div>
          <div className="np-display np text-5xl font-bold text-foreground">
            जसरी पठाओले ट्याक्सी कार्टेल तोड्यो
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            How Pathao broke the taxi cartel — same playbook, different
            industry
          </div>
        </div>

        <div className="mt-10 grid flex-1 grid-cols-2 gap-6">
          <div className="flex flex-col rounded-lg bg-muted p-10">
            <div className="text-xs font-bold uppercase tracking-wider text-gray-500">
              Before · पठाओ अघि
            </div>
            <div className="np mt-3 text-3xl font-bold text-foreground">
              ट्याक्सी कार्टेल
            </div>
            <ul className="mt-8 space-y-4 text-lg text-gray-700">
              <li className="flex gap-3">
                <span className="text-gray-400">×</span>
                <span className="np">मिटर बिग्रिएको</span>
              </li>
              <li className="flex gap-3">
                <span className="text-gray-400">×</span>
                <span className="np">कार्टेलले मूल्य तय गर्छ</span>
              </li>
              <li className="flex gap-3">
                <span className="text-gray-400">×</span>
                <span className="np">ड्राइभरले आधा मात्र पाउँछन्</span>
              </li>
              <li className="flex gap-3">
                <span className="text-gray-400">×</span>
                <span className="np">रिफ्युजल, अनिश्चितता</span>
              </li>
            </ul>
          </div>

          <div className="flex flex-col rounded-lg bg-primary p-10 text-white">
            <div className="text-xs font-bold uppercase tracking-wider text-white/70">
              After · पठाओ पछि
            </div>
            <div className="np mt-3 text-3xl font-bold">सिधा एप</div>
            <ul className="mt-8 space-y-4 text-lg text-white/95">
              <li className="flex gap-3">
                <span className="text-amber-300">✓</span>
                <span className="np">पारदर्शी मूल्य</span>
              </li>
              <li className="flex gap-3">
                <span className="text-amber-300">✓</span>
                <span className="np">ड्राइभरले धेरै बढी पाउँछन्</span>
              </li>
              <li className="flex gap-3">
                <span className="text-amber-300">✓</span>
                <span className="np">ग्राहकले कम तिर्छन्</span>
              </li>
              <li className="flex gap-3">
                <span className="text-amber-300">✓</span>
                <span className="np">रेटिङ, जवाफदेहिता</span>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-x-4 gap-y-1 rounded-md bg-secondary px-6 py-4 text-center text-white">
          <span className="np text-2xl font-bold">
            कृषिमा पनि उही कुरा गर्न सकिन्छ।
          </span>
          <span className="text-white/50">·</span>
          <span className="text-base">
            JiriSewa is to agriculture what Pathao was to taxis.
          </span>
        </div>
      </div>
    ),
    notes: (
      <p>
        Use the room&apos;s familiarity. Everyone in this hall has used
        Pathao. The analogy carries the rest of the talk. Belief: A + B.
        2:00.
      </p>
    ),
  },

  // 5 — Today vs Tomorrow (direct-route framing)
  {
    id: "today-tomorrow",
    bg: "bg-background",
    body: (
      <div className="grid h-full grid-cols-2">
        <div className="flex flex-col justify-center bg-muted px-16 py-20">
          <div className="np text-2xl font-bold text-gray-700">आज</div>
          <div className="text-sm font-medium uppercase tracking-wider text-gray-500">
            Today
          </div>
          <ul className="np mt-10 space-y-5 text-2xl font-medium text-gray-700">
            <li className="flex gap-3">
              <span className="text-gray-400">·</span> किसान दिनभर बजार
              पुर्‍याउँछन्
            </li>
            <li className="flex gap-3">
              <span className="text-gray-400">·</span> मूल्य अरूले तय गर्छन्
            </li>
            <li className="flex gap-3">
              <span className="text-gray-400">·</span> तीन हात पार गर्दा १००{" "}
              <span className="text-gray-400">→</span> ३००
            </li>
            <li className="flex gap-3 font-bold text-foreground">
              <span className="text-gray-400">·</span> किसानले एक-तिहाइ मात्र
              पाउँछन्
            </li>
          </ul>
        </div>
        <div className="flex flex-col justify-center bg-secondary px-16 py-20 text-white">
          <div className="np text-2xl font-bold">भोलि — जिरीसेवासँग</div>
          <div className="text-sm font-medium uppercase tracking-wider text-white/70">
            Tomorrow with JiriSewa
          </div>
          <ul className="np mt-10 space-y-5 text-2xl font-medium text-white/95">
            <li className="flex gap-3">
              <span className="text-white/50">·</span> किसानले आफ्नो मूल्य तय
              गर्छन्
            </li>
            <li className="flex gap-3">
              <span className="text-white/50">·</span> एउटै राइडर — सीधा
              काठमाडौँको घरसम्म
            </li>
            <li className="flex gap-3">
              <span className="text-white/50">·</span> बीचमा कुनै हात छैन
            </li>
            <li className="flex gap-3 font-bold text-amber-200">
              <span className="text-white/50">·</span> किसानले बढी, ग्राहकले
              कम
            </li>
          </ul>
        </div>
      </div>
    ),
    notes: (
      <p>
        Direct-route framing. The tourist appeal is a side-benefit, not the
        lead. The win is: Jiri farmer captures the value Kathmandu is willing
        to pay. Belief: A. 1:30.
      </p>
    ),
  },

  // 6 — Consumer
  {
    id: "consumer",
    bg: "bg-background",
    body: (
      <div className="grid h-full grid-cols-[1.1fr_1fr] gap-12 px-16 py-14">
        <div className="flex flex-col">
          <div className="np-display np text-5xl font-bold text-foreground">
            काठमाडौँको ग्राहक, सीधै किसानसँग
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            A Kathmandu consumer, ordering directly from a Jiri farmer
          </div>

          <div className="mt-8 rounded-lg bg-muted p-8">
            <div className="text-xs font-bold uppercase tracking-wider text-primary">
              Live demo
            </div>
            <ol className="mt-4 space-y-3 text-lg text-foreground">
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">1</span>
                Open <code className="rounded bg-white px-2 py-0.5 text-base">khetbata.xyz/ne/marketplace</code>
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">2</span>
                Filter by &ldquo;<span className="np">जिरी</span>&rdquo;
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">3</span>
                Open kiwi listing — note farmer name + ward
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">4</span>
                Add to cart, head to checkout
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">5</span>
                Place a cash order
              </li>
            </ol>
          </div>

          <p className="np mt-6 text-sm italic text-gray-500">
            यो लिस्टिङ्ग आज मात्र seed गरिएको हो — हाम्रो पहिलो जिरी किसानको
            नामांकन तपाईंको स्वीकृतिपछि हुनेछ।
          </p>
        </div>
        <div className="relative overflow-hidden rounded-md bg-muted">
          <Image
            src={`${CAPTURES}/04-consumer/01-marketplace-ne.png`}
            alt="Marketplace listing for Jiri kiwi"
            fill
            className="object-cover object-top"
            sizes="640px"
          />
        </div>
      </div>
    ),
    notes: <p>The honest sentence is on the slide. Don&apos;t skip it. 3:00.</p>,
  },

  // 5 — Farmer
  {
    id: "farmer",
    bg: "bg-background",
    body: (
      <div className="grid h-full grid-cols-[1fr_1.1fr] gap-12 px-16 py-14">
        <div className="relative overflow-hidden rounded-md bg-muted">
          <Image
            src={`${CAPTURES}/05-farmer/01-dashboard.png`}
            alt="Farmer dashboard"
            fill
            className="object-cover object-top"
            sizes="640px"
          />
        </div>
        <div className="flex flex-col">
          <div className="np-display np text-5xl font-bold text-foreground">
            किसानले फोनबाट यस्तो देख्छन्
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            What the farmer sees on their phone
          </div>

          <div className="mt-8 rounded-lg bg-muted p-8">
            <div className="text-xs font-bold uppercase tracking-wider text-primary">
              Live demo
            </div>
            <ol className="mt-4 space-y-3 text-lg text-foreground">
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">1</span>
                Sign in as the seeded farmer (<span className="np">नमुना जिरेल</span>)
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">2</span>
                Show pending orders + earnings
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">3</span>
                Toggle UI to Nepali → all labels render
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">4</span>
                Show listings with <span className="np">कोशेली घर</span> /
                hub drop-off enabled
              </li>
            </ol>
          </div>
        </div>
      </div>
    ),
    notes: (
      <p>
        Both Nepali and English. Even low-literacy farmers can navigate by icon
        + word. 2:00.
      </p>
    ),
  },

  // 6 — Rider phone
  {
    id: "rider",
    bg: "bg-foreground",
    body: (
      <div className="relative grid h-full grid-cols-[1fr_auto_1fr] items-center px-16 text-white">
        <div className="text-right">
          <div className="np-display np text-5xl font-bold">राइडरको फोन</div>
          <div className="mt-3 text-lg text-white/60">
            The rider&apos;s view — Android, in your hand
          </div>
          <div className="mt-10 inline-flex flex-col gap-3 rounded-lg bg-white/5 p-6 text-left">
            <div className="text-xs font-bold uppercase tracking-wider text-amber-300">
              In their pocket today
            </div>
            <ul className="space-y-2 text-base text-white/80">
              <li className="np">· रुटसँग मिल्ने अर्डर</li>
              <li className="np">· एक थपक्कीमा स्वीकार</li>
              <li>· OSRM-routed pickup sequence</li>
            </ul>
          </div>
        </div>

        <div className="relative h-[600px] w-[300px] overflow-hidden rounded-[2.5rem] border-[14px] border-white/10 bg-black">
          <Image
            src={`${CAPTURES}/06-rider/00-app-launched.png`}
            alt="Rider app on Android"
            fill
            className="object-cover object-top"
            sizes="300px"
          />
        </div>

        <div>
          <div className="grid grid-cols-2 gap-3">
            {[
              "01-email-tab.png",
              "02-after-signin.png",
              "03-farmer-home.png",
              "04-profile.png",
            ].map((f) => (
              <div
                key={f}
                className="relative aspect-[9/16] overflow-hidden rounded-md border border-white/10 bg-black"
              >
                <Image
                  src={`${CAPTURES}/06-rider/${f}`}
                  alt={f}
                  fill
                  className="object-cover object-top"
                  sizes="180px"
                />
              </div>
            ))}
          </div>
        </div>
      </div>
    ),
    notes: (
      <p>
        Pull out the actual phone. Hold it up. Cuttable if running long. 1:00.
      </p>
    ),
  },

  // 7 — Hub framing pivot
  {
    id: "hub",
    bg: "bg-background",
    body: (
      <div className="flex h-full flex-col px-20 py-14">
        <div>
          <div className="np-display np text-5xl font-bold text-foreground">
            हब = कोशेली घर × जिरीसेवा
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            The pickup hub: where Koseli Ghar meets JiriSewa
          </div>
        </div>

        <div className="mt-12 grid grid-cols-[1fr_auto_1fr] items-center gap-8">
          <div className="rounded-lg bg-emerald-50 p-10">
            <div className="np text-3xl font-bold text-secondary">
              कोशेली घर
            </div>
            <div className="text-sm font-medium uppercase tracking-wider text-gray-500">
              Koseli Ghar — your existing program
            </div>
            <ul className="np mt-6 space-y-3 text-lg text-foreground">
              <li>· भौतिक खुद्रा बिक्री</li>
              <li>· पर्यटक हिँडेर पस्न सक्ने</li>
              <li>· कोशेली / उपहार बिक्री</li>
            </ul>
          </div>

          <div className="grid h-16 w-16 place-items-center rounded-full bg-foreground text-3xl font-extrabold text-white">
            ×
          </div>

          <div className="rounded-lg bg-blue-50 p-10">
            <div className="np text-3xl font-bold text-primary">
              जिरीसेवा पिकअप हब
            </div>
            <div className="text-sm font-medium uppercase tracking-wider text-gray-500">
              JiriSewa pickup hub — our digital layer
            </div>
            <ul className="np mt-6 space-y-3 text-lg text-foreground">
              <li>· डिजिटल इनटेक</li>
              <li>· काठमाडौँमा डेलिभरी</li>
              <li>· वर्षभर</li>
            </ul>
          </div>
        </div>

        <div className="mt-12 rounded-md bg-muted py-6 text-center">
          <div className="np text-2xl font-bold text-foreground">
            एउटै ठाउँ। दुई बजार। पर्यटक र काठमाडौँ — दुवै।
          </div>
          <div className="mt-1 text-base text-gray-500">
            One place. Two markets. Tourists and Kathmandu — both.
          </div>
        </div>
      </div>
    ),
    notes: (
      <p>
        This slide is the framing pivot. Do not rush. Belief: B. 2:30.
      </p>
    ),
  },

  // 8 — Drop off
  {
    id: "dropoff",
    bg: "bg-background",
    body: (
      <div className="grid h-full grid-cols-[1fr_1.1fr] gap-12 px-16 py-14">
        <div className="relative overflow-hidden rounded-md bg-muted">
          <Image
            src={`${CAPTURES}/08-dropoff/02-success.png`}
            alt="Lot code success card"
            fill
            className="object-cover object-top"
            sizes="640px"
          />
        </div>
        <div className="flex flex-col">
          <div className="np-display np text-5xl font-bold text-foreground">
            किसानले हबमा छाड्छन्
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            Live: the farmer drops off 5 kg of kiwi
          </div>

          <div className="mt-8 rounded-lg bg-muted p-8">
            <div className="text-xs font-bold uppercase tracking-wider text-primary">
              Live demo
            </div>
            <ol className="mt-4 space-y-3 text-lg text-foreground">
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">1</span>
                Farmer signs in
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">2</span>
                <span className="np">हबमा छाड्नुहोस्</span> (Drop off at hub)
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">3</span>
                Pre-selected: <span className="np font-semibold">जिरी बजार हब</span>
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">4</span>
                Quantity: <span className="font-semibold">5 kg</span>
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">5</span>
                Submit → lot code{" "}
                <code className="rounded bg-white px-2 py-0.5 font-mono text-base">
                  NYGJ38
                </code>
              </li>
            </ol>
          </div>
          <p className="mt-5 text-sm italic text-gray-500">
            Pull printed lot-code label out of pocket; pass around.
          </p>
        </div>
      </div>
    ),
    notes: <p>The tactile moment matters. Officials touch real paper. 2:30.</p>,
  },

  // 9 — Operator confirms
  {
    id: "operator",
    bg: "bg-background",
    body: (
      <div className="grid h-full grid-cols-[1.1fr_1fr] gap-12 px-16 py-14">
        <div className="flex flex-col">
          <div className="np-display np text-5xl font-bold text-foreground">
            सञ्चालकले स्वीकृत गर्छन्
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            Live: the operator confirms
          </div>

          <div className="mt-8 rounded-lg bg-muted p-8">
            <div className="text-xs font-bold uppercase tracking-wider text-primary">
              Live demo
            </div>
            <ol className="mt-4 space-y-3 text-lg text-foreground">
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">1</span>
                Switch to operator account
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">2</span>
                <span className="np">स्वीकृति बाँकी</span> tab — the §8 dropoff
                is there
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">3</span>
                Click <span className="np font-semibold">स्वीकार गर्नुहोस्</span>
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">4</span>
                Row moves to <span className="np font-semibold">इन्भेन्टरीमा</span>
              </li>
              <li className="flex gap-4">
                <span className="font-mono font-bold text-primary">5</span>
                Farmer&apos;s phone:{" "}
                <span className="np italic">
                  &ldquo;तपाईंको कोशेली घरमा प्राप्त भयो&rdquo;
                </span>
              </li>
            </ol>
          </div>
        </div>
        <div className="relative overflow-hidden rounded-md bg-muted">
          <Image
            src={`${CAPTURES}/09-operator/03-after-mark-received.png`}
            alt="Inventory after received"
            fill
            className="object-cover object-top"
            sizes="640px"
          />
        </div>
      </div>
    ),
    notes: (
      <p>
        That moment gives us the right to show live data on the next slide.
        1:30.
      </p>
    ),
  },

  // 10 — Live ward counters
  {
    id: "counters",
    bg: "bg-foreground deck-geo",
    body: (
      <div className="relative flex h-full flex-col px-20 py-14 text-white">
        <div className="flex items-end justify-between">
          <div>
            <div className="np-display np text-5xl font-bold">
              तपाईंको वडा, आज, प्लेटफर्ममा
            </div>
            <div className="mt-2 text-lg text-white/60">
              Your ward on JiriSewa today
            </div>
          </div>
          <div className="inline-flex items-center gap-2 rounded-full bg-secondary px-4 py-2 text-sm font-bold uppercase tracking-wider">
            <span className="h-2 w-2 animate-pulse rounded-full bg-white" />
            Live
          </div>
        </div>

        <div className="mt-10 grid flex-1 grid-cols-[3fr_2fr] gap-10">
          <div className="relative overflow-hidden rounded-lg bg-white/5">
            <div className="absolute inset-0 grid place-items-center">
              <div className="text-center">
                <div className="text-7xl">🗺️</div>
                <div className="np mt-4 text-2xl font-semibold">
                  जिरी नगरपालिका
                </div>
                <div className="text-sm text-white/50">
                  Wards 1–9 · Koseli Ghar pinned
                </div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            {[
              { label: "किसान", sub: "Farmers", value: "—" },
              { label: "लिस्टिङ", sub: "Active listings", value: "—" },
              { label: "केजी (यो महिना)", sub: "Kg this month", value: "—" },
              { label: "रुपैयाँ (यो महिना)", sub: "NPR this month", value: "—" },
            ].map((c) => (
              <div
                key={c.label}
                className="flex flex-col gap-1 rounded-lg bg-white/5 p-6"
              >
                <div className="np text-sm font-semibold text-white/60">
                  {c.label}
                </div>
                <div className="text-xs text-white/40">{c.sub}</div>
                <div className="mt-3 text-5xl font-extrabold text-white/70">
                  {c.value}
                </div>
              </div>
            ))}
            <div className="col-span-2 rounded-lg bg-amber-500/15 p-5 text-sm">
              <div className="np font-semibold text-amber-200">
                हाम्रो प्रणाली तयार छ — साझेदारी पछि वडा-स्तरीय गणना सुरु हुनेछ।
              </div>
              <div className="mt-1 text-amber-100/70">
                System is ready. Ward-level counts begin once partnership is
                signed.
              </div>
            </div>
          </div>
        </div>
      </div>
    ),
    notes: (
      <p>
        Don&apos;t apologize for zeros — the slide explains them. Belief: B.
        1:30.
      </p>
    ),
  },

  // 11 — The Ask
  {
    id: "ask",
    bg: "bg-background",
    body: (
      <div className="flex h-full flex-col px-20 py-14">
        <div>
          <div className="np-display np text-5xl font-bold text-foreground">
            हाम्रो अनुरोध — तीन कुरा
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            The ask — three things
          </div>
        </div>

        <div className="mt-10 flex flex-1 flex-col">
          {[
            {
              n: "१",
              en: "①",
              h: "एउटा बुँदा कोशेली घरको आह्वानमा",
              d: "Add JiriSewa पिकअप हब सञ्चालन as one bullet on your existing Koseli Ghar proposal call. Open process. Either we win or someone else does — either way you have a digital partner from day one.",
            },
            {
              n: "२",
              en: "②",
              h: "तपाईंकै नारा, हाम्रो उत्पादन सूचीमा",
              d: "Permission to use “अर्गानीक जिरी” — your declaration, your phrase — on JiriSewa-listed Jiri produce. Non-exclusive. Revocable. Quality-conditional.",
            },
            {
              n: "३",
              en: "③",
              h: "यो कागज, अर्को कार्यपालिका बैठकमा",
              d: "Bilingual MoU is signature-ready. Mayor signs after standard executive resolution. We are not asking for money. The MoU explicitly says no money changes hands.",
            },
          ].map((row, i) => (
            <div
              key={row.n}
              className={`grid grid-cols-[80px_1fr] gap-8 py-7 ${
                i > 0 ? "border-t-2 border-border" : ""
              }`}
            >
              <div className="grid h-16 w-16 place-items-center rounded-md bg-secondary font-extrabold text-2xl text-white">
                {row.en}
              </div>
              <div>
                <div className="np text-2xl font-bold text-foreground">
                  {row.h}
                </div>
                <div className="mt-2 text-base leading-relaxed text-gray-600">
                  {row.d}
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-2 rounded-md bg-secondary px-6 py-4 text-center text-white">
          <div className="np text-xl font-bold">
            हामी नगरपालिकासँग पैसा माग्दैनौँ। ठाउँ र नाम मात्र।
          </div>
          <div className="text-sm text-white/80">
            We are not asking the municipality for money. Address and name only.
          </div>
        </div>
      </div>
    ),
    notes: (
      <p>
        If asked about fuel subsidy: pursue logistics support separately when
        the truck route activates. This document is a partnership, not a
        contract. 3:00.
      </p>
    ),
  },

  // 12 — What Jiri gets / Nepal expansion path
  {
    id: "what-jiri-gets",
    bg: "bg-background",
    body: (
      <div className="flex h-full flex-col px-20 py-14">
        <div>
          <div className="np-display np text-5xl font-bold text-foreground">
            पहिले जिरीले, त्यसपछि नेपालले
          </div>
          <div className="mt-2 text-lg font-medium text-gray-500">
            What Jiri gets first, what Nepal gets next
          </div>
        </div>

        <div className="mt-10 grid flex-1 grid-cols-[3fr_2fr] gap-10">
          <div>
            <div className="np text-base font-bold uppercase tracking-wider text-secondary">
              जिरी नगरपालिकालाई
            </div>
            <div className="mt-5 grid grid-cols-1 gap-3">
              {[
                {
                  h: "मासिक तौल रिपोर्ट",
                  d: "Monthly tonnage by crop, ward, farmer cohort. Aligns with your राजस्व सुधार कार्ययोजना.",
                },
                {
                  h: "किसान कल्याण तथ्याङ्क",
                  d: "Active farmers, average revenue per household, and the price farmers actually received versus traditional market rate — the middleman delta, made visible.",
                },
                {
                  h: "“अर्गानीक जिरी” ब्रान्ड",
                  d: "Your declaration travelling to Kathmandu kitchens with your name on it.",
                },
                {
                  h: "वडा डेटा ड्यासबोर्ड",
                  d: "Real-time, not a quarterly PDF. Wards 1–9 separately.",
                },
              ].map((row) => (
                <div
                  key={row.h}
                  className="border-l-4 border-secondary bg-emerald-50/50 px-5 py-4"
                >
                  <div className="np text-lg font-bold text-foreground">
                    {row.h}
                  </div>
                  <div className="text-sm text-gray-600">{row.d}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="flex flex-col">
            <div className="np text-base font-bold uppercase tracking-wider text-primary">
              अनि सम्पूर्ण नेपालले
            </div>
            <div className="mt-5 flex-1 rounded-lg bg-blue-50 p-7">
              <div className="np text-lg font-bold text-foreground">
                विस्तार मार्ग
              </div>
              <div className="text-sm text-gray-500">Expansion path</div>
              <ul className="mt-5 space-y-3 text-base text-foreground">
                <li className="flex items-baseline gap-3">
                  <span className="h-2 w-2 shrink-0 rounded-full bg-primary" />
                  <span className="np font-bold">जिरी</span>
                  <span className="text-gray-500">— pilot</span>
                </li>
                <li className="flex items-baseline gap-3">
                  <span className="h-2 w-2 shrink-0 rounded-full bg-primary/70" />
                  <span className="np">दोलखा / रामेछाप</span>
                  <span className="text-gray-500">— year 1</span>
                </li>
                <li className="flex items-baseline gap-3">
                  <span className="h-2 w-2 shrink-0 rounded-full bg-primary/50" />
                  <span className="np">सोलुखुम्बु / ओखलढुङ्गा</span>
                  <span className="text-gray-500">— year 2</span>
                </li>
                <li className="flex items-baseline gap-3">
                  <span className="h-2 w-2 shrink-0 rounded-full bg-primary/40" />
                  <span className="np">कोशी प्रदेशका पहाडी जिल्लाहरू</span>
                  <span className="text-gray-500">— year 3</span>
                </li>
                <li className="flex items-baseline gap-3">
                  <span className="h-2 w-2 shrink-0 rounded-full bg-primary/25" />
                  <span className="np">सम्पूर्ण नेपाल</span>
                  <span className="text-gray-500">— horizon</span>
                </li>
              </ul>
            </div>
            <div className="np mt-4 text-base font-semibold text-foreground">
              जिरीको नाम यी सबैमा पहिलो लेखिनेछ।
            </div>
            <div className="text-sm text-gray-500">
              Jiri&apos;s name is written first on all of these.
            </div>
          </div>
        </div>
      </div>
    ),
    notes: <p>Belief: B + C. 2:30.</p>,
  },

  // 13 — Closing
  {
    id: "closing",
    bg: "bg-secondary deck-geo",
    body: (
      <div className="relative flex h-full flex-col items-center justify-center px-20 text-center text-white">
        <div className="np text-[5rem] font-extrabold leading-[1.2]">
          अर्गानिक नगर ले
          <br />
          अर्गानिक नेपाललाई
          <br />
          <span className="text-amber-300">बाटो देखाउँछ।</span>
        </div>
        <div className="np mt-12 text-2xl font-medium text-white/85">
          यो यात्रा जिरीबाटै सुरु हुन्छ।
        </div>
        <div className="mt-4 max-w-2xl text-base text-white/70">
          The organic city shows the way to an organic Nepal. The journey
          starts here in Jiri.
        </div>

        <div className="mt-16 flex items-center gap-6 border-t border-white/20 pt-8 text-sm">
          <span className="np font-semibold">अब कागजमा हेरौँ।</span>
          <span className="text-white/50">·</span>
          <span>Now let&apos;s look at the document.</span>
        </div>

        <div className="mt-10 flex items-center gap-3 text-white/70">
          <Sprout className="h-5 w-5" strokeWidth={2.25} />
          <ArrowRight className="h-4 w-4" strokeWidth={2.5} />
          <Truck className="h-5 w-5" strokeWidth={2.25} />
          <ArrowRight className="h-4 w-4" strokeWidth={2.5} />
          <ShoppingBag className="h-5 w-5" strokeWidth={2.25} />
          <span className="ml-3 text-xs font-bold uppercase tracking-[0.3em]">
            JiriSewa
          </span>
        </div>
      </div>
    ),
    notes: (
      <p>
        1:30 then walk to the table. The MoU is on the table from minute zero.
        Q&amp;A folds into the MoU walk-through.
      </p>
    ),
  },
];

export default function DeckPage() {
  return <SlideStage slides={slides} />;
}
