"use client";

import { useEffect, useRef } from "react";
import { useAuth } from "@/components/AuthProvider";
import { requestFcmToken, onForegroundMessage } from "@/lib/firebase";
import { registerDeviceToken } from "@/lib/actions/notifications";

/**
 * Manages FCM push notification registration for the current user.
 * Requests permission, registers the device token, and handles foreground messages.
 * Renders nothing — this is a side-effect-only component.
 */
export function PushNotificationManager() {
  const { user } = useAuth();
  const registeredRef = useRef(false);

  useEffect(() => {
    if (!user || registeredRef.current) return;

    async function setupPush() {
      const token = await requestFcmToken();
      if (!token) return;

      const result = await registerDeviceToken(token, "web");
      if (result.error) {
        console.error("Failed to register push token:", result.error);
        return;
      }

      registeredRef.current = true;
    }

    setupPush();
  }, [user]);

  // Listen for foreground messages and show browser notifications
  useEffect(() => {
    const unsubscribe = onForegroundMessage((payload) => {
      if (payload.title && Notification.permission === "granted") {
        new Notification(payload.title, {
          body: payload.body,
          icon: "/icon-192x192.png",
        });
      }
    });

    return () => {
      if (unsubscribe) unsubscribe();
    };
  }, []);

  return null;
}
