<script setup lang="ts">
import { onMounted, ref } from 'vue'

// Slide §10: live counters of Jiri ward activity on JiriSewa, with
// graceful fallback to a pre-cached snapshot when network is down or
// prod has no Jiri data yet.
//
// On Day 1 (almost certainly), all four counters will be zero. The
// component renders zero values with the partnership-pending caption
// instead of looking broken.

interface Counter {
  key: 'farmers' | 'listings' | 'kg' | 'npr'
  labelNe: string
  labelEn: string
  unitNe?: string
  unitEn?: string
  value: number | null
}

const counters = ref<Counter[]>([
  { key: 'farmers', labelNe: 'दर्ता भएका जिरी किसान', labelEn: 'Registered Jiri farmers', value: null },
  { key: 'listings', labelNe: 'सक्रिय लिस्टिङ', labelEn: 'Active Jiri-ward listings', value: null },
  { key: 'kg', labelNe: 'यस महिना कोशेली घरमा प्राप्त', labelEn: 'Kg dropped this month', unitNe: 'किलो', unitEn: 'kg', value: null },
  { key: 'npr', labelNe: 'यस महिना जिरी किसानले कमाएको', labelEn: 'NPR earned by Jiri farmers this month', unitNe: 'रुपैयाँ', unitEn: 'NPR', value: null },
])

const sourceMode = ref<'live' | 'cache' | 'loading'>('loading')
const cacheStamp = ref<string | null>(null)

const SUPABASE_URL = (import.meta as any).env?.VITE_SUPABASE_URL ?? 'https://khetbata.xyz/_supabase'
const SUPABASE_ANON = (import.meta as any).env?.VITE_SUPABASE_ANON_KEY ?? ''

async function fetchLive(): Promise<Partial<Record<Counter['key'], number>> | null> {
  if (!SUPABASE_ANON) return null
  // Read-only views queryable by anon. Falls back to null on any failure.
  try {
    const headers = { apikey: SUPABASE_ANON, Authorization: `Bearer ${SUPABASE_ANON}` }
    const ctrl = new AbortController()
    const t = setTimeout(() => ctrl.abort(), 5000)
    const url = `${SUPABASE_URL}/rest/v1/rpc/jiri_ward_counters_v1`
    const res = await fetch(url, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: '{}',
      signal: ctrl.signal,
    })
    clearTimeout(t)
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}

async function fetchCache() {
  try {
    const res = await fetch('/cache/jiri-counters.json')
    if (!res.ok) return null
    const json = await res.json()
    cacheStamp.value = json.stamp ?? null
    return json.counters as Record<Counter['key'], number>
  } catch {
    return null
  }
}

onMounted(async () => {
  const live = await fetchLive()
  if (live) {
    sourceMode.value = 'live'
    counters.value = counters.value.map((c) => ({
      ...c,
      value: live[c.key] ?? 0,
    }))
    return
  }
  const cached = await fetchCache()
  if (cached) {
    sourceMode.value = 'cache'
    counters.value = counters.value.map((c) => ({ ...c, value: cached[c.key] ?? 0 }))
    return
  }
  // No live, no cache — show zeros with pending caption.
  sourceMode.value = 'cache'
  counters.value = counters.value.map((c) => ({ ...c, value: 0 }))
})

function fmt(c: Counter): string {
  if (c.value == null) return '…'
  if (c.value === 0) return '—'
  if (c.key === 'npr') return `रु. ${c.value.toLocaleString('ne-NP')}`
  if (c.key === 'kg') return `${c.value.toLocaleString('ne-NP')} किलो`
  return c.value.toLocaleString('ne-NP')
}
</script>

<template>
  <div class="counters-grid">
    <div
      v-for="c in counters"
      :key="c.key"
      class="counter-card"
    >
      <div class="label np">{{ c.labelNe }}</div>
      <div class="value" :class="{ zero: c.value === 0 }">{{ fmt(c) }}</div>
      <div class="sub">{{ c.labelEn }}</div>
    </div>
  </div>

  <div v-if="counters.every(c => c.value === 0)" class="pending-caption">
    <div class="np">हाम्रो प्रणाली तयार छ। बाँकी छ — तपाईंको स्वीकृति।</div>
    <div class="en-sub">Our system is ready. What's left — your blessing.</div>
  </div>

  <div class="source-stamp">
    <span v-if="sourceMode === 'live'" class="live-badge">live</span>
    <span v-else-if="sourceMode === 'cache' && cacheStamp">cached {{ cacheStamp }}</span>
    <span v-else>loading…</span>
  </div>
</template>

<style scoped>
.counters-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  margin-top: 12px;
}
.pending-caption {
  margin-top: 24px;
  padding: 16px 20px;
  background: rgba(22, 163, 74, 0.08);
  border-left: 3px solid var(--jirisewa-green);
  border-radius: 0 8px 8px 0;
}
.pending-caption .np {
  font-weight: 600;
  font-size: 1.1em;
  color: var(--jirisewa-ink);
}
.source-stamp {
  margin-top: 12px;
  font-size: 0.7em;
  color: var(--jirisewa-ink-soft);
  text-align: right;
}
</style>
