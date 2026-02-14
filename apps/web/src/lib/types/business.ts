export interface BusinessProfile {
  id: string;
  user_id: string;
  business_name: string;
  business_type: "restaurant" | "hotel" | "canteen" | "other";
  registration_number: string | null;
  address: string;
  phone: string | null;
  contact_person: string | null;
  verified_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface BulkOrder {
  id: string;
  business_id: string;
  status: string;
  delivery_address: string;
  delivery_location: string | null;
  delivery_frequency: "once" | "weekly" | "biweekly" | "monthly";
  delivery_schedule: Record<string, string> | null;
  total_amount: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface BulkOrderItem {
  id: string;
  bulk_order_id: string;
  produce_listing_id: string;
  farmer_id: string;
  quantity_kg: number;
  price_per_kg: number;
  quoted_price_per_kg: number | null;
  status: string;
  farmer_notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface BulkOrderItemWithDetails extends BulkOrderItem {
  listing: {
    name_en: string;
    name_ne: string;
    photos: string[];
  } | null;
  farmer: {
    id: string;
    name: string;
    avatar_url: string | null;
  } | null;
}

export interface BulkOrderWithDetails extends BulkOrder {
  items: BulkOrderItemWithDetails[];
  business?: BusinessProfile;
}

export interface CreateBusinessProfileInput {
  business_name: string;
  business_type: "restaurant" | "hotel" | "canteen" | "other";
  registration_number?: string;
  address: string;
  phone?: string;
  contact_person?: string;
}

export interface CreateBulkOrderInput {
  delivery_address: string;
  delivery_lat?: number;
  delivery_lng?: number;
  delivery_frequency: "once" | "weekly" | "biweekly" | "monthly";
  delivery_schedule?: Record<string, string>;
  notes?: string;
  items: {
    listingId: string;
    farmerId: string;
    quantityKg: number;
    pricePerKg: number;
  }[];
}
