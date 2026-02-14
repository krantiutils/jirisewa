import type { Database } from "@/lib/supabase/types";

export type OrderRow = Database["public"]["Tables"]["orders"]["Row"];
export type OrderItemRow = Database["public"]["Tables"]["order_items"]["Row"];
export type OrderStatus = Database["public"]["Enums"]["order_status"];

export interface OrderItemWithDetails extends OrderItemRow {
  listing: {
    name_en: string;
    name_ne: string;
    photos: string[];
  };
  farmer: {
    id: string;
    name: string;
    avatar_url: string | null;
  };
}

export interface OrderWithDetails extends OrderRow {
  items: OrderItemWithDetails[];
  rider?: {
    id: string;
    name: string;
    avatar_url: string | null;
    phone: string;
    rating_avg: number;
  } | null;
  trip?: {
    id: string;
    origin_name: string;
    destination_name: string;
    departure_at: string;
  } | null;
}

export interface PlaceOrderInput {
  deliveryAddress: string;
  deliveryLat: number;
  deliveryLng: number;
  deliveryFee: number;
  deliveryFeeBase: number;
  deliveryFeeDistance: number;
  deliveryFeeWeight: number;
  deliveryDistanceKm: number | null;
  items: {
    listingId: string;
    farmerId: string;
    quantityKg: number;
    pricePerKg: number;
  }[];
}

export interface DeliveryFeeEstimate {
  baseFee: number;
  distanceFee: number;
  weightFee: number;
  totalFee: number;
  distanceKm: number;
  weightKg: number;
}
