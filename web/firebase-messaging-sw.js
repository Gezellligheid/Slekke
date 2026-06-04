importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDK1xi00zf3Hl0n9k_juF7rexAxFs83BXk',
  appId: '1:224585099790:web:183dcd4e013833831c6a5f',
  messagingSenderId: '224585099790',
  projectId: 'slekke-5f041',
  authDomain: 'slekke-5f041.firebaseapp.com',
  storageBucket: 'slekke-5f041.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages (app tab closed or not focused)
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'Slekke';
  const body  = payload.notification?.body  ?? '';
  return self.registration.showNotification(title, {
    body,
    icon:  '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data:  payload.data ?? {},
    tag:   payload.data?.channelId ?? payload.data?.dmId ?? 'slekke',
    renotify: true,
  });
});

// Clicking the notification opens / focuses the app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      if (list.length > 0) return list[0].focus();
      return clients.openWindow('/');
    })
  );
});
