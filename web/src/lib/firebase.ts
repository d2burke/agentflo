import { initializeApp, getApps } from 'firebase/app'
import { getMessaging, getToken, onMessage, type Messaging } from 'firebase/messaging'
import { createClient } from '@/lib/supabase/client'

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

function getFirebaseApp() {
  if (getApps().length === 0) {
    return initializeApp(firebaseConfig)
  }
  return getApps()[0]
}

let messagingInstance: Messaging | null = null

function getMessagingInstance(): Messaging | null {
  if (typeof window === 'undefined') return null
  if (!firebaseConfig.apiKey) return null
  if (messagingInstance) return messagingInstance

  try {
    const app = getFirebaseApp()
    messagingInstance = getMessaging(app)
    return messagingInstance
  } catch {
    console.warn('[firebase] Failed to initialize messaging')
    return null
  }
}

/**
 * Request push permission and register the FCM token with our backend.
 * Returns the token string if successful, null otherwise.
 */
export async function requestPushPermissionAndRegister(): Promise<string | null> {
  const messaging = getMessagingInstance()
  if (!messaging) return null

  try {
    const permission = await Notification.requestPermission()
    if (permission !== 'granted') return null

    const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY
    if (!vapidKey) {
      console.warn('[firebase] Missing VAPID key')
      return null
    }

    const token = await getToken(messaging, {
      vapidKey,
      serviceWorkerRegistration: await navigator.serviceWorker.register('/firebase-messaging-sw.js'),
    })

    if (token) {
      await registerTokenWithBackend(token)
    }

    return token
  } catch (err) {
    console.error('[firebase] Failed to get push token:', err)
    return null
  }
}

async function registerTokenWithBackend(token: string) {
  const supabase = createClient()

  // Refresh the session first to ensure a valid JWT
  await supabase.auth.refreshSession()

  const { error } = await supabase.functions.invoke('register-push-token', {
    body: { token, platform: 'web' },
  })
  if (error) {
    console.error('[firebase] Failed to register token:', error)
  }
}

/**
 * Listen for foreground messages. Returns an unsubscribe function.
 */
export function onForegroundMessage(callback: (payload: { title?: string; body?: string; data?: Record<string, string> }) => void): (() => void) | null {
  const messaging = getMessagingInstance()
  if (!messaging) return null

  return onMessage(messaging, (payload) => {
    callback({
      title: payload.notification?.title,
      body: payload.notification?.body,
      data: payload.data,
    })
  })
}

/**
 * Check current push notification permission state.
 */
export function getPushPermissionState(): NotificationPermission | 'unsupported' {
  if (typeof window === 'undefined') return 'unsupported'
  if (!('Notification' in window)) return 'unsupported'
  return Notification.permission
}

// Cooldown for "Not Now" dismissal (7 days)
const PUSH_PROMPT_KEY = 'lastPushPromptDate'
const PROMPT_COOLDOWN_DAYS = 7

export function shouldShowPushPrompt(): boolean {
  const permission = getPushPermissionState()
  if (permission !== 'default') return false

  const lastPrompt = localStorage.getItem(PUSH_PROMPT_KEY)
  if (lastPrompt) {
    const daysSince = (Date.now() - new Date(lastPrompt).getTime()) / (1000 * 60 * 60 * 24)
    if (daysSince < PROMPT_COOLDOWN_DAYS) return false
  }

  return true
}

export function recordPushPromptDismissal() {
  localStorage.setItem(PUSH_PROMPT_KEY, new Date().toISOString())
}
