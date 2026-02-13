export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      users: {
        Row: {
          id: string;
          phone: string;
          name: string;
          role: "farmer" | "consumer" | "rider";
          avatar_url: string | null;
          location: unknown | null;
          address: string | null;
          municipality: string | null;
          lang: "en" | "ne";
          rating_avg: number;
          rating_count: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          phone: string;
          name: string;
          role: "farmer" | "consumer" | "rider";
          avatar_url?: string | null;
          location?: unknown | null;
          address?: string | null;
          municipality?: string | null;
          lang?: "en" | "ne";
          rating_avg?: number;
          rating_count?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          phone?: string;
          name?: string;
          role?: "farmer" | "consumer" | "rider";
          avatar_url?: string | null;
          location?: unknown | null;
          address?: string | null;
          municipality?: string | null;
          lang?: "en" | "ne";
          rating_avg?: number;
          rating_count?: number;
          created_at?: string;
          updated_at?: string;
        };
      };
      user_roles: {
        Row: {
          id: string;
          user_id: string;
          role: "farmer" | "consumer" | "rider";
          farm_name: string | null;
          vehicle_type: "bike" | "car" | "truck" | "bus" | "other" | null;
          vehicle_capacity_kg: number | null;
          license_photo_url: string | null;
          verified: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          role: "farmer" | "consumer" | "rider";
          farm_name?: string | null;
          vehicle_type?: "bike" | "car" | "truck" | "bus" | "other" | null;
          vehicle_capacity_kg?: number | null;
          license_photo_url?: string | null;
          verified?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          role?: "farmer" | "consumer" | "rider";
          farm_name?: string | null;
          vehicle_type?: "bike" | "car" | "truck" | "bus" | "other" | null;
          vehicle_capacity_kg?: number | null;
          license_photo_url?: string | null;
          verified?: boolean;
          created_at?: string;
        };
      };
      produce_categories: {
        Row: {
          id: string;
          name_en: string;
          name_ne: string;
          icon: string | null;
          sort_order: number;
        };
        Insert: {
          id?: string;
          name_en: string;
          name_ne: string;
          icon?: string | null;
          sort_order?: number;
        };
        Update: {
          id?: string;
          name_en?: string;
          name_ne?: string;
          icon?: string | null;
          sort_order?: number;
        };
      };
      produce_listings: {
        Row: {
          id: string;
          farmer_id: string;
          category_id: string;
          name_en: string;
          name_ne: string;
          description: string | null;
          price_per_kg: number;
          available_qty_kg: number;
          freshness_date: string | null;
          location: unknown | null;
          photos: string[];
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          farmer_id: string;
          category_id: string;
          name_en: string;
          name_ne: string;
          description?: string | null;
          price_per_kg: number;
          available_qty_kg: number;
          freshness_date?: string | null;
          location?: unknown | null;
          photos?: string[];
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          farmer_id?: string;
          category_id?: string;
          name_en?: string;
          name_ne?: string;
          description?: string | null;
          price_per_kg?: number;
          available_qty_kg?: number;
          freshness_date?: string | null;
          location?: unknown | null;
          photos?: string[];
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
      };
      orders: {
        Row: {
          id: string;
          consumer_id: string;
          rider_trip_id: string | null;
          rider_id: string | null;
          status:
            | "pending"
            | "matched"
            | "picked_up"
            | "in_transit"
            | "delivered"
            | "cancelled"
            | "disputed";
          delivery_address: string;
          delivery_location: unknown;
          total_price: number;
          delivery_fee: number;
          payment_method: "cash" | "esewa" | "khalti";
          payment_status: "pending" | "collected" | "settled";
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          consumer_id: string;
          rider_trip_id?: string | null;
          rider_id?: string | null;
          status?:
            | "pending"
            | "matched"
            | "picked_up"
            | "in_transit"
            | "delivered"
            | "cancelled"
            | "disputed";
          delivery_address: string;
          delivery_location: unknown;
          total_price: number;
          delivery_fee?: number;
          payment_method?: "cash" | "esewa" | "khalti";
          payment_status?: "pending" | "collected" | "settled";
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          consumer_id?: string;
          rider_trip_id?: string | null;
          rider_id?: string | null;
          status?:
            | "pending"
            | "matched"
            | "picked_up"
            | "in_transit"
            | "delivered"
            | "cancelled"
            | "disputed";
          delivery_address?: string;
          delivery_location?: unknown;
          total_price?: number;
          delivery_fee?: number;
          payment_method?: "cash" | "esewa" | "khalti";
          payment_status?: "pending" | "collected" | "settled";
          created_at?: string;
          updated_at?: string;
        };
      };
      order_items: {
        Row: {
          id: string;
          order_id: string;
          listing_id: string;
          farmer_id: string;
          quantity_kg: number;
          price_per_kg: number;
          subtotal: number;
          pickup_location: unknown | null;
          pickup_confirmed: boolean;
          pickup_photo_url: string | null;
          delivery_confirmed: boolean;
        };
        Insert: {
          id?: string;
          order_id: string;
          listing_id: string;
          farmer_id: string;
          quantity_kg: number;
          price_per_kg: number;
          subtotal: number;
          pickup_location?: unknown | null;
          pickup_confirmed?: boolean;
          pickup_photo_url?: string | null;
          delivery_confirmed?: boolean;
        };
        Update: {
          id?: string;
          order_id?: string;
          listing_id?: string;
          farmer_id?: string;
          quantity_kg?: number;
          price_per_kg?: number;
          subtotal?: number;
          pickup_location?: unknown | null;
          pickup_confirmed?: boolean;
          pickup_photo_url?: string | null;
          delivery_confirmed?: boolean;
        };
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: {
      app_language: "en" | "ne";
      app_role: "farmer" | "consumer" | "rider";
      order_status:
        | "pending"
        | "matched"
        | "picked_up"
        | "in_transit"
        | "delivered"
        | "cancelled"
        | "disputed";
      payment_method: "cash" | "esewa" | "khalti";
      payment_status: "pending" | "collected" | "settled";
      role_rated: "farmer" | "consumer" | "rider";
      trip_status: "scheduled" | "in_transit" | "completed" | "cancelled";
      vehicle_type: "bike" | "car" | "truck" | "bus" | "other";
    };
  };
};

export type Tables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Row"];
export type InsertTables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Insert"];
export type UpdateTables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Update"];
