// supabase/functions/send-notification/index.ts
// Edge Function: Central notification dispatcher
//
// Called by other edge functions (not directly by clients).
// Uses service role key for cross-user operations.
//
// Business Logic:
//   1. Resolve notification template from type (e.g., 'task_accepted' → title + body template)
//   2. Check recipient's notification_preferences — skip if disabled for this type
//   3. Insert notification record into notifications table
//   4. Look up recipient's push_tokens (active ones)
//   5. Send push notification via FCM (Android/Web) or APNs (iOS)
//   6. Update push_sent_at on the notification record
//
// Input: { userId: string, type: string, data: { task_id?, screen?, ... }, customTitle?: string, customBody?: string }
// Output: { notification_id: string, push_sent: boolean }
//
// NOTE: This function is internal — called by other edge functions, not exposed to clients.
// It uses SUPABASE_SERVICE_ROLE_KEY to bypass RLS for cross-user notification insertion.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Notification templates — move to DB/config in Iteration 3
const TEMPLATES: Record<string, { title: string; body: string }> = {
  task_accepted:       { title: 'You Got the Task!',       body: '{agent_name} accepted your application for {category} at {address}' },
  task_application:    { title: 'New Application',          body: '{runner_name} applied for your {category} task at {address}' },
  deliverables_ready:  { title: 'Deliverables Ready',       body: '{runner_name} submitted deliverables for {address}' },
  task_completed:      { title: 'Task Completed',           body: '{category} at {address} is complete. Payment of ${amount} processed.' },
  payment_received:    { title: 'Payment Received!',        body: '${amount} has been deposited for {category} at {address}' },
  new_task_nearby:     { title: 'New Task Nearby',          body: '{category} task posted {distance} away — ${price}' },
  task_cancelled:      { title: 'Task Cancelled',           body: '{category} at {address} has been cancelled. {reason}' },
  revision_requested:  { title: 'Revision Requested',       body: '{agent_name} requested changes to your deliverables for {address}' },
  review_prompt:       { title: 'How Did It Go?',           body: 'Rate your experience with {other_name} for {category} at {address}' },
  vetting_approved:    { title: 'Account Approved!',         body: 'Your account has been verified. You can now {action} on Agent Flo.' },
  vetting_rejected:    { title: 'Verification Update',       body: 'Your verification needs attention. {reason}' },
}

// Maps notification type → notification_preferences column
const PREF_MAP: Record<string, string> = {
  task_accepted: 'task_updates',
  task_application: 'task_updates',
  deliverables_ready: 'task_updates',
  task_completed: 'task_updates',
  payment_received: 'payment_confirmations',
  new_task_nearby: 'new_available_tasks',
  task_cancelled: 'task_updates',
  revision_requested: 'task_updates',
  review_prompt: 'task_updates',
  vetting_approved: 'task_updates',
  vetting_rejected: 'task_updates',
}

function resolveTemplate(
  type: string,
  data: Record<string, string>,
  customTitle?: string,
  customBody?: string,
): { title: string; body: string } {
  const template = TEMPLATES[type]
  if (!template && !customTitle) {
    return { title: 'Notification', body: '' }
  }

  let title = customTitle ?? template.title
  let body = customBody ?? template.body

  // Replace placeholders like {agent_name}, {address}, etc.
  for (const [key, value] of Object.entries(data)) {
    title = title.replace(`{${key}}`, value ?? '')
    body = body.replace(`{${key}}`, value ?? '')
    // Handle ${amount} and ${price} patterns (dollar sign prefix)
    title = title.replace(`\${${key}}`, value ?? '')
    body = body.replace(`\${${key}}`, value ?? '')
  }

  return { title, body }
}

