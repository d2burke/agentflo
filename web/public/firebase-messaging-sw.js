/* eslint-disable no-undef */
// Firebase Messaging Service Worker
// Handles background push notifications when the app tab is not active.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js')
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js')

firebase.initializeApp({
  apiKey: 'AIzaSyA0QeMmJurayPJ-_mdjpzHAew9NT_IxIEc',
  authDomain: 'agentflo-4822e.firebaseapp.com',
  projectId: 'agentflo-4822e',
  storageBucket: 'agentflo-4822e.firebasestorage.app',
  messagingSenderId: '684953215923',
  appId: '1:684953215923:web:701958fea32d56a05e61c6',
})

const messaging = firebase.messaging()

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {}
  const data = payload.data ?? {}

  self.registration.showNotification(title ?? 'Agent Flo', {
    body: body ?? '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    data,
  })
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const data = event.notification.data ?? {}
  let url = '/'

  // Route based on notification type
  if (data.task_id) {
    url = `/tasks/${data.task_id}`
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Focus existing tab if available
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.focus()
          client.navigate(url)
          return
        }
      }
      // Otherwise open a new tab
      return clients.openWindow(url)
    }),
  )
})
