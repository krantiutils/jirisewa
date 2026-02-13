/**
 * Database types matching the Supabase schema.
 * Generated manually from supabase/migrations/20260214000002_core_tables.sql.
 *
 * When `supabase gen types typescript` becomes available, replace this file
 * with the auto-generated output.
 */

export type Json = string | number | boolean | null | { [key: string]: Json } | Json[];

export type AppRole = "farmer" | "consumer" | "rider";
export type VehicleType = "bike" | "car" | "truck" | "bus" | "other";
export type TripStatus = "scheduled" | "in_transit" | "completed" | "cancelled";
export type OrderStatus =
  | "pending"
  | "matched"
  | "picked_up"
  | "in_transit"
  | "delivered"
  | "cancelled"
  | "disputed";
export type PaymentMethod = "cash" | "esewa" | "khalti";
export type PaymentStatus = "pending" | "collected" | "settled";
export type AppLanguage = "en" | "ne";
export type RoleRated = "farmer" | "consumer" | "rider";

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string;
          phone: string;
          name: string;
          role: AppRole;
          avatar_url: string | null;
          location: string | null; // PostGIS geography serialised as GeoJSON/WKT
          address: string | null;
          municipality: string | null;
          lang: AppLanguage;
          rating_avg: number;
          rating_count: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          phone: string;
          name: string;
          role: AppRole;
          avatar_url?: string | null;
          location?: string | null;
          address?: string | null;
          municipality?: string | null;
          lang?: AppLanguage;
          rating_avg?: number;
          rating_count?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database["public"]["Tables"]["users"]["Insert"]>;
      };
      user_roles: {
        Row: {
          id: string;
          user_id: string;
          role: AppRole;
          farm_name: string | null;
          vehicle_type: VehicleType | null;
          vehicle_capacity_kg: number | null;
          license_photo_url: string | null;
          verified: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          role: AppRole;
          farm_name?: string | null;
          vehicle_type?: VehicleType | null;
          vehicle_capacity_kg?: number | null;
          license_photo_url?: string | null;
          verified?: boolean;
          created_at?: string;
        };
        Update: Partial<Database["public"]["Tables"]["user_roles"]["Insert"]>;
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
        Update: Partial<Database["public"]["Tables"]["produce_categories"]["Insert"]>;
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
          location: string | null;
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
          location?: string | null;
          photos?: string[];
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database["public"]["Tables"]["produce_listings"]["Insert"]>;
      };
      ratings: {
        Row: {
          id: string;
          order_id: string;
          rater_id: string;
          rated_id: string;
          role_rated: RoleRated;
          score: number;
          comment: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          order_id: string;
          rater_id: string;
          rated_id: string;
          role_rated: RoleRated;
          score: number;
          comment?: string | null;
          created_at?: string;
        };
        Update: Partial<Database["public"]["Tables"]["ratings"]["Insert"]>;
      };
    };
  };
}

/** Convenience aliases */
export type ProduceListing = Database["public"]["Tables"]["produce_listings"]["Row"];
export type ProduceCategory = Database["public"]["Tables"]["produce_categories"]["Row"];
export type User = Database["public"]["Tables"]["users"]["Row"];

/** A produce listing enriched with joined farmer + category data */
export interface ProduceListingWithDetails extends ProduceListing {
  farmer: Pick<User, "id" | "name" | "avatar_url" | "rating_avg" | "rating_count">;
  category: Pick<ProduceCategory, "id" | "name_en" | "name_ne" | "icon">;
  /** Distance in km from the consumer's location — computed at query time */
  distance_km?: number;
}