// Get FCM OAuth2 access token from Google service account
async function getFcmAccessToken(serviceAccount: {
  client_email: string
  private_key: string
  token_uri: string
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = btoa(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: serviceAccount.token_uri,
      iat: now,
      exp: now + 3600,
    }),
  )

  // Sign JWT with RS256
  const encoder = new TextEncoder()
  const signingInput = `${header}.${payload}`

  // Import private key
  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '')
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(signingInput),
  )

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')

  const jwt = `${header}.${payload}.${sig}`

  // Exchange JWT for access token
  const tokenRes = await fetch(serviceAccount.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const tokenData = await tokenRes.json()
  return tokenData.access_token
}

serve(async (req) => {
  try {
    const { userId, type, data, customTitle, customBody } = await req.json()

    if (!userId || !type) {
      return new Response(
        JSON.stringify({ error: 'userId and type are required' }),
        { status: 400 },
      )
    }

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Check notification preferences
    const prefColumn = PREF_MAP[type]
    if (prefColumn) {
      const { data: prefs } = await serviceClient
        .from('notification_preferences')
        .select(prefColumn)
        .eq('user_id', userId)
        .single()

      if (prefs && prefs[prefColumn] === false) {
        return new Response(
          JSON.stringify({ notification_id: null, push_sent: false, skipped: 'disabled_by_preference' }),
          { headers: { 'Content-Type': 'application/json' } },
        )
      }
    }

    // Resolve template
    const { title, body } = resolveTemplate(type, data ?? {}, customTitle, customBody)

    // Insert notification record
    const { data: notification, error: insertError } = await serviceClient
      .from('notifications')
      .insert({
        user_id: userId,
        type,
        title,
        body,
        data: data ?? {},
      })
      .select('id')
      .single()

    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), { status: 500 })
    }

    // Look up active push tokens
    const { data: tokens } = await serviceClient
      .from('push_tokens')
      .select('token, platform')
      .eq('user_id', userId)
      .eq('is_active', true)

    let pushSent = false

    if (tokens && tokens.length > 0) {
      const fcmServiceAccount = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')

      if (fcmServiceAccount) {
        try {
          const sa = JSON.parse(fcmServiceAccount)
          const accessToken = await getFcmAccessToken(sa)
          const projectId = sa.project_id

          for (const { token, platform } of tokens) {
            try {
              const message: Record<string, unknown> = {
                token,
                notification: { title, body },
                data: { type, ...(data ?? {}) },
              }

              // Platform-specific config
              if (platform === 'ios') {
                message.apns = {
                  payload: { aps: { sound: 'default', badge: 1 } },
                }
              } else if (platform === 'web') {
                message.webpush = {
                  notification: { icon: '/icon-192.png' },
                }
              }

              const res = await fetch(
                `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
                {
                  method: 'POST',
                  headers: {
                    Authorization: `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                  },
                  body: JSON.stringify({ message }),
                },
              )

              if (res.ok) {
                pushSent = true
              } else {
                const errBody = await res.json()
                const errorCode = errBody?.error?.details?.[0]?.errorCode
                // Token is no longer valid — deactivate it
                if (errorCode === 'UNREGISTERED' || res.status === 404) {
                  await serviceClient
                    .from('push_tokens')
                    .update({ is_active: false })
                    .eq('token', token)
                  console.log(`[send-notification] Deactivated stale token for user ${userId}`)
                } else {
                  console.error(`[send-notification] FCM error for user ${userId}:`, errBody)
                }
              }
            } catch (tokenErr) {
              console.error(`[send-notification] Failed to send to token:`, tokenErr)
            }
          }
        } catch (fcmErr) {
          console.error(`[send-notification] FCM setup error:`, fcmErr)
        }
      } else {
        console.log(`[send-notification] FCM not configured — would send push to ${tokens.length} device(s) for user ${userId}: ${title}`)
      }

      if (pushSent) {
        await serviceClient
          .from('notifications')
          .update({ push_sent_at: new Date().toISOString() })
          .eq('id', notification.id)
      }
    }

    return new Response(
      JSON.stringify({ notification_id: notification.id, push_sent: pushSent }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
