"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { MessageCircle, Loader2, User } from "lucide-react";
import { listConversations } from "@/lib/actions/chat";
import type { ChatConversation } from "@/lib/types/chat";

const ROLE_COLORS: Record<string, string> = {
  consumer: "bg-blue-100 text-blue-700",
  farmer: "bg-emerald-100 text-emerald-700",
  rider: "bg-amber-100 text-amber-700",
};

export default function MessagesPage() {
  const { locale } = useParams<{ locale: string }>();
  const router = useRouter();
  const t = useTranslations("chat");

  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authChecked, setAuthChecked] = useState(false);
  const [conversations, setConversations] = useState<ChatConversation[]>([]);
  const [loading, setLoading] = useState(true);

  // Check auth first
  useEffect(() => {
    async function checkAuth() {
      try {
        const res = await fetch("/api/auth/session");
        if (!res.ok || !(await res.json()).user) {
          router.replace(`/${locale}/auth/login`);
          return;
        }
        setIsAuthenticated(true);
      } catch {
        router.replace(`/${locale}/auth/login`);
        return;
      } finally {
        setAuthChecked(true);
      }
    }
    checkAuth();
  }, [locale, router]);

  useEffect(() => {
    if (!authChecked || !isAuthenticated) return;

    async function load() {
      const result = await listConversations();
      if (result.data) {
        setConversations(result.data);
      }
      setLoading(false);
    }
    load();
  }, [authChecked, isAuthenticated]);

  // Don't render until auth is checked
  if (!authChecked) {
    return null;
  }

  // Show loading state while checking auth
  if (!isAuthenticated) {
    return (
      <main className="mx-auto max-w-2xl px-4 py-8 min-h-screen flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-500">Please log in to view your messages...</p>
        </div>
      </main>
    );
  }

  const formatTime = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);

    if (diffMins < 1) return locale === "ne" ? "अहिले" : "Now";
    if (diffMins < 60) return `${diffMins}m`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h`;
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 7) return `${diffDays}d`;
    return date.toLocaleDateString(locale === "ne" ? "ne-NP" : "en-US", {
      month: "short",
      day: "numeric",
    });
  };

  const getPreviewText = (conv: ChatConversation) => {
    if (!conv.last_message) return "";
    if (conv.last_message.message_type === "image") return `📷 ${t("image")}`;
    if (conv.last_message.message_type === "location") return `📍 ${t("location")}`;
    return conv.last_message.content;
  };

  return (
    <main className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">{t("title")}</h1>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <Loader2 className="h-6 w-6 animate-spin text-primary" />
        </div>
      ) : conversations.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 mb-4">
            <MessageCircle className="h-8 w-8 text-gray-400" />
          </div>
          <p className="text-lg font-medium text-gray-900">{t("noConversations")}</p>
          <p className="mt-1 text-sm text-gray-500">{t("noConversationsHint")}</p>
        </div>
      ) : (
        <div className="divide-y divide-gray-100">
          {conversations.map((conv) => (
            <Link
              key={conv.id}
              href={`/${locale}/messages/${conv.id}`}
              className="flex items-center gap-3 px-3 py-4 transition-colors hover:bg-gray-50 rounded-lg"
            >
              {/* Avatar(s) - show stacked for 3-way chat */}
              <div className="relative flex-shrink-0">
                {/* Check for 3-way chat */}
                {conv.participants && conv.participants.length > 1 ? (
                  <div className="flex -space-x-2">
                    {conv.participants.slice(0, 3).map((participant, idx) => (
                      participant.avatar_url ? (
                        <Image
                          key={participant.id}
                          src={participant.avatar_url}
                          alt={participant.name}
                          width={48}
                          height={48}
                          className="h-12 w-12 rounded-full object-cover border-2 border-white"
                          unoptimized
                        />
                      ) : (
                        <div
                          key={participant.id}
                          className="flex h-12 w-12 items-center justify-center rounded-full bg-gray-100 border-2 border-white"
                        >
                          <User className="h-6 w-6 text-gray-400" />
                        </div>
                      )
                    ))}
                  </div>
                ) : conv.other_user?.avatar_url ? (
                  <Image
                    src={conv.other_user.avatar_url}
                    alt={conv.other_user.name}
                    width={48}
                    height={48}
                    className="h-12 w-12 rounded-full object-cover"
                    unoptimized
                  />
                ) : (
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-gray-100">
                    <User className="h-6 w-6 text-gray-400" />
                  </div>
                )}
                {conv.unread_count > 0 && (
                  <span className="absolute -top-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-white">
                    {conv.unread_count > 9 ? "9+" : conv.unread_count}
                  </span>
                )}
              </div>

              {/* Content */}
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className={`truncate text-sm font-semibold ${conv.unread_count > 0 ? "text-gray-900" : "text-gray-700"}`}>
                      {conv.participants && conv.participants.length > 1
                        ? conv.participants.map((p) => p.name).join(", ")
                        : (conv.other_user?.name ?? "Unknown")}
                    </span>
                    {/* Show role badges for multi-participant chats */}
                    {conv.participants && conv.participants.length > 1
                      ? conv.participants.slice(0, 2).map((participant) => (
                          <span
                            key={participant.id}
                            className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider ${ROLE_COLORS[participant.role] ?? "bg-gray-100 text-gray-600"}`}
                          >
                            {participant.role}
                          </span>
                        ))
                      : conv.other_user?.role && (
                          <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider ${ROLE_COLORS[conv.other_user.role] ?? "bg-gray-100 text-gray-600"}`}>
                            {conv.other_user.role}
                          </span>
                        )}
                  </div>
                  <span className="flex-shrink-0 text-xs text-gray-400">
                    {conv.last_message
                      ? formatTime(conv.last_message.created_at)
                      : formatTime(conv.created_at)}
                  </span>
                </div>
                <div className="flex items-center justify-between gap-2 mt-0.5">
                  <p className={`truncate text-sm ${conv.unread_count > 0 ? "font-medium text-gray-900" : "text-gray-500"}`}>
                    {getPreviewText(conv) || t("orderRef", { id: conv.order_id.slice(0, 8) })}
                  </p>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}
