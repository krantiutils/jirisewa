# Flow Test Matrix — Jiri Demo (2026-04-30)

Companion to `2026-04-30-presentation-plan.md`. Every row is a flow
that must pass against **prod** before the meeting. Each row maps to
a specific slide in the deck (or to demo prep). If a row's "Status"
isn't ✅ by the morning of the meeting, the deck falls back to the
captured screenshot for that flow and the presenter narrates around
it (no silent failure).

**Conventions:**
- **Surface:** `web` (Next.js apps/web), `android` (Flutter mobile),
  `web+android` (must work on both), `db` (Supabase only — no UI)
- **Locale:** `ne` for Nepali UI, `en` for English, `both` if must
  toggle correctly
- **Capture:** filename slug saved at `docs/demo/deck/public/captures/<slug>/`
- **Status legend:** 🔴 not run | 🟡 partial / blockers | ✅ passing on prod

Run the whole matrix via:

```bash
cd apps/web
npx tsx scripts/run-flow-matrix.ts --target=prod
```

Output dumps screenshots to the deck's `public/captures/`.

---

## 1. Pre-flight (run once, the day before)

These are NOT user flows — they are infrastructure prerequisites. If
any of them is 🔴, every demo flow underneath fails too.

| # | Pre-flight | Surface | Pass criterion | Status |
|---|------------|---------|----------------|--------|
| 1.1 | Hub migrations applied to **prod** Supabase | db | `pickup_hubs`, `hub_dropoffs` tables exist, `app_role` enum includes `hub_operator`, RPCs `record_hub_dropoff_v1` etc. respond | 🔴 |
| 1.2 | Jiri Bazaar Hub seeded on prod at (27.6275, 86.2202) | db | Row exists in `pickup_hubs`, `hub_type='origin'`, `is_active=true`, `municipality_id` set to Jiri | 🔴 |
| 1.3 | Demo consumer account on prod | db | `demo-consumer-ktm@khetbata.xyz` with onboarding completed, role=consumer | 🔴 |
| 1.4 | Demo farmer account on prod (display name `नमुना जिरेल`) | db | `demo-farmer-jiri@khetbata.xyz` with role=farmer + onboarding completed | 🔴 |
| 1.5 | Demo hub-operator account on prod | db | `demo-operator-jiri@khetbata.xyz` with role=hub_operator + assigned to Jiri Bazaar Hub | 🔴 |
| 1.6 | Three Jiri-marquee listings on prod (kiwi, akbare, churpi) | db | Owned by demo farmer account, `is_active=true`, `pickup_mode='both'` | 🔴 |
| 1.7 | Mobile APK on phone signed in as rider | android | Phone shows rider home with live trip card; Tailscale not interfering | 🔴 |
| 1.8 | Two Chrome profiles on laptop pre-loaded | web | Profile 1 = consumer signed in; Profile 2 = farmer signed in; Profile 3 = operator signed in | 🔴 |
| 1.9 | Slidev deck exports cleanly | web | `pnpm export-pdf` produces `deck.pdf` with all 13 slides, no rendering errors | 🔴 |
| 1.10 | Failure-script cache populated | web | `public/cache.json` has Jiri counter values stamped 2026-04-29 | 🔴 |

**Blocker rule:** if 1.1 or 1.2 or 1.3 or 1.4 or 1.5 is 🔴 by 18:00
the day before, the demo segments (slides 4, 5, 8, 9) revert to
screenshots and the presenter scripts the narration. Get the user's
go-ahead to apply prod migrations early in the day.

---

## 2. Demo flows — every row maps to a deck slide

