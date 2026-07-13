// Service worker for Firebase Cloud Messaging background messages.
// This file must stay at the web root (web/firebase-messaging-sw.js).
// TODO: Keep the Firebase version here in sync with what firebase_messaging pulls in.

importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAanZm_QOvu_Vede6g_sjRAr-dqaImv3z0",
  authDomain: "emvnzir-canada-song.firebaseapp.com",
  projectId: "emvnzir-canada-song",
  storageBucket: "emvnzir-canada-song.firebasestorage.app",
  messagingSenderId: "483471568825",
  appId: "1:483471568825:web:a3e01d8d5d2ead83d59068",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? "New notification";
  const options = {
    body: payload.notification?.body,
    icon: "/icons/Icon-192.png",
  };
  return self.registration.showNotification(title, options);
});
