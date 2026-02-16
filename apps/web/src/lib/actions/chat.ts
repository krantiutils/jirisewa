"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import type { ActionResult } from "@/lib/types/action";
import type { ChatConversation, ChatMessage } from "@/lib/types/chat";

// TODO: Replace hardcoded user ID with authenticated user once auth is wired
const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";

/**
 * Get or create a conversation between the current user and another user for an order.
 * Ensures only one conversation per (order, participant pair).
 */
export async function getOrCreateConversation(
  orderId: string,
  otherUserId: string,
): Promise<ActionResult<{ conversationId: string }>> {
  try {
    const supabase = createServiceRoleClient();
    const currentUserId = DEMO_CONSUMER_ID;

    // Sort participant IDs for consistent storage (prevents duplicate conversations)
    const participantIds = [currentUserId, otherUserId].sort();

    // Try to find existing conversation
    const { data: existing, error: findError } = await supabase
      .from("chat_conversations")
      .select("id")
      .eq("order_id", orderId)
      .contains("participant_ids", participantIds)
      .single();

    if (existing && !findError) {
      return { data: { conversationId: existing.id } };
    }

    // Create new conversation
    const { data: created, error: createError } = await supabase
      .from("chat_conversations")
      .insert({
        order_id: orderId,
        participant_ids: participantIds,
      })
      .select("id")
      .single();

    if (createError) {
      // Handle race condition: another request created it first
      if (createError.code === "23505") {
        const { data: raceResult } = await supabase
          .from("chat_conversations")
          .select("id")
          .eq("order_id", orderId)
          .contains("participant_ids", participantIds)
          .single();

        if (raceResult) {
          return { data: { conversationId: raceResult.id } };
        }
      }
      console.error("getOrCreateConversation error:", createError);
      return { error: createError.message };
    }

    return { data: { conversationId: created.id } };
  } catch (err) {
    console.error("getOrCreateConversation unexpected error:", err);
    return { error: "Failed to create conversation" };
  }
}

/**
 * Add a rider to an existing conversation (3-way chat).
 * Called when a rider accepts an order ping.
 */
export async function addRiderToConversation(
  orderId: string,
  riderId: string,
): Promise<ActionResult<{ conversationId: string }>> {
  try {
    const supabase = createServiceRoleClient();

    // Find the existing conversation for this order
    const { data: existing, error: findError } = await supabase
      .from("chat_conversations")
      .select("id, participant_ids")
      .eq("order_id", orderId)
      .single();

    if (findError || !existing) {
      // No conversation exists yet - this is fine, it might be created later
      return { error: "No conversation found for this order" };
    }

    // Check if rider is already in the conversation
    if (existing.participant_ids.includes(riderId)) {
      return { data: { conversationId: existing.id } };
    }

    // Add rider to participants
    const { error: updateError } = await supabase
      .from("chat_conversations")
      .update({
        participant_ids: [...existing.participant_ids, riderId],
      })
      .eq("id", existing.id);

    if (updateError) {
      console.error("addRiderToConversation error:", updateError);
      return { error: updateError.message };
    }

    // Send a system message announcing the rider joined
    const { data: rider } = await supabase
      .from("users")
      .select("name, role")
      .eq("id", riderId)
      .single();

    if (rider) {
      await supabase
        .from("chat_messages")
        .insert({
          conversation_id: existing.id,
          sender_id: "system", // Special ID for system messages
          content: `${rider.name} (${rider.role}) joined the conversation`,
          message_type: "text",
          read_at: new Date().toISOString(), // Auto-mark as read
        });
    }

    return { data: { conversationId: existing.id } };
  } catch (err) {
    console.error("addRiderToConversation unexpected error:", err);
    return { error: "Failed to add rider to conversation" };
  }
}

/**
 * Send a message in a conversation.
 */
export async function sendMessage(
  conversationId: string,
  content: string,
  messageType: "text" | "image" | "location" = "text",
): Promise<ActionResult<ChatMessage>> {
  try {
    const supabase = createServiceRoleClient();
    const currentUserId = DEMO_CONSUMER_ID;

    // Verify the user is a participant
    const { data: conversation, error: convError } = await supabase
      .from("chat_conversations")
      .select("id, participant_ids")
      .eq("id", conversationId)
      .single();

    if (convError || !conversation) {
      return { error: "Conversation not found" };
    }

    if (!conversation.participant_ids.includes(currentUserId)) {
      return { error: "You are not a participant in this conversation" };
    }

    const { data: message, error: insertError } = await supabase
      .from("chat_messages")
      .insert({
        conversation_id: conversationId,
        sender_id: currentUserId,
        content,
        message_type: messageType,
      })
      .select("*")
      .single();

    if (insertError) {
      console.error("sendMessage error:", insertError);
      return { error: insertError.message };
    }

    return { data: message as ChatMessage };
  } catch (err) {
    console.error("sendMessage unexpected error:", err);
    return { error: "Failed to send message" };
  }
}

