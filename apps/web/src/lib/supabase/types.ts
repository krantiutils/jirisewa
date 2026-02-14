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
          is_admin: boolean;
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
          is_admin?: boolean;
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
          is_admin?: boolean;
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
          verification_status: "unverified" | "pending" | "approved" | "rejected";
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
          verification_status?: "unverified" | "pending" | "approved" | "rejected";
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
          verification_status?: "unverified" | "pending" | "approved" | "rejected";
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
      delivery_rates: {
        Row: {
          id: string;
          base_fee_npr: number;
          per_km_rate_npr: number;
          per_kg_rate_npr: number;
          min_fee_npr: number;
          max_fee_npr: number | null;
          is_active: boolean;
          effective_from: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          base_fee_npr: number;
          per_km_rate_npr: number;
          per_kg_rate_npr: number;
          min_fee_npr?: number;
          max_fee_npr?: number | null;
          is_active?: boolean;
          effective_from?: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          base_fee_npr?: number;
          per_km_rate_npr?: number;
          per_kg_rate_npr?: number;
          min_fee_npr?: number;
          max_fee_npr?: number | null;
          is_active?: boolean;
          effective_from?: string;
          created_at?: string;
        };
        Relationships: [];
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
          delivery_fee_base: number;
          delivery_fee_distance: number;
          delivery_fee_weight: number;
          delivery_distance_km: number | null;
          parent_order_id: string | null;
          payment_method: "cash" | "esewa" | "khalti";
          payment_status: "pending" | "escrowed" | "collected" | "settled" | "refunded";
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
          delivery_fee_base?: number;
          delivery_fee_distance?: number;
          delivery_fee_weight?: number;
          delivery_distance_km?: number | null;
          parent_order_id?: string | null;
          payment_method?: "cash" | "esewa" | "khalti";
          payment_status?: "pending" | "escrowed" | "collected" | "settled" | "refunded";
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
          delivery_fee_base?: number;
          delivery_fee_distance?: number;
          delivery_fee_weight?: number;
          delivery_distance_km?: number | null;
          parent_order_id?: string | null;
          payment_method?: "cash" | "esewa" | "khalti";
          payment_status?: "pending" | "escrowed" | "collected" | "settled" | "refunded";
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
          {
            foreignKeyName: "orders_rider_id_fkey";
            columns: ["rider_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "orders_rider_trip_id_fkey";
            columns: ["rider_trip_id"];
            isOneToOne: false;
            referencedRelation: "rider_trips";
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
          pickup_status: "pending_pickup" | "picked_up" | "unavailable";
          pickup_sequence: number;
          pickup_confirmed_at: string | null;
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
          pickup_status?: "pending_pickup" | "picked_up" | "unavailable";
          pickup_sequence?: number;
          pickup_confirmed_at?: string | null;
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
          pickup_status?: "pending_pickup" | "picked_up" | "unavailable";
          pickup_sequence?: number;
          pickup_confirmed_at?: string | null;
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
      esewa_transactions: {
        Row: {
          id: string;
          order_id: string;
          transaction_uuid: string;
          product_code: string;
          amount: number;
          tax_amount: number;
          service_charge: number;
          delivery_charge: number;
          total_amount: number;
          status: string;
          esewa_ref_id: string | null;
          esewa_status: string | null;
          verified_at: string | null;
          escrow_released_at: string | null;
          refunded_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          order_id: string;
          transaction_uuid: string;
          product_code: string;
          amount: number;
          tax_amount?: number;
          service_charge?: number;
          delivery_charge?: number;
          total_amount: number;
          status?: string;
          esewa_ref_id?: string | null;
          esewa_status?: string | null;
          verified_at?: string | null;
          escrow_released_at?: string | null;
          refunded_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          order_id?: string;
          transaction_uuid?: string;
          product_code?: string;
          amount?: number;
          tax_amount?: number;
          service_charge?: number;
          delivery_charge?: number;
          total_amount?: number;
          status?: string;
          esewa_ref_id?: string | null;
          esewa_status?: string | null;
          verified_at?: string | null;
          escrow_released_at?: string | null;
          refunded_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "esewa_transactions_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "orders";
            referencedColumns: ["id"];
          },
        ];
      };
      rider_location_log: {
        Row: {
          id: string;
          rider_id: string;
          trip_id: string;
          location: unknown;
          speed_kmh: number | null;
          recorded_at: string;
        };
        Insert: {
          id?: string;
          rider_id: string;
          trip_id: string;
          location: unknown;
          speed_kmh?: number | null;
          recorded_at?: string;
        };
        Update: {
          id?: string;
          rider_id?: string;
          trip_id?: string;
          location?: unknown;
          speed_kmh?: number | null;
          recorded_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "rider_location_log_rider_id_fkey";
            columns: ["rider_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rider_location_log_trip_id_fkey";
            columns: ["trip_id"];
            isOneToOne: false;
            referencedRelation: "rider_trips";
            referencedColumns: ["id"];
          },
        ];
      };
      verification_documents: {
        Row: {
          id: string;
          user_role_id: string;
          citizenship_photo_url: string;
          farm_photo_url: string;
          municipality_letter_url: string | null;
          admin_notes: string | null;
          reviewed_by: string | null;
          reviewed_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_role_id: string;
          citizenship_photo_url: string;
          farm_photo_url: string;
          municipality_letter_url?: string | null;
          admin_notes?: string | null;
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_role_id?: string;
          citizenship_photo_url?: string;
          farm_photo_url?: string;
          municipality_letter_url?: string | null;
          admin_notes?: string | null;
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "verification_documents_user_role_id_fkey";
            columns: ["user_role_id"];
            isOneToOne: false;
            referencedRelation: "user_roles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "verification_documents_reviewed_by_fkey";
            columns: ["reviewed_by"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
      };
      farmer_payouts: {
        Row: {
          id: string;
          order_id: string;
          farmer_id: string;
          amount: number;
          status: "pending" | "settled" | "refunded";
          settled_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          order_id: string;
          farmer_id: string;
          amount: number;
          status?: "pending" | "settled" | "refunded";
          settled_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          order_id?: string;
          farmer_id?: string;
          amount?: number;
          status?: "pending" | "settled" | "refunded";
          settled_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "farmer_payouts_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "orders";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "farmer_payouts_farmer_id_fkey";
            columns: ["farmer_id"];
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
      user_devices: {
        Row: {
          id: string;
          user_id: string;
          fcm_token: string;
          platform: "web" | "android" | "ios";
          device_name: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          fcm_token: string;
          platform: "web" | "android" | "ios";
          device_name?: string | null;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          fcm_token?: string;
          platform?: "web" | "android" | "ios";
          device_name?: string | null;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "user_devices_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
      };
      notification_preferences: {
        Row: {
          id: string;
          user_id: string;
          category:
            | "order_matched"
            | "rider_picked_up"
            | "rider_arriving"
            | "order_delivered"
            | "new_order_for_farmer"
            | "rider_arriving_for_pickup"
            | "new_order_match"
            | "trip_reminder"
            | "delivery_confirmed";
          enabled: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          category:
            | "order_matched"
            | "rider_picked_up"
            | "rider_arriving"
            | "order_delivered"
            | "new_order_for_farmer"
            | "rider_arriving_for_pickup"
            | "new_order_match"
            | "trip_reminder"
            | "delivery_confirmed";
          enabled?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          category?:
            | "order_matched"
            | "rider_picked_up"
            | "rider_arriving"
            | "order_delivered"
            | "new_order_for_farmer"
            | "rider_arriving_for_pickup"
            | "new_order_match"
            | "trip_reminder"
            | "delivery_confirmed";
          enabled?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notification_preferences_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
      };
      notifications: {
        Row: {
          id: string;
          user_id: string;
          category:
            | "order_matched"
            | "rider_picked_up"
            | "rider_arriving"
            | "order_delivered"
            | "new_order_for_farmer"
            | "rider_arriving_for_pickup"
            | "new_order_match"
            | "trip_reminder"
            | "delivery_confirmed";
          title_en: string;
          title_ne: string;
          body_en: string;
          body_ne: string;
          data: Record<string, unknown>;
          read: boolean;
          push_sent: boolean;
          sms_fallback_sent: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          category:
            | "order_matched"
            | "rider_picked_up"
            | "rider_arriving"
            | "order_delivered"
            | "new_order_for_farmer"
            | "rider_arriving_for_pickup"
            | "new_order_match"
            | "trip_reminder"
            | "delivery_confirmed";
          title_en: string;
          title_ne: string;
          body_en: string;
          body_ne: string;
          data?: Record<string, unknown>;
          read?: boolean;
          push_sent?: boolean;
          sms_fallback_sent?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          category?:
            | "order_matched"
            | "rider_picked_up"
            | "rider_arriving"
            | "order_delivered"
            | "new_order_for_farmer"
            | "rider_arriving_for_pickup"
            | "new_order_match"
            | "trip_reminder"
            | "delivery_confirmed";
          title_en?: string;
          title_ne?: string;
          body_en?: string;
          body_ne?: string;
          data?: Record<string, unknown>;
          read?: boolean;
          push_sent?: boolean;
          sms_fallback_sent?: boolean;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
      };
      chat_conversations: {
        Row: {
          id: string;
          order_id: string;
          participant_ids: string[];
          created_at: string;
        };
        Insert: {
          id?: string;
          order_id: string;
          participant_ids: string[];
          created_at?: string;
        };
        Update: {
          id?: string;
          order_id?: string;
          participant_ids?: string[];
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "chat_conversations_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "orders";
            referencedColumns: ["id"];
          },
        ];
      };
      chat_messages: {
        Row: {
          id: string;
          conversation_id: string;
          sender_id: string;
          content: string;
          message_type: "text" | "image" | "location";
          read_at: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          conversation_id: string;
          sender_id: string;
          content: string;
          message_type?: "text" | "image" | "location";
          read_at?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          conversation_id?: string;
          sender_id?: string;
          content?: string;
          message_type?: "text" | "image" | "location";
          read_at?: string | null;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "chat_messages_conversation_id_fkey";
            columns: ["conversation_id"];
            isOneToOne: false;
            referencedRelation: "chat_conversations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "chat_messages_sender_id_fkey";
            columns: ["sender_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
        ];
      };
      order_pings: {
        Row: {
          id: string;
          order_id: string;
          rider_id: string;
          trip_id: string;
          pickup_locations: Json;
          delivery_location: Json;
          total_weight_kg: number;
          estimated_earnings: number;
          detour_distance_m: number;
          status: "pending" | "accepted" | "declined" | "expired";
          expires_at: string;
          responded_at: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          order_id: string;
          rider_id: string;
          trip_id: string;
          pickup_locations: Json;
          delivery_location: Json;
          total_weight_kg: number;
          estimated_earnings: number;
          detour_distance_m: number;
          status?: "pending" | "accepted" | "declined" | "expired";
          expires_at: string;
          responded_at?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          order_id?: string;
          rider_id?: string;
          trip_id?: string;
          pickup_locations?: Json;
          delivery_location?: Json;
          total_weight_kg?: number;
          estimated_earnings?: number;
          detour_distance_m?: number;
          status?: "pending" | "accepted" | "declined" | "expired";
          expires_at?: string;
          responded_at?: string | null;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "order_pings_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "orders";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "order_pings_rider_id_fkey";
            columns: ["rider_id"];
            isOneToOne: false;
            referencedRelation: "users";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "order_pings_trip_id_fkey";
            columns: ["trip_id"];
            isOneToOne: false;
            referencedRelation: "rider_trips";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: Record<string, never>;
    Functions: {
      create_notification: {
        Args: {
          p_user_id: string;
          p_category:
            | "order_matched"
            | "rider_picked_up"
            | "rider_arriving"
            | "order_delivered"
            | "new_order_for_farmer"
            | "rider_arriving_for_pickup"
            | "new_order_match"
            | "trip_reminder"
            | "delivery_confirmed";
          p_title_en: string;
          p_title_ne: string;
          p_body_en: string;
          p_body_ne: string;
          p_data?: Record<string, unknown>;
        };
        Returns: Record<string, unknown>;
      };
      mark_notification_read: {
        Args: { p_notification_id: string };
        Returns: void;
      };
      mark_all_notifications_read: {
        Args: Record<string, never>;
        Returns: void;
      };
      get_unread_notification_count: {
        Args: Record<string, never>;
        Returns: number;
      };
    };
    Enums: {
      app_language: "en" | "ne";
      app_role: "farmer" | "consumer" | "rider";
      notification_category:
        | "order_matched"
        | "rider_picked_up"
        | "rider_arriving"
        | "order_delivered"
        | "new_order_for_farmer"
        | "rider_arriving_for_pickup"
        | "new_order_match"
        | "trip_reminder"
        | "delivery_confirmed";
      device_platform: "web" | "android" | "ios";
      order_status:
        | "pending"
        | "matched"
        | "picked_up"
        | "in_transit"
        | "delivered"
        | "cancelled"
        | "disputed";
      payment_method: "cash" | "esewa" | "khalti";
      payment_status: "pending" | "escrowed" | "collected" | "settled" | "refunded";
      role_rated: "farmer" | "consumer" | "rider";
      trip_status: "scheduled" | "in_transit" | "completed" | "cancelled";
      vehicle_type: "bike" | "car" | "truck" | "bus" | "other";
      verification_status: "unverified" | "pending" | "approved" | "rejected";
      order_item_status: "pending_pickup" | "picked_up" | "unavailable";
      payout_status: "pending" | "settled" | "refunded";
      ping_status: "pending" | "accepted" | "declined" | "expired";
      message_type: "text" | "image" | "location";
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
  farmer_verified?: boolean;
}

export type VerificationStatus = Database["public"]["Enums"]["verification_status"];
export type VerificationDocument = Database["public"]["Tables"]["verification_documents"]["Row"];
