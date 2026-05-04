<script setup lang="ts">
import { onMounted, ref } from 'vue'

interface Props {
  height?: string
  zoom?: number
}
const props = withDefaults(defineProps<Props>(), {
  height: '420px',
  zoom: 12,
})

const mapEl = ref<HTMLElement | null>(null)
const tilesFailed = ref(false)
const fallbackSrc = '/cache/jiri-map-static.png'
const fallbackImgFailed = ref(false)

// Jiri Bazaar (city centre) — 27.6275, 86.2202 from jirimun.gov.np
const JIRI_CENTER: [number, number] = [27.6275, 86.2202]

// Tourist places lifted from the gemma-god corpus
const PINS = [
  { name: 'जिरी बजार / Jiri Bazaar', coords: [27.6275, 86.2202], primary: true },
  { name: 'जटा पोखरी / Jata Pokhari', coords: [27.725752, 86.418588] },
  { name: 'पाँच पोखरी / Panch Pokhari', coords: [27.731350, 86.421729] },
  { name: 'बुद्ध पार्क / Buddha Park', coords: [27.638216, 86.218009] },
  { name: 'स्टोन पार्क / Stone Park', coords: [27.6450000, 86.3080556] },
  { name: 'जीरेश्वोरी / Jireshwori', coords: [27.626578, 86.237320] },
] as const

onMounted(async () => {
  if (!mapEl.value) return
  try {
    // @ts-expect-error — Leaflet ESM
    const L = await import('leaflet')
    await import('leaflet/dist/leaflet.css')

    const map = L.map(mapEl.value, {
      center: JIRI_CENTER,
      zoom: props.zoom,
      zoomControl: false,
      attributionControl: false,
      scrollWheelZoom: false,
    })

    const tiles = L.tileLayer(
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      {
        maxZoom: 18,
        attribution: '© OpenStreetMap',
      },
    )
    tiles.on('tileerror', () => { tilesFailed.value = true })
    tiles.addTo(map)

    PINS.forEach((p) => {
      const marker = L.circleMarker(p.coords, {
        radius: p.primary ? 12 : 6,
        color: p.primary ? '#16A34A' : '#2563EB',
        fillColor: p.primary ? '#16A34A' : '#2563EB',
        fillOpacity: p.primary ? 0.85 : 0.5,
        weight: 2,
      }).addTo(map)
      marker.bindTooltip(p.name, {
        permanent: p.primary,
        direction: p.primary ? 'right' : 'top',
        className: 'jiri-pin-label',
        offset: [10, 0],
      })
    })
  } catch (e) {
    tilesFailed.value = true
  }
})
</script>

<template>
  <div class="jiri-map-wrapper" :style="{ height }">
    <div v-if="tilesFailed" class="map-fallback">
      <div class="np">नेटवर्क समस्या — स्थैतिक नक्शा देखाइँदै</div>
      <div class="en-sub">Network issue — showing static map fallback</div>
      <img v-if="!fallbackImgFailed" :src="fallbackSrc" alt="Static Jiri map fallback" @error="fallbackImgFailed = true" />
      <div v-else class="np" style="margin-top: 12px; font-size: 0.9em; opacity: 0.7">जिरी बजार · २७.६२७५° N, ८६.२२०२° E</div>
    </div>
    <div v-else ref="mapEl" class="leaflet-host"></div>
  </div>
</template>

<style scoped>
.jiri-map-wrapper {
  position: relative;
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid var(--jirisewa-divider);
}
.leaflet-host {
  width: 100%;
  height: 100%;
}
.map-fallback {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  background: #f1f5f9;
  text-align: center;
  padding: 24px;
}
.map-fallback img {
  max-width: 100%;
  margin-top: 12px;
  border-radius: 8px;
}
:global(.jiri-pin-label) {
  font-family: 'Mukta', sans-serif !important;
  font-weight: 600 !important;
  font-size: 13px !important;
  background: rgba(255,255,255,0.95) !important;
  border: none !important;
  box-shadow: 0 1px 3px rgba(0,0,0,0.12);
}
</style>