| # | Flow | Slide | Surface · Locale | Pass criterion | Capture | Status |
|---|------|-------|------------------|----------------|---------|--------|
| 2.1 | Consumer browses marketplace, filters for "जिरी" / kiwi | §4 | web · ne | Marketplace page loads; filter narrows results; first listing card shows farmer name + ward + price | `04-consumer/01-marketplace.png` | 🔴 |
| 2.2 | Consumer opens kiwi listing detail | §4 | web · ne | Detail page renders with photos, freshness date, farmer profile link, "थप्नुहोस् कार्टमा" button | `04-consumer/02-detail.png` | 🔴 |
| 2.3 | Consumer adds to cart and reaches checkout | §4 | web · ne | Cart shows item; checkout step shows delivery-fee estimate and total in NPR | `04-consumer/03-cart.png` + `04-consumer/04-checkout.png` | 🔴 |
| 2.4 | Consumer places **cash** order end-to-end | §4 | web · ne | `place_order_v1` returns order_id; consumer sees confirmation; rider matched (visible in admin) | `04-consumer/05-order-confirmation.png` | 🔴 |
| 2.5 | Farmer signs in and sees dashboard with real numbers | §5 | web · both | Dashboard renders without errors; pending order count + earnings reflect 2.4 | `05-farmer/01-dashboard.png` | 🔴 |
| 2.6 | Farmer toggles UI between EN/NE | §5 | web · both | Toggle works; Devanagari renders crisply (Mukta loads); no fallback fonts visible | `05-farmer/02-bilingual.png` | 🔴 |
| 2.7 | Rider home shows live trip card on phone | §6 | android · ne | Rider sees scheduled Jiri↔Kathmandu trip with available capacity; available-orders surface lists pings | `06-rider/01-home.png` | 🔴 |
| 2.8 | Farmer opens "drop off at hub" screen | §8 | web · ne | Form renders with Jiri Bazaar Hub pre-selected; farmer's listings visible in dropdown | `08-dropoff/01-form.png` | 🔴 |
| 2.9 | Farmer submits 5 kg drop-off, gets lot code | §8 | web · ne | `record_hub_dropoff_v1` returns within 3s; success card shows lot code (e.g. `NYGJ38`); listing flips to `pickup_mode='both'` | `08-dropoff/02-success.png` | 🔴 |
| 2.10 | Operator inventory shows new dropoff in "Awaiting" tab | §9 | web · ne | Operator dashboard shows the §2.9 dropoff with status `dropped_off`, lot code matches | `09-operator/01-awaiting.png` | 🔴 |
| 2.11 | Operator clicks "Mark received" — status flips, notif fires | §9 | web · ne | Status moves to `in_inventory`; farmer notification with category `hub_dropoff_received` lands in `notifications` table | `09-operator/02-received.png` + `09-operator/03-notif.png` | 🔴 |
| 2.12 | Live ward counters render (or fall back gracefully) | §10 | web · both | Slidev component fetches Supabase counters within 5s; if zero, shows "—" with "हाम्रो प्रणाली तयार छ" caption; if network fails, reads `cache.json` | `10-counters/01-live.png` + `10-counters/02-fallback.png` | 🔴 |

---

## 3. Bilingual + i18n smoke (must hold across the deck)

| # | Surface | Test | Pass criterion | Status |
|---|---------|------|----------------|--------|
| 3.1 | web | Marketplace at `/ne/marketplace` | Devanagari renders for nav, headings, product names, and farmer name | 🔴 |
| 3.2 | web | Farmer dashboard at `/ne/farmer/dashboard` | All buttons + cards in Nepali; no `[object Object]` or English fallbacks | 🔴 |
| 3.3 | web | Hub dropoff form at `/ne/farmer/hubs` | Form labels in Nepali; success banner Devanagari | 🔴 |
| 3.4 | web | Hub operator at `/ne/hub` | Status filter chips in Nepali ("स्वीकृति बाँकी", "इन्भेन्टरी", etc.) | 🔴 |
| 3.5 | android | Rider home + profile in Nepali | Native Flutter strings render | 🔴 |
| 3.6 | android | Marketplace tab in Nepali on phone | Same listings as web, Devanagari intact | 🔴 |

If any 3.x is 🔴, the bilingual claim in §3 of the deck is shaky.
Worst-case fallback: present primarily in English, narrate the
Nepali version, demo the toggle but don't dwell.

---

## 4. Failure-script verification

