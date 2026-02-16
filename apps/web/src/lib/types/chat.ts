export interface ChatConversation {
  id: string;
  order_id: string;
  participant_ids: string[];
  created_at: string;
  /** All other participants in the conversation (for 3-way chat) */
  participants?: {
    id: string;
    name: string;
    avatar_url: string | null;
    role: "farmer" | "consumer" | "rider";
  }[];
  /** @deprecated Use participants instead */
  other_user?: {
    id: string;
    name: string;
    avatar_url: string | null;
    role: "farmer" | "consumer" | "rider";
  };
  /** Most recent message in the conversation */
  last_message?: {
    content: string;
    message_type: "text" | "image" | "location";
    created_at: string;
    sender_id: string;
  };
  /** Number of unread messages for the current user */
  unread_count: number;
}

export interface ChatMessage {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  message_type: "text" | "image" | "location";
  read_at: string | null;
  created_at: string;
  /** Joined sender info */
  sender?: {
    name: string;
    avatar_url: string | null;
  };
}
