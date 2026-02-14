"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { useTranslations } from "next-intl";
import {
  ArrowLeft,
  Send,
  ImagePlus,
  Loader2,
  User,
  X,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import {
  getConversationDetails,
  getMessages,
  sendMessage,
  markConversationRead,
  uploadChatImage,
} from "@/lib/actions/chat";
import type { ChatConversation, ChatMessage } from "@/lib/types/chat";

const DEMO_CONSUMER_ID = "00000000-0000-0000-0000-000000000001";

const ROLE_COLORS: Record<string, string> = {
  consumer: "bg-blue-500",
  farmer: "bg-emerald-500",
  rider: "bg-amber-500",
};

export default function ConversationPage() {
  const { locale, conversationId } = useParams<{
    locale: string;
    conversationId: string;
  }>();
  const t = useTranslations("chat");

  const [conversation, setConversation] = useState<ChatConversation | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [inputText, setInputText] = useState("");
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Auto-scroll to latest message
  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, []);

  // Load conversation and messages
  useEffect(() => {
    async function load() {
      const [convResult, msgResult] = await Promise.all([
        getConversationDetails(conversationId),
        getMessages(conversationId),
      ]);

      if (convResult.data) {
        setConversation(convResult.data.conversation);
      }
      if (msgResult.data) {
        setMessages(msgResult.data);
      }
      setLoading(false);

      // Mark messages as read
      markConversationRead(conversationId);
    }
    load();
  }, [conversationId]);

  // Scroll to bottom when messages change
  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  // Subscribe to realtime new messages
  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`chat:${conversationId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "chat_messages",
          filter: `conversation_id=eq.${conversationId}`,
        },
        (payload) => {
          const newMsg = payload.new as ChatMessage;
          setMessages((prev) => {
            // Avoid duplicates
            if (prev.some((m) => m.id === newMsg.id)) return prev;
            return [...prev, newMsg];
          });
          // Mark as read if from the other user
          if (newMsg.sender_id !== DEMO_CONSUMER_ID) {
            markConversationRead(conversationId);
          }
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [conversationId]);

  const handleSend = async () => {
    const text = inputText.trim();
    if (!text && !imageFile) return;

    setSending(true);

    try {
      if (imageFile) {
        // Upload image first, then send as image message
        const formData = new FormData();
        formData.append("file", imageFile);
        const uploadResult = await uploadChatImage(formData);
        if (uploadResult.data) {
          await sendMessage(conversationId, uploadResult.data.url, "image");
        }
        setImageFile(null);
        setImagePreview(null);
      }

      if (text) {
        await sendMessage(conversationId, text, "text");
        setInputText("");
      }
    } finally {
      setSending(false);
      inputRef.current?.focus();
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 5 * 1024 * 1024) {
      return; // 5MB limit
    }

    setImageFile(file);
    const reader = new FileReader();
    reader.onload = (ev) => setImagePreview(ev.target?.result as string);
    reader.readAsDataURL(file);
  };

  const clearImagePreview = () => {
    setImageFile(null);
    setImagePreview(null);
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const formatMessageTime = (dateStr: string) => {
    return new Date(dateStr).toLocaleTimeString(
      locale === "ne" ? "ne-NP" : "en-US",
      { hour: "2-digit", minute: "2-digit" },
    );
  };

  const formatDateSeparator = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);

    if (date.toDateString() === now.toDateString()) return t("today");
    if (date.toDateString() === yesterday.toDateString()) return t("yesterday");

    return date.toLocaleDateString(locale === "ne" ? "ne-NP" : "en-US", {
      month: "short",
      day: "numeric",
      year: date.getFullYear() !== now.getFullYear() ? "numeric" : undefined,
    });
  };

  // Group messages by date
  const groupedMessages: { date: string; messages: ChatMessage[] }[] = [];
  let currentDate = "";
  for (const msg of messages) {
    const msgDate = new Date(msg.created_at).toDateString();
    if (msgDate !== currentDate) {
      currentDate = msgDate;
      groupedMessages.push({ date: msg.created_at, messages: [msg] });
    } else {
      groupedMessages[groupedMessages.length - 1].messages.push(msg);
    }
  }

  if (loading) {
    return (
      <div className="flex h-[calc(100vh-64px)] items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-primary" />
      </div>
    );
  }

  const otherUser = conversation?.other_user;
  const roleColor = otherUser?.role
    ? ROLE_COLORS[otherUser.role] ?? "bg-gray-500"
    : "bg-gray-500";

  return (
    <div className="flex h-[calc(100vh-64px)] flex-col">
      {/* Header */}
      <div className="flex items-center gap-3 border-b border-gray-200 px-4 py-3">
        <Link
          href={`/${locale}/messages`}
          className="rounded-full p-1.5 text-gray-600 hover:bg-gray-100 transition-colors"
        >
          <ArrowLeft size={20} />
        </Link>
        <div className="flex items-center gap-3">
          {otherUser?.avatar_url ? (
            <Image
              src={otherUser.avatar_url}
              alt={otherUser.name}
              width={40}
              height={40}
              className="h-10 w-10 rounded-full object-cover"
              unoptimized
            />
          ) : (
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100">
              <User className="h-5 w-5 text-gray-400" />
            </div>
          )}
          <div>
            <p className="text-sm font-semibold text-gray-900">
              {otherUser?.name ?? "Unknown"}
            </p>
            {otherUser?.role && (
              <span className={`inline-block rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider text-white ${roleColor}`}>
                {otherUser.role}
              </span>
            )}
          </div>
        </div>
        {conversation && (
          <Link
            href={`/${locale}/orders/${conversation.order_id}`}
            className="ml-auto text-xs text-primary hover:underline"
          >
            {t("orderRef", { id: conversation.order_id.slice(0, 8) })}
          </Link>
        )}
      </div>

      {/* Messages */}
      <div
        ref={messagesContainerRef}
        className="flex-1 overflow-y-auto px-4 py-4"
      >
        {groupedMessages.map((group, gi) => (
          <div key={gi}>
            {/* Date separator */}
            <div className="flex items-center justify-center py-3">
              <span className="rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-500">
                {formatDateSeparator(group.date)}
              </span>
            </div>

            {/* Messages in this group */}
            {group.messages.map((msg) => {
              const isOwn = msg.sender_id === DEMO_CONSUMER_ID;
              return (
                <div
                  key={msg.id}
                  className={`mb-2 flex ${isOwn ? "justify-end" : "justify-start"}`}
                >
                  <div
                    className={`max-w-[75%] rounded-2xl px-4 py-2 ${
                      isOwn
                        ? "bg-primary text-white rounded-br-md"
                        : "bg-gray-100 text-gray-900 rounded-bl-md"
                    }`}
                  >
                    {msg.message_type === "image" ? (
                      <div className="overflow-hidden rounded-lg">
                        <Image
                          src={msg.content}
                          alt="Chat image"
                          width={280}
                          height={280}
                          className="max-h-64 w-auto rounded-lg object-cover"
                          unoptimized
                        />
                      </div>
                    ) : msg.message_type === "location" ? (
                      <div className="flex items-center gap-1">
                        <span>📍</span>
                        <span className="text-sm">{msg.content}</span>
                      </div>
                    ) : (
                      <p className="text-sm whitespace-pre-wrap break-words">{msg.content}</p>
                    )}
                    <div className={`mt-1 flex items-center gap-1 ${isOwn ? "justify-end" : "justify-start"}`}>
                      <span className={`text-[10px] ${isOwn ? "text-white/70" : "text-gray-400"}`}>
                        {formatMessageTime(msg.created_at)}
                      </span>
                      {isOwn && msg.read_at && (
                        <span className="text-[10px] text-white/70">✓</span>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Image preview */}
      {imagePreview && (
        <div className="border-t border-gray-200 px-4 py-2">
          <div className="relative inline-block">
            <Image
              src={imagePreview}
              alt="Preview"
              width={80}
              height={80}
              className="h-20 w-20 rounded-lg object-cover"
              unoptimized
            />
            <button
              onClick={clearImagePreview}
              className="absolute -top-2 -right-2 flex h-5 w-5 items-center justify-center rounded-full bg-gray-800 text-white"
            >
              <X size={12} />
            </button>
          </div>
        </div>
      )}

      {/* Input */}
      <div className="border-t border-gray-200 px-4 py-3">
        <div className="flex items-end gap-2">
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handleImageSelect}
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            className="flex-shrink-0 rounded-full p-2 text-gray-500 hover:bg-gray-100 hover:text-primary transition-colors"
            aria-label={t("sendImage")}
          >
            <ImagePlus size={20} />
          </button>
          <textarea
            ref={inputRef}
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={t("typeMessage")}
            rows={1}
            className="flex-1 resize-none rounded-2xl bg-gray-100 px-4 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary"
          />
          <button
            onClick={handleSend}
            disabled={sending || (!inputText.trim() && !imageFile)}
            className="flex-shrink-0 rounded-full bg-primary p-2.5 text-white transition-all hover:scale-105 hover:bg-blue-600 disabled:opacity-50 disabled:hover:scale-100"
            aria-label={t("send")}
          >
            {sending ? (
              <Loader2 size={18} className="animate-spin" />
            ) : (
              <Send size={18} />
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
