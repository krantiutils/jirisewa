# JiriSewa — Jiri Demo Deck

Slidev project for the 2026-04-30 presentation to Jiri Nagarpalika
officials. Source of truth: `slides.md`. Companion docs:

- Plan: `../2026-04-30-presentation-plan.md`
- Flow matrix: `../2026-04-30-flow-test-matrix.md`
- Grounding facts: `../jiri-grounding-facts.md`
- Leave-behind: `../leave-behind/{mou-draft.md, organic-jiri-mark.md}`

## Run

```bash
pnpm install
pnpm dev            # http://localhost:3030
pnpm export-pdf     # → deck.pdf
pnpm export-png     # → public/slides/slide-XX.png
pnpm export-html    # → dist/  (host at /jiri-presentation)
```

## What's where

| File | Purpose |
|------|---------|
| `slides.md` | All 13 slides, bilingual, with `<!-- presenter notes -->` per slide |
| `style/global.css` | Inter + Mukta type stack, three-colour palette |
| `components/JiriHubMap.vue` | Live Leaflet map of Jiri, with static fallback for dead network |
| `components/LiveWardCounters.vue` | Live Supabase counters with `cache.json` fallback |
| `public/captures/` | Screenshots from `apps/web/scripts/run-flow-matrix.ts` |
| `public/cache/jiri-counters.json` | Day-1 fallback values (all zeros + the partnership-pending caption) |

## Live data flow

`LiveWardCounters.vue` tries, in order:

1. Live `POST /rest/v1/rpc/jiri_ward_counters_v1` against
   `VITE_SUPABASE_URL` (defaults to prod) with anon key. Times out
   at 5s.
2. `/cache/jiri-counters.json` (date-stamped fallback).
3. Zeros + partnership-pending caption.

The RPC `jiri_ward_counters_v1` does NOT yet exist on prod — it's a
TODO before demo day. Spec is in this README under "Counter RPC".

## Counter RPC (TODO before demo)

```sql
CREATE OR REPLACE FUNCTION public.jiri_ward_counters_v1()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'farmers',  (SELECT count(*) FROM users u
                  JOIN user_roles ur ON ur.user_id = u.id
                  WHERE ur.role = 'farmer'
                    AND u.municipality ILIKE '%jiri%'),
    'listings', (SELECT count(*) FROM produce_listings pl
                  JOIN users u ON u.id = pl.farmer_id
                  WHERE pl.is_active
                    AND u.municipality ILIKE '%jiri%'),
    'kg',       (SELECT coalesce(sum(quantity_kg), 0)::int
                  FROM hub_dropoffs d
                  JOIN pickup_hubs h ON h.id = d.hub_id
                  WHERE h.municipality_id IS NOT NULL
                    AND d.dropped_at >= date_trunc('month', now())),
    'npr',      (SELECT coalesce(sum(oi.subtotal), 0)::int
                  FROM order_items oi
                  JOIN users u ON u.id = oi.farmer_id
                  WHERE u.municipality ILIKE '%jiri%'
                    AND oi.created_at >= date_trunc('month', now()))
  );
$$;

GRANT EXECUTE ON FUNCTION public.jiri_ward_counters_v1() TO anon, authenticated;
```

This is added by the prod-prep migration (see
`../scripts/prep-prod-for-demo.sh` once built).

## Failure-script verification

Before the meeting, verify each fallback:

1. **Hotspot off:** open Slidev preview, click through deck. Every
   slide must render. Live data slide should show cached zeros.
2. **OSM tiles blocked** (hosts file or DevTools): map slide must
   render the static `/cache/jiri-map-static.png` fallback.
3. **Wrong Supabase URL:** counters must show "loading…" → "—"
   gracefully, not a JS error.

## Notes on tone

- Devanagari display headlines use Mukta 700; body Mukta 600.
- Latin uses Inter; English-as-subtitle is rendered at 60% opacity.
- The deck never mixes scripts inside a single line of equal
  weight — Devanagari headline on top, English sub-line below.
- Numbers use Devanagari numerals where the surrounding text is
  Devanagari.
