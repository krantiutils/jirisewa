import L from "leaflet";

/** Default Leaflet marker icon — fixes bundler path resolution issues */
export const defaultMarkerIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

/** Rider location marker — blue circle with white motorcycle SVG */
export const riderMarkerIcon = L.divIcon({
  className: "",
  html: `<div style="
    width:36px;height:36px;border-radius:50%;
    background:#3B82F6;border:3px solid #fff;
    box-shadow:0 2px 6px rgba(0,0,0,0.3);
    display:flex;align-items:center;justify-content:center;
  "><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18.5" cy="17.5" r="3.5"/><circle cx="5.5" cy="17.5" r="3.5"/><circle cx="15" cy="5" r="1"/><path d="M12 17.5V14l-3-3 4-3 2 3h2"/></svg></div>`,
  iconSize: [36, 36],
  iconAnchor: [18, 18],
  popupAnchor: [0, -20],
});

/** Pickup marker — green icon */
export const pickupMarkerIcon = L.divIcon({
  className: "",
  html: `<div style="
    width:32px;height:32px;border-radius:50%;
    background:#10B981;border:3px solid #fff;
    box-shadow:0 2px 4px rgba(0,0,0,0.25);
    display:flex;align-items:center;justify-content:center;
  "><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></div>`,
  iconSize: [32, 32],
  iconAnchor: [16, 16],
  popupAnchor: [0, -18],
});

/** Delivery destination marker — red pin */
export const deliveryMarkerIcon = L.divIcon({
  className: "",
  html: `<div style="
    width:32px;height:32px;border-radius:50% 50% 50% 0;
    background:#EF4444;border:3px solid #fff;
    box-shadow:0 2px 4px rgba(0,0,0,0.25);
    transform:rotate(-45deg);
    display:flex;align-items:center;justify-content:center;
  "><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="#fff" stroke="none" style="transform:rotate(45deg)"><circle cx="12" cy="12" r="6"/></svg></div>`,
  iconSize: [32, 32],
  iconAnchor: [16, 32],
  popupAnchor: [0, -34],
});
