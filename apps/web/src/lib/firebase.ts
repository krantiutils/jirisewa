"use client";

import { initializeApp, getApps, type FirebaseApp } from "firebase/app";
import { getMessaging, getToken, onMessage, type Messaging } from "firebase/messaging";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

let app: FirebaseApp | null = null;
let messaging: Messaging | null = null;

function getFirebaseApp(): FirebaseApp | null {
  if (typeof window === "undefined") return null;
  if (!firebaseConfig.apiKey) return null;

  if (!app) {
    app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
  }
  return app;
}

function getFirebaseMessaging(): Messaging | null {
  if (typeof window === "undefined") return null;

  const firebaseApp = getFirebaseApp();
  if (!firebaseApp) return null;

  if (!messaging) {
    try {
      messaging = getMessaging(firebaseApp);
    } catch (err) {
      console.error("Failed to initialize Firebase Messaging:", err);
      return null;
    }
  }
  return messaging;
}

/**
 * Request notification permission and get FCM token.
 * Returns null if permission denied or messaging unavailable.
 */
export async function requestFcmToken(): Promise<string | null> {
  const msg = getFirebaseMessaging();
  if (!msg) return null;

  const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
  if (!vapidKey) {
    console.error("NEXT_PUBLIC_FIREBASE_VAPID_KEY not configured");
    return null;
  }

  try {
    const permission = await Notification.requestPermission();
    if (permission !== "granted") {
      return null;
    }

    const token = await getToken(msg, { vapidKey });
    return token;
  } catch (err) {
    console.error("Failed to get FCM token:", err);
    return null;
  }
}

/**
 * Listen for foreground push messages.
 * Returns an unsubscribe function.
 */
export function onForegroundMessage(
  callback: (payload: { title?: string; body?: string; data?: Record<string, string> }) => void,
): (() => void) | null {
  const msg = getFirebaseMessaging();
  if (!msg) return null;

  return onMessage(msg, (payload) => {
    callback({
      title: payload.notification?.title,
      body: payload.notification?.body,
      data: payload.data,
    });
  });
}
