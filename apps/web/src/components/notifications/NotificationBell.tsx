"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useLocale, useTranslations } from "next-intl";
import { getUnreadCount, listNotifications, markNotificationRead, markAllNotificationsRead } from "@/lib/actions/notifications";

interface NotificationItem {
  id: string;
  category: string;
  title_en: string;
  title_ne: string;
  body_en: string;
  body_ne: string;
  data: Record<string, unknown>;
  read: boolean;
  created_at: string;
}

export function NotificationBell() {
  const locale = useLocale();
  const t = useTranslations("notifications");
  const [unreadCount, setUnreadCount] = useState(0);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const fetchUnreadCount = useCallback(async () => {
    const result = await getUnreadCount();
    if (result.data !== undefined) {
      setUnreadCount(result.data);
    }
  }, []);

  useEffect(() => {
    fetchUnreadCount();
    // Poll for new notifications every 30 seconds
    const interval = setInterval(fetchUnreadCount, 30000);
    return () => clearInterval(interval);
  }, [fetchUnreadCount]);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleOpen = async () => {
    const opening = !isOpen;
    setIsOpen(opening);
    if (opening) {
      setLoading(true);
      const result = await listNotifications(20, 0);
      if (result.data) {
        setNotifications(result.data);
      }
      setLoading(false);
    }
  };

  const handleMarkRead = async (id: string) => {
    await markNotificationRead(id);
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, read: true } : n)),
    );
    setUnreadCount((prev) => Math.max(0, prev - 1));
  };

  const handleMarkAllRead = async () => {
    await markAllNotificationsRead();
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    setUnreadCount(0);
  };

  const formatTime = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);

    if (diffMins < 1) return locale === "ne" ? "अहिले" : "Just now";
    if (diffMins < 60) return locale === "ne" ? `${diffMins} मिनेट अगाडि` : `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return locale === "ne" ? `${diffHours} घण्टा अगाडि` : `${diffHours}h ago`;
    const diffDays = Math.floor(diffHours / 24);
    return locale === "ne" ? `${diffDays} दिन अगाडि` : `${diffDays}d ago`;
  };

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        onClick={handleOpen}
        className="relative rounded-full p-2 text-gray-600 hover:bg-gray-100 hover:text-primary transition-colors"
        aria-label={t("title")}
      >
        {/* Bell SVG icon */}
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
          <path d="M13.73 21a2 2 0 0 1-3.46 0" />
        </svg>
        {unreadCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-[10px] font-bold text-white">
            {unreadCount > 99 ? "99+" : unreadCount}
          </span>
        )}
      </button>

      {isOpen && (
        <div className="absolute right-0 top-full z-50 mt-2 w-80 rounded-lg border border-gray-200 bg-white shadow-lg sm:w-96">
          <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
            <h3 className="text-sm font-semibold text-gray-900">
              {t("title")}
            </h3>
            {unreadCount > 0 && (
              <button
                onClick={handleMarkAllRead}
                className="text-xs text-primary hover:underline"
              >
                {t("markAllRead")}
              </button>
            )}
          </div>

          <div className="max-h-96 overflow-y-auto">
            {loading ? (
              <div className="flex items-center justify-center py-8">
                <div className="h-5 w-5 animate-spin rounded-full border-2 border-gray-300 border-t-primary" />
              </div>
            ) : notifications.length === 0 ? (
              <div className="px-4 py-8 text-center text-sm text-gray-500">
                {t("empty")}
              </div>
            ) : (
              notifications.map((notif) => (
                <button
                  key={notif.id}
                  onClick={() => {
                    if (!notif.read) handleMarkRead(notif.id);
                    // Navigate if URL is present in data
                    const url = notif.data?.url as string | undefined;
                    if (url) {
                      window.location.href = `/${locale}${url}`;
                    }
                  }}
                  className={`block w-full border-b border-gray-50 px-4 py-3 text-left transition-colors hover:bg-gray-50 ${
                    !notif.read ? "bg-blue-50/50" : ""
                  }`}
                >
                  <div className="flex items-start gap-3">
                    {!notif.read && (
                      <span className="mt-1.5 h-2 w-2 flex-shrink-0 rounded-full bg-primary" />
                    )}
                    <div className={!notif.read ? "" : "pl-5"}>
                      <p className="text-sm font-medium text-gray-900">
                        {locale === "ne" ? notif.title_ne : notif.title_en}
                      </p>
                      <p className="mt-0.5 text-xs text-gray-600">
                        {locale === "ne" ? notif.body_ne : notif.body_en}
                      </p>
                      <p className="mt-1 text-[10px] text-gray-400">
                        {formatTime(notif.created_at)}
                      </p>
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
