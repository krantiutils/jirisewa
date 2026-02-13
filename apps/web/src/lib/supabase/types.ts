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
        Relationships: [];
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
        Relationships: [
          {
            foreignKeyName: "user_roles_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
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
        Relationships: [];
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
        Relationships: [
          {
            foreignKeyName: "produce_listings_farmer_id_fkey";
            columns: ["farmer_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "produce_listings_category_id_fkey";
            columns: ["category_id"];
            isOneToOne: false;
            referencedRelation: "produce_categories";
            referencedColumns: ["id"];
          },
        ];
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
        Relationships: [
          {
            foreignKeyName: "orders_consumer_id_fkey";
            columns: ["consumer_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
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
        Relationships: [
          {
            foreignKeyName: "order_items_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "orders";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "order_items_listing_id_fkey";
            columns: ["listing_id"];
            isOneToOne: false;
            referencedRelation: "produce_listings";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "order_items_farmer_id_fkey";
            columns: ["farmer_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
      };
      rider_trips: {
        Row: {
          id: string;
          rider_id: string;
          origin: unknown;
          origin_name: string;
          destination: unknown;
          destination_name: string;
          route: unknown | null;
          departure_at: string;
          available_capacity_kg: number;
          remaining_capacity_kg: number;
          status: "scheduled" | "in_transit" | "completed" | "cancelled";
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          rider_id: string;
          origin: unknown;
          origin_name: string;
          destination: unknown;
          destination_name: string;
          route?: unknown | null;
          departure_at: string;
          available_capacity_kg: number;
          remaining_capacity_kg: number;
          status?: "scheduled" | "in_transit" | "completed" | "cancelled";
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          rider_id?: string;
          origin?: unknown;
          origin_name?: string;
          destination?: unknown;
          destination_name?: string;
          route?: unknown | null;
          departure_at?: string;
          available_capacity_kg?: number;
          remaining_capacity_kg?: number;
          status?: "scheduled" | "in_transit" | "completed" | "cancelled";
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "rider_trips_rider_id_fkey";
            columns: ["rider_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
      };
      ratings: {
        Row: {
          id: string;
          order_id: string;
          rater_id: string;
          rated_id: string;
          role_rated: "farmer" | "consumer" | "rider";
          score: number;
          comment: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          order_id: string;
          rater_id: string;
          rated_id: string;
          role_rated: "farmer" | "consumer" | "rider";
          score: number;
          comment?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          order_id?: string;
          rater_id?: string;
          rated_id?: string;
          role_rated?: "farmer" | "consumer" | "rider";
          score?: number;
          comment?: string | null;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "ratings_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "orders";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "ratings_rater_id_fkey";
            columns: ["rater_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "ratings_rated_id_fkey";
            columns: ["rated_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
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

export type AppRole = Database["public"]["Enums"]["app_role"];
export type AppLanguage = Database["public"]["Enums"]["app_language"];
export type ProduceListing = Database["public"]["Tables"]["produce_listings"]["Row"];
export type ProduceCategory = Database["public"]["Tables"]["produce_categories"]["Row"];
export type User = Database["public"]["Tables"]["users"]["Row"];

export interface ProduceListingWithDetails extends ProduceListing {
  farmer: Pick<User, "id" | "name" | "avatar_url" | "rating_avg" | "rating_count">;
  category: Pick<ProduceCategory, "id" | "name_en" | "name_ne" | "icon">;
  distance_km?: number;
}