These are the *fallbacks* — must work even more reliably than the
happy paths because they're the safety net.

| # | Failure | Detection | Verify in advance |
|---|---------|-----------|-------------------|
| 4.1 | Network drops during live demo | Demo page won't load | Switch laptop to airplane mode for 10s; verify deck still navigates; verify each demo slide has a static screenshot in `public/captures/` |
| 4.2 | Supabase prod down | Counter component throws | Add a network throttle of 100% packet loss in DevTools; verify counters fall back to `cache.json` values, not error UI |
| 4.3 | Leaflet tile server fails | Map shows grey | Block `*.openstreetmap.org` in the laptop hosts file; verify static map image renders; confirm pinned coords are still labeled correctly |
| 4.4 | Browser tab dies mid-demo | Tab won't reload | Use Chrome's "Reload" forced kill; verify second profile in the second window has the same view ready (bookmark to `/ne/farmer/dashboard` already loaded) |
| 4.5 | "Why isn't there money?" Q&A objection | Spoken question | Memorize the prepared one-liner: *"पैसा भएमा सभाको स्वीकृति चाहिन्छ। यो कागज साझेदारी हो — मेयर एक्लै हस्ताक्षर गर्न सक्नुहुन्छ।"* |
| 4.6 | "We need to discuss with Karyapalika first" | Spoken | This is a YES, not a NO. Acknowledge and offer to attend the Karyapalika session. The MoU on the table makes this a guided next step, not a deferral |

---

## 5. Capture script — `apps/web/scripts/run-flow-matrix.ts`

Drives every `2.x` web row via Playwright; every `2.7` and `3.5/3.6`
android row via adb. Reuses the existing `capture-demo-shots.ts`
auth flow (drives the email login UI to set httpOnly cookies).

**Targets:**
- `--target=local` → `http://localhost:3000` against local Supabase
- `--target=prod` → `https://khetbata.xyz` against prod Supabase

**Outputs:**
- `docs/demo/deck/public/captures/<slug>/<NN>-<step>.png`
- `docs/demo/deck/public/cache.json` (counters snapshot, dated)
- `docs/demo/2026-04-30-flow-test-matrix.run.json` (status per row,
  re-readable by the deck for the §10 fallback line)

**Re-runnable:** safe to call before every dry-run. The script
deletes only its own output directory, doesn't touch DB.

---

## 6. The day-of order of operations

This is the runbook for the morning of 2026-04-30. Read top to bottom.

1. **08:00** — Boot laptop + phone. Charge to 100%.
2. **08:15** — Run `npx tsx scripts/run-flow-matrix.ts --target=prod`.
   All 2.x and 3.x rows must come back ✅. Any 🔴 → fix or fall back.
3. **08:30** — Open Slidev deck locally; click through every slide;
   check live counters render (live or cache.json fallback).
4. **08:45** — Open three Chrome profiles, sign each in to its
   designated account, leave tabs at the slide-4/5/9 starting URLs.
5. **09:00** — Print the leave-behind packet (×3): MoU draft,
   one-pager, ask + what-you-get pages from the deck, lot-code
   label sample.
6. **09:30** — Final bag check: laptop, phone, USB stick with PDF,
   printed packet ×3, lot-code label, three pens, one folder, water.
7. **Travel.**
8. **At venue, 30 min before meeting:** connect phone hotspot, NOT
   venue Wi-Fi. Verify ports 80/443 reach Supabase prod. Open deck.
   Place printed MoU on the table from minute zero.

---

## 7. Open questions (unresolved at time of writing)

- **7.1** — Apply hub schema migrations to prod when?
  Plan default: tonight (2026-04-29) after user sign-off.
- **7.2** — Demo farmer display name. Plan default: `नमुना जिरेल`
  with footer disclosure that this is a seeded sample, real
  onboarding pending the partnership.
- **7.3** — Is there time for a dry-run with a Nepali-fluent
  reviewer before the meeting? Plan default: no, but desirable.
- **7.4** — Backup phone for hotspot redundancy. Plan default:
  none, single point of failure accepted.
