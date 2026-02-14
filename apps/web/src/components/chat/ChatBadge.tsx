"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { MessageCircle } from "lucide-react";
import { getTotalUnreadCount } from "@/lib/actions/chat";

interface ChatBadgeProps {
  locale: string;
}

export function ChatBadge({ locale }: ChatBadgeProps) {
  const t = useTranslations("chat");
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    let cancelled = false;

    async function fetchCount() {
      const result = await getTotalUnreadCount();
      if (!cancelled && result.data !== undefined) {
        setUnreadCount(result.data);
      }
    }

    const interval = setInterval(fetchCount, 30000);
    const immediate = setTimeout(fetchCount, 0);
    return () => {
      cancelled = true;
      clearInterval(interval);
      clearTimeout(immediate);
    };
  }, []);

  return (
    <Link
      href={`/${locale}/messages`}
      className="relative rounded-full p-2 text-gray-600 hover:bg-gray-100 hover:text-primary transition-colors"
      aria-label={t("title")}
    >
      <MessageCircle size={20} />
      {unreadCount > 0 && (
        <span className="absolute -top-0.5 -right-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-white">
          {unreadCount > 99 ? "99+" : unreadCount}
        </span>
      )}
    </Link>
  );
}