/**
 * List conversations for the current user, with last message and unread count.
 */
export async function listConversations(): Promise<ActionResult<ChatConversation[]>> {
  try {
    const supabase = createServiceRoleClient();
    const currentUserId = DEMO_CONSUMER_ID;

    // Get all conversations where user is a participant
    const { data: conversations, error: convError } = await supabase
      .from("chat_conversations")
      .select("*")
      .contains("participant_ids", [currentUserId])
      .order("created_at", { ascending: false });

    if (convError) {
      console.error("listConversations error:", convError);
      return { error: convError.message };
    }

    if (!conversations || conversations.length === 0) {
      return { data: [] };
    }

    // Collect all other participant IDs
    const otherUserIds = new Set<string>();
    for (const conv of conversations) {
      for (const pid of conv.participant_ids) {
        if (pid !== currentUserId) otherUserIds.add(pid);
      }
    }

    // Fetch user info for other participants
    const { data: users } = await supabase
      .from("users")
      .select("id, name, avatar_url, role")
      .in("id", Array.from(otherUserIds));

    const userMap = new Map(users?.map((u) => [u.id, u]) ?? []);

    // For each conversation, get last message and unread count
    const result: ChatConversation[] = [];
    for (const conv of conversations) {
      // Get all other participants (for 3-way chat)
      const participantUsers: Array<{
        id: string;
        name: string;
        avatar_url: string | null;
        role: "farmer" | "consumer" | "rider";
      }> = [];
      for (const pid of conv.participant_ids) {
        if (pid !== currentUserId) {
          const user = userMap.get(pid);
          if (user) participantUsers.push(user as {
            id: string;
            name: string;
            avatar_url: string | null;
            role: "farmer" | "consumer" | "rider";
          });
        }
      }

      // For backwards compatibility, set other_user to first participant
      const otherUserId = conv.participant_ids.find(
        (id: string) => id !== currentUserId,
      );

      // Get last message
      const { data: lastMessages } = await supabase
        .from("chat_messages")
        .select("content, message_type, created_at, sender_id")
        .eq("conversation_id", conv.id)
        .order("created_at", { ascending: false })
        .limit(1);

      // Count unread (messages not from current user where read_at is null)
      const { count: unreadCount } = await supabase
        .from("chat_messages")
        .select("*", { count: "exact", head: true })
        .eq("conversation_id", conv.id)
        .neq("sender_id", currentUserId)
        .is("read_at", null);

      result.push({
        id: conv.id,
        order_id: conv.order_id,
        participant_ids: conv.participant_ids,
        created_at: conv.created_at,
        participants: participantUsers,
        other_user: otherUserId ? userMap.get(otherUserId) ?? undefined : undefined,
        last_message: lastMessages?.[0] ?? undefined,
        unread_count: unreadCount ?? 0,
      });
    }

    // Sort by last message time (most recent first)
    result.sort((a, b) => {
      const aTime = a.last_message?.created_at ?? a.created_at;
      const bTime = b.last_message?.created_at ?? b.created_at;
      return new Date(bTime).getTime() - new Date(aTime).getTime();
    });

    return { data: result };
  } catch (err) {
    console.error("listConversations unexpected error:", err);
    return { error: "Failed to list conversations" };
  }
}

/**
 * Get messages for a conversation (paginated).
 */
export async function getMessages(
  conversationId: string,
  limit: number = 50,
  beforeId?: string,
): Promise<ActionResult<ChatMessage[]>> {
  try {
    const supabase = createServiceRoleClient();
    const currentUserId = DEMO_CONSUMER_ID;

    // Verify the user is a participant
    const { data: conversation, error: convError } = await supabase
      .from("chat_conversations")
      .select("participant_ids")
      .eq("id", conversationId)
      .single();

    if (convError || !conversation) {
      return { error: "Conversation not found" };
    }

    if (!conversation.participant_ids.includes(currentUserId)) {
      return { error: "You are not a participant in this conversation" };
    }

    let query = supabase
      .from("chat_messages")
      .select("*, sender:users!chat_messages_sender_id_fkey(name, avatar_url)")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true })
      .limit(limit);

    if (beforeId) {
      // Fetch the timestamp for cursor-based pagination
      const { data: cursorMsg } = await supabase
        .from("chat_messages")
        .select("created_at")
        .eq("id", beforeId)
        .single();

      if (cursorMsg) {
        query = query.lt("created_at", cursorMsg.created_at);
      }
    }

    const { data: messages, error: msgError } = await query;

    if (msgError) {
      console.error("getMessages error:", msgError);
      return { error: msgError.message };
    }

    return { data: (messages ?? []) as ChatMessage[] };
  } catch (err) {
    console.error("getMessages unexpected error:", err);
    return { error: "Failed to load messages" };
  }
}

