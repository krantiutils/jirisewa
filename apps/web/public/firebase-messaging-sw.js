// Firebase Cloud Messaging service worker for background push notifications.
// This file MUST be at the root of the public directory for FCM to discover it.

importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

// Firebase config is injected at build time or via query params.
// For security, only public keys are used here.
firebase.initializeApp({
  apiKey: self.__FIREBASE_CONFIG__?.apiKey ?? "",
  authDomain: self.__FIREBASE_CONFIG__?.authDomain ?? "",
  projectId: self.__FIREBASE_CONFIG__?.projectId ?? "",
  storageBucket: self.__FIREBASE_CONFIG__?.storageBucket ?? "",
  messagingSenderId: self.__FIREBASE_CONFIG__?.messagingSenderId ?? "",
  appId: self.__FIREBASE_CONFIG__?.appId ?? "",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title ?? "JiriSewa";
  const notificationOptions = {
    body: payload.notification?.body ?? "",
    icon: "/icon-192x192.png",
    badge: "/icon-72x72.png",
    data: payload.data,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click — open the app or focus existing tab
self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const urlToOpen = event.notification.data?.url ?? "/";

  event.waitUntil(
    self.clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (client.url.includes(self.location.origin) && "focus" in client) {
            return client.focus();
          }
        }
        return self.clients.openWindow(urlToOpen);
      }),
  );
});
