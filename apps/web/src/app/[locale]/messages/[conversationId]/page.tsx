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
  Mic,
  Square,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { useAuth } from "@/components/AuthProvider";
import {
  getConversationDetails,
  getMessages,
  sendMessage,
  markConversationRead,
  uploadChatImage,
  uploadChatAudio,
} from "@/lib/actions/chat";
import type { ChatConversation, ChatMessage } from "@/lib/types/chat";

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
  const { user } = useAuth();
  const currentUserId = user?.id ?? "";

  const [conversation, setConversation] = useState<ChatConversation | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [inputText, setInputText] = useState("");
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [recording, setRecording] = useState(false);
  const [recordingDuration, setRecordingDuration] = useState(0);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const recordingTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const streamRef = useRef<MediaStream | null>(null);

  // Auto-scroll to latest message
  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, []);

  // Load conversation and messages
  useEffect(() => {
    if (!currentUserId) return;
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
  }, [conversationId, currentUserId]);

  // Scroll to bottom when messages change
  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  // Subscribe to realtime new messages
  useEffect(() => {
    if (!currentUserId) return;
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
          if (newMsg.sender_id !== currentUserId) {
            markConversationRead(conversationId);
          }
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [conversationId, currentUserId]);

  const handleSend = async () => {
    const text = inputText.trim();
    if (!text && !imageFile) return;

    setSending(true);
    setError(null);

    try {
      if (imageFile) {
        const formData = new FormData();
        formData.append("file", imageFile);
        const uploadResult = await uploadChatImage(formData);
        if (uploadResult.error) {
          setError(uploadResult.error);
          setSending(false);
          return;
        }
        if (uploadResult.data) {
          const sendResult = await sendMessage(conversationId, uploadResult.data.url, "image");
          if (sendResult.error) {
            setError(sendResult.error);
            setSending(false);
            return;
          }
          if (sendResult.data) {
            setMessages((prev) => {
              if (prev.some((m) => m.id === sendResult.data!.id)) return prev;
              return [...prev, sendResult.data!];
            });
          }
        }
        setImageFile(null);
        setImagePreview(null);
      }

      if (text) {
        const sendResult = await sendMessage(conversationId, text, "text");
        if (sendResult.error) {
          setError(sendResult.error);
        } else {
          if (sendResult.data) {
            setMessages((prev) => {
              if (prev.some((m) => m.id === sendResult.data!.id)) return prev;
              return [...prev, sendResult.data!];
            });
          }
          setInputText("");
        }
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
      setError("File too large (max 5MB)");
      return;
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

  const startRecording = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      const recorder = new MediaRecorder(stream);
      mediaRecorderRef.current = recorder;
      audioChunksRef.current = [];

      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) audioChunksRef.current.push(e.data);
      };

      recorder.onstop = async () => {
        // Stop all tracks
        streamRef.current?.getTracks().forEach((t) => t.stop());
        streamRef.current = null;

        // Clear timer
        if (recordingTimerRef.current) {
          clearInterval(recordingTimerRef.current);
          recordingTimerRef.current = null;
        }

        const blob = new Blob(audioChunksRef.current, { type: "audio/webm" });
        audioChunksRef.current = [];

        if (blob.size === 0) {
          setRecording(false);
          setRecordingDuration(0);
          return;
        }

        setSending(true);
        setError(null);

        const file = new File([blob], `voice-${Date.now()}.webm`, {
          type: "audio/webm",
        });
        const formData = new FormData();
        formData.append("file", file);

        const uploadResult = await uploadChatAudio(formData);
        if (uploadResult.error) {
          setError(uploadResult.error);
          setSending(false);
          setRecording(false);
          setRecordingDuration(0);
          return;
        }

        if (uploadResult.data) {
          const sendResult = await sendMessage(
            conversationId,
            uploadResult.data.url,
            "audio",
          );
          if (sendResult.error) {
            setError(sendResult.error);
          } else if (sendResult.data) {
            setMessages((prev) => {
              if (prev.some((m) => m.id === sendResult.data!.id)) return prev;
              return [...prev, sendResult.data!];
            });
          }
        }

        setSending(false);
        setRecording(false);
        setRecordingDuration(0);
      };

      recorder.start();
      setRecording(true);
      setRecordingDuration(0);
      recordingTimerRef.current = setInterval(() => {
        setRecordingDuration((d) => d + 1);
      }, 1000);
    } catch {
      setError("Microphone access denied");
    }
  }, [conversationId]);

  const stopRecording = useCallback(() => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== "inactive") {
      mediaRecorderRef.current.stop();
    }
  }, []);

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

  // Check if this is a 3-way chat
  const isGroupChat = conversation?.participants && conversation.participants.length > 1;

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
          {/* Avatar(s) - show stacked for 3-way chat */}
          {isGroupChat ? (
            <div className="flex -space-x-2">
              {conversation.participants!.slice(0, 3).map((participant) => (
                participant.avatar_url ? (
                  <Image
                    key={participant.id}
                    src={participant.avatar_url}
                    alt={participant.name}
                    width={40}
                    height={40}
                    className="h-10 w-10 rounded-full object-cover border-2 border-white"
                    unoptimized
                  />
                ) : (
                  <div
                    key={participant.id}
                    className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100 border-2 border-white"
                  >
                    <User className="h-5 w-5 text-gray-400" />
                  </div>
                )
              ))}
            </div>
          ) : otherUser?.avatar_url ? (
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
              {isGroupChat
                ? conversation.participants!.map((p) => p.name).join(", ")
                : (otherUser?.name ?? "Unknown")}
            </p>
            <div className="flex items-center gap-1">
              {isGroupChat
                ? conversation.participants!.slice(0, 3).map((participant) => (
                    <span
                      key={participant.id}
                      className={`inline-block rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider text-white ${
                        ROLE_COLORS[participant.role] ?? "bg-gray-500"
                      }`}
                    >
                      {participant.role}
                    </span>
                  ))
                : otherUser?.role && (
                    <span className={`inline-block rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider text-white ${roleColor}`}>
                      {otherUser.role}
                    </span>
                  )}
            </div>
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
              const isOwn = msg.sender_id === currentUserId;
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
                    ) : msg.message_type === "audio" ? (
                      <div className="flex items-center gap-2">
                        <Mic size={14} className={isOwn ? "text-white/70" : "text-gray-400"} />
                        <audio
                          controls
                          preload="metadata"
                          className="h-8 max-w-[220px]"
                          src={msg.content}
                        />
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

      {/* Error message */}
      {error && (
        <div className="border-t border-gray-200 px-4 py-2">
          <p className="text-sm text-red-600">{error}</p>
        </div>
      )}

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
        {recording ? (
          <div className="flex items-center gap-3">
            <div className="flex flex-1 items-center gap-3 rounded-2xl bg-red-50 px-4 py-2.5">
              <span className="h-2.5 w-2.5 animate-pulse rounded-full bg-red-500" />
              <span className="text-sm font-medium text-red-600">
                {t("recording")}
              </span>
              <span className="text-sm tabular-nums text-red-500">
                {Math.floor(recordingDuration / 60)}:{String(recordingDuration % 60).padStart(2, "0")}
              </span>
            </div>
            <button
              onClick={stopRecording}
              className="flex-shrink-0 rounded-full bg-red-500 p-2.5 text-white transition-all hover:scale-105 hover:bg-red-600"
              aria-label={t("stopRecording")}
            >
              <Square size={18} fill="currentColor" />
            </button>
          </div>
        ) : (
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
              disabled={sending}
            >
              <ImagePlus size={20} />
            </button>
            <button
              onClick={startRecording}
              className="flex-shrink-0 rounded-full p-2 text-gray-500 hover:bg-gray-100 hover:text-red-500 transition-colors"
              aria-label={t("recordVoice")}
              disabled={sending}
            >
              <Mic size={20} />
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
        )}
      </div>
    </div>
  );
}
