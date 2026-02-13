"use client";

import { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import {
  MAP_TILE_URL,
  MAP_ATTRIBUTION,
  MAP_DEFAULT_CENTER,
  MAP_DEFAULT_ZOOM,
  NEPAL_BOUNDS,
} from "@jirisewa/shared";

const listingIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

export interface ProduceListing {
  id: string;
  name: string;
  pricePerKg: number;
  farmerName: string;
  lat: number;
  lng: number;
}

interface ProduceMapProps {
  listings: ProduceListing[];
  center?: { lat: number; lng: number };
  zoom?: number;
  className?: string;
  onMarkerClick?: (listingId: string) => void;
}

export default function ProduceMap({
  listings,
  center,
  zoom,
  className,
  onMarkerClick,
}: ProduceMapProps) {
  const mapCenter = center ?? MAP_DEFAULT_CENTER;
  const mapZoom = zoom ?? MAP_DEFAULT_ZOOM;

  const bounds = useMemo(
    () =>
      L.latLngBounds(
        [NEPAL_BOUNDS.southWest.lat, NEPAL_BOUNDS.southWest.lng],
        [NEPAL_BOUNDS.northEast.lat, NEPAL_BOUNDS.northEast.lng],
      ),
    [],
  );

  return (
    <div className={className}>
      <MapContainer
        center={[mapCenter.lat, mapCenter.lng]}
        zoom={mapZoom}
        maxBounds={bounds}
        maxBoundsViscosity={1.0}
        minZoom={7}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={MAP_TILE_URL} attribution={MAP_ATTRIBUTION} />
        {listings.map((listing) => (
          <Marker
            key={listing.id}
            position={[listing.lat, listing.lng]}
            icon={listingIcon}
            eventHandlers={
              onMarkerClick
                ? {
                    click: () => onMarkerClick(listing.id),
                  }
                : undefined
            }
          >
            <Popup>
              <div className="font-sans">
                <p className="font-semibold text-sm">{listing.name}</p>
                <p className="text-xs text-gray-600">
                  NPR {listing.pricePerKg}/kg
                </p>
                <p className="text-xs text-gray-500">{listing.farmerName}</p>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