/**
 * Mark all messages in a conversation as read (messages not sent by the current user).
 */
export async function markConversationRead(
  conversationId: string,
): Promise<ActionResult> {
  try {
    const supabase = createServiceRoleClient();
    const currentUserId = DEMO_CONSUMER_ID;

    const { error } = await supabase
      .from("chat_messages")
      .update({ read_at: new Date().toISOString() })
      .eq("conversation_id", conversationId)
      .neq("sender_id", currentUserId)
      .is("read_at", null);

    if (error) {
      console.error("markConversationRead error:", error);
      return { error: error.message };
    }

    return {};
  } catch (err) {
    console.error("markConversationRead unexpected error:", err);
    return { error: "Failed to mark messages as read" };
  }
}

/**
 * Get total unread message count across all conversations.
 */
export async function getTotalUnreadCount(): Promise<ActionResult<number>> {
  try {
    const supabase = createServiceRoleClient();
    const currentUserId = DEMO_CONSUMER_ID;

    // Get all conversation IDs where the user is a participant
    const { data: conversations } = await supabase
      .from("chat_conversations")
      .select("id")
      .contains("participant_ids", [currentUserId]);

    if (!conversations || conversations.length === 0) {
      return { data: 0 };
    }

    const convIds = conversations.map((c) => c.id);

    const { count, error } = await supabase
      .from("chat_messages")
      .select("*", { count: "exact", head: true })
      .in("conversation_id", convIds)
      .neq("sender_id", currentUserId)
      .is("read_at", null);

    if (error) {
      console.error("getTotalUnreadCount error:", error);
      return { error: error.message };
    }

    return { data: count ?? 0 };
  } catch (err) {
    console.error("getTotalUnreadCount unexpected error:", err);
    return { error: "Failed to get unread count" };
  }
}

/**
 * Upload a chat image to Supabase Storage.
 */
export async function uploadChatImage(
  formData: FormData,
): Promise<ActionResult<{ url: string }>> {
  try {
    const supabase = createServiceRoleClient();
    const file = formData.get("file") as File | null;

    if (!file) {
      return { error: "No file provided" };
    }

    const ext = file.name.split(".").pop() ?? "jpg";
    const path = `${DEMO_CONSUMER_ID}/${Date.now()}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from("chat-images")
      .upload(path, file, {
        cacheControl: "3600",
        upsert: false,
      });

    if (uploadError) {
      console.error("uploadChatImage error:", uploadError);
      return { error: uploadError.message };
    }

    const { data: urlData } = supabase.storage
      .from("chat-images")
      .getPublicUrl(path);

    return { data: { url: urlData.publicUrl } };
  } catch (err) {
    console.error("uploadChatImage unexpected error:", err);
    return { error: "Failed to upload image" };
  }
}

/**
 * Get conversation details (for the conversation page header).
 */
export async function getConversationDetails(
  conversationId: string,
): Promise<ActionResult<{
  conversation: ChatConversation;
  orderId: string;
}>> {
  try {
    const supabase = createServiceRoleClient();
    const currentUserId = DEMO_CONSUMER_ID;

    const { data: conv, error: convError } = await supabase
      .from("chat_conversations")
      .select("*")
      .eq("id", conversationId)
      .single();

    if (convError || !conv) {
      return { error: "Conversation not found" };
    }

    if (!conv.participant_ids.includes(currentUserId)) {
      return { error: "You are not a participant in this conversation" };
    }

    const otherUserId = conv.participant_ids.find(
      (id: string) => id !== currentUserId,
    );

    // Get all other participants (for 3-way chat)
    const otherParticipantIds = conv.participant_ids.filter(
      (id: string) => id !== currentUserId,
    );

    let participants: Array<{ id: string; name: string; avatar_url: string | null; role: "farmer" | "consumer" | "rider" }> = [];
    let otherUser;

    if (otherParticipantIds.length > 0) {
      const { data: users } = await supabase
        .from("users")
        .select("id, name, avatar_url, role")
        .in("id", otherParticipantIds);

      participants = (users ?? []).map((u) => ({
        id: u.id,
        name: u.name,
        avatar_url: u.avatar_url,
        role: u.role as "farmer" | "consumer" | "rider",
      }));

      // For backwards compatibility, set other_user to first participant
      otherUser = participants[0];
    }

    return {
      data: {
        conversation: {
          id: conv.id,
          order_id: conv.order_id,
          participant_ids: conv.participant_ids,
          created_at: conv.created_at,
          participants,
          other_user: otherUser,
          unread_count: 0,
        },
        orderId: conv.order_id,
      },
    };
  } catch (err) {
    console.error("getConversationDetails unexpected error:", err);
    return { error: "Failed to load conversation" };
  }
}
