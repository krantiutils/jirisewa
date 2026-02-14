import type { Database } from "@/lib/supabase/types";

export type OrderRow = Database["public"]["Tables"]["orders"]["Row"];
export type OrderItemRow = Database["public"]["Tables"]["order_items"]["Row"];
export type OrderStatus = Database["public"]["Enums"]["order_status"];
export type OrderItemStatus = Database["public"]["Enums"]["order_item_status"];
export type FarmerPayoutRow = Database["public"]["Tables"]["farmer_payouts"]["Row"];

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

/** Items grouped by farmer for multi-farmer order display. */
export interface FarmerItemGroup {
  farmerId: string;
  farmerName: string;
  farmerAvatar: string | null;
  pickupSequence: number;
  pickupStatus: OrderItemStatus;
  pickupConfirmedAt: string | null;
  items: OrderItemWithDetails[];
  subtotal: number;
  totalKg: number;
}

export interface OrderWithDetails extends OrderRow {
  items: OrderItemWithDetails[];
  subOrders?: OrderWithDetails[];
  farmerPayouts?: FarmerPayoutRow[];
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
  paymentMethod: "cash" | "esewa";
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

export interface EsewaPaymentFormData {
  orderId: string;
  url: string;
  fields: Record<string, string>;
}


export interface DeliveryFeeEstimate {
  baseFee: number;
  distanceFee: number;
  weightFee: number;
  totalFee: number;
  distanceKm: number;
  weightKg: number;
}

/** Result of the trip matching algorithm. */
export interface TripMatchResult {
  tripId: string;
  riderId: string;
  riderName: string;
  riderRating: number;
  departureAt: string;
  originName: string;
  destinationName: string;
  remainingCapacityKg: number;
  /** Which farmer pickup locations are covered by this trip. */
  coveredFarmerIds: string[];
  /** Whether this trip covers ALL pickup locations. */
  coversAllPickups: boolean;
}
