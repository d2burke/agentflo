import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getCorsHeaders, handleCorsPreFlight } from '../_shared/cors.ts'
import { isValidUUID } from '../_shared/validation.ts'

type NotificationJobRow = {
  id: string
  message_id: string
  conversation_id: string
  sender_id: string
  recipient_id: string
  status: 'pending' | 'processing' | 'sent' | 'skipped' | 'failed'
  attempts: number
  notification_id?: string | null
}

type MessageRow = {
  id: string
  body: string | null
  task_id: string | null
  message_type: 'text' | 'image' | 'file' | 'system'
  deleted_at: string | null
}

type NotificationRow = {
  id: string
  title: string
  body: string
  data: Record<string, string> | null
}

type PushTokenRow = {
  token: string
  platform: 'ios' | 'android' | 'web'
}

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

  const encoder = new TextEncoder()
  const signingInput = `${header}.${payload}`
  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '')
  const binaryKey = Uint8Array.from(atob(pemContents), (char) => char.charCodeAt(0))

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

  const signed = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')

  const jwt = `${header}.${payload}.${signed}`

  const tokenResponse = await fetch(serviceAccount.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

function buildPreview(message: MessageRow) {
  if (message.deleted_at) return '[deleted]'

  const trimmed = (message.body ?? '').trim()
  if (trimmed.length > 0) {
    return trimmed.length > 100 ? `${trimmed.slice(0, 97)}...` : trimmed
  }

  if (message.message_type === 'image') return 'Sent an image'
  if (message.message_type === 'file') return 'Sent a file'

  return 'New message'
}

serve(async (req) => {
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse

  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const authorization = req.headers.get('Authorization') ?? ''
    const internalServiceKey = req.headers.get('x-internal-service-key') ?? ''
    const bearerToken = authorization.startsWith('Bearer ')
      ? authorization.slice('Bearer '.length)
      : ''
    const apiKey = req.headers.get('apikey') ?? ''
    const isInternalCall = Boolean(serviceRoleKey) &&
      (internalServiceKey === serviceRoleKey || apiKey === serviceRoleKey || bearerToken === serviceRoleKey)

    let actorUserId: string | null = null

    if (!isInternalCall) {
      const userClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authorization } },
      })
      const {
        data: { user },
        error: authError,
      } = await userClient.auth.getUser()

      if (authError || !user) {
        return new Response(JSON.stringify({ error: authError?.message ?? 'Unauthorized' }), {
          status: 401,
          headers,
        })
      }

      actorUserId = user.id
    }

    const input = await req.json().catch(() => ({}))
    const messageId = input.messageId ?? input.message_id ?? null

    if (messageId && !isValidUUID(messageId)) {
      return new Response(JSON.stringify({ error: 'Invalid messageId' }), { status: 400, headers })
    }

    if (!messageId && !isInternalCall && !actorUserId) {
      return new Response(JSON.stringify({ error: 'messageId is required' }), { status: 400, headers })
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey)
    const jobsById = new Map<string, NotificationJobRow>()

    if (messageId) {
      const { data: job, error: jobError } = await serviceClient
        .from('message_notification_jobs')
        .select('id, message_id, conversation_id, sender_id, recipient_id, status, attempts, notification_id')
        .eq('message_id', messageId)
        .maybeSingle()

      if (jobError) {
        return new Response(JSON.stringify({ error: jobError.message }), { status: 500, headers })
      }

      if (job) {
        jobsById.set((job as NotificationJobRow).id, job as NotificationJobRow)
      }
    }

    const limit = Math.max(1, Math.min(Number(input.limit ?? 20), 100))
    let pendingJobsQuery = serviceClient
      .from('message_notification_jobs')
      .select('id, message_id, conversation_id, sender_id, recipient_id, status, attempts, notification_id')
      .in('status', ['pending', 'failed'])
      .order('created_at', { ascending: true })
      .limit(limit)

    if (!isInternalCall && actorUserId) {
      pendingJobsQuery = pendingJobsQuery.eq('sender_id', actorUserId)
    }

    const { data: pendingJobs, error: pendingError } = await pendingJobsQuery

    if (pendingError) {
      return new Response(JSON.stringify({ error: pendingError.message }), { status: 500, headers })
    }

    for (const pendingJob of (pendingJobs ?? []) as NotificationJobRow[]) {
      jobsById.set(pendingJob.id, pendingJob)
    }

    const jobs = Array.from(jobsById.values())

    if (jobs.length === 0) {
      return new Response(JSON.stringify({ jobs: [] }), { status: 200, headers })
    }

    const results: Array<Record<string, unknown>> = []

    for (const job of jobs) {
      if (actorUserId && job.sender_id !== actorUserId) {
        return new Response(JSON.stringify({ error: 'Not authorized to dispatch this notification' }), {
          status: 403,
          headers,
        })
      }

      if (job.status === 'sent' || job.status === 'skipped') {
        results.push({
          message_id: job.message_id,
          status: job.status,
          push_sent: job.status === 'sent',
        })
        continue
      }

      const { data: claimedJob, error: claimError } = await serviceClient
        .from('message_notification_jobs')
        .update({
          status: 'processing',
          attempts: job.attempts + 1,
          locked_at: new Date().toISOString(),
        })
        .eq('id', job.id)
        .in('status', ['pending', 'failed', 'processing'])
        .select('id, message_id, conversation_id, sender_id, recipient_id, status, attempts, notification_id')
        .maybeSingle()

      if (claimError || !claimedJob) {
        results.push({
          message_id: job.message_id,
          status: 'failed',
          error: claimError?.message ?? 'Failed to claim notification job',
        })
        continue
      }

      const typedJob = claimedJob as NotificationJobRow

      const { data: message, error: messageError } = await serviceClient
        .from('messages')
        .select('id, body, task_id, message_type, deleted_at')
        .eq('id', typedJob.message_id)
        .maybeSingle()

      if (messageError || !message) {
        await serviceClient
          .from('message_notification_jobs')
          .update({
            status: 'failed',
            last_error: messageError?.message ?? 'Message not found',
            locked_at: null,
          })
          .eq('id', typedJob.id)

        results.push({
          message_id: typedJob.message_id,
          status: 'failed',
          error: messageError?.message ?? 'Message not found',
        })
        continue
      }

      const typedMessage = message as MessageRow

      if (typedMessage.deleted_at || typedMessage.message_type === 'system') {
        await serviceClient
          .from('message_notification_jobs')
          .update({
            status: 'skipped',
            last_error: 'message_not_notifiable',
            processed_at: new Date().toISOString(),
            locked_at: null,
          })
          .eq('id', typedJob.id)

        results.push({
          message_id: typedJob.message_id,
          status: 'skipped',
          push_sent: false,
        })
        continue
      }

      try {
        let notificationId = typedJob.notification_id ?? null

        if (!notificationId) {
          const { data: senderProfile } = await serviceClient
            .from('users')
            .select('full_name')
            .eq('id', typedJob.sender_id)
            .maybeSingle()

          const preview = buildPreview(typedMessage)
          const { data: notification, error: notificationError } = await serviceClient
            .from('notifications')
            .insert({
              user_id: typedJob.recipient_id,
              type: 'new_message',
              title: senderProfile?.full_name ?? 'Someone',
              body: preview,
              data: {
                sender_name: senderProfile?.full_name ?? 'Someone',
                message_preview: preview,
                conversation_id: typedJob.conversation_id,
                task_id: typedMessage.task_id,
                screen: 'messages',
              },
            })
            .select('id')
            .single()

          if (notificationError || !notification) {
            throw new Error(notificationError?.message ?? 'Failed to create message notification')
          }

          notificationId = notification.id
          await serviceClient
            .from('message_notification_jobs')
            .update({ notification_id: notificationId })
            .eq('id', typedJob.id)
        }

        const { data: notification, error: notificationLookupError } = await serviceClient
          .from('notifications')
          .select('id, title, body, data')
          .eq('id', notificationId)
          .maybeSingle()

        if (notificationLookupError || !notification) {
          throw new Error(notificationLookupError?.message ?? 'Notification record not found')
        }

        const typedNotification = notification as NotificationRow
        const { data: tokens, error: tokenError } = await serviceClient
          .from('push_tokens')
          .select('token, platform')
          .eq('user_id', typedJob.recipient_id)
          .eq('is_active', true)

        if (tokenError) {
          throw new Error(tokenError.message)
        }

        const typedTokens = (tokens ?? []) as PushTokenRow[]
        if (typedTokens.length === 0) {
          await serviceClient
            .from('message_notification_jobs')
            .update({
              status: 'sent',
              notification_id: notificationId,
              push_sent: false,
              processed_at: new Date().toISOString(),
              last_error: null,
              locked_at: null,
            })
            .eq('id', typedJob.id)

          results.push({
            message_id: typedJob.message_id,
            status: 'sent',
            push_sent: false,
            notification_id: notificationId,
          })
          continue
        }

        const fcmServiceAccount = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
        if (!fcmServiceAccount) {
          await serviceClient
            .from('message_notification_jobs')
            .update({
              status: 'sent',
              notification_id: notificationId,
              push_sent: false,
              processed_at: new Date().toISOString(),
              last_error: null,
              locked_at: null,
            })
            .eq('id', typedJob.id)

          results.push({
            message_id: typedJob.message_id,
            status: 'sent',
            push_sent: false,
            notification_id: notificationId,
          })
          continue
        }

        const serviceAccount = JSON.parse(fcmServiceAccount)
        const accessToken = await getFcmAccessToken(serviceAccount)
        const projectId = serviceAccount.project_id
        let pushSent = false

        for (const tokenRow of typedTokens) {
          const messagePayload: Record<string, unknown> = {
            token: tokenRow.token,
            notification: {
              title: typedNotification.title,
              body: typedNotification.body,
            },
            data: {
              type: 'new_message',
              ...((typedNotification.data ?? {}) as Record<string, string>),
            },
          }

          if (tokenRow.platform === 'ios') {
            messagePayload.apns = {
              payload: { aps: { sound: 'default', badge: 1 } },
            }
          } else if (tokenRow.platform === 'web') {
            messagePayload.webpush = {
              notification: { icon: '/icon-192.png' },
            }
          }

          const pushResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({ message: messagePayload }),
            },
          )

          if (pushResponse.ok) {
            pushSent = true
            continue
          }

          const errorBody = await pushResponse.json().catch(() => ({}))
          const errorCode = errorBody?.error?.details?.[0]?.errorCode
          if (errorCode === 'UNREGISTERED' || pushResponse.status === 404) {
            await serviceClient
              .from('push_tokens')
              .update({ is_active: false })
              .eq('token', tokenRow.token)
          }
        }

        await serviceClient
          .from('message_notification_jobs')
          .update({
            status: 'sent',
            notification_id: notificationId,
            push_sent: pushSent,
            processed_at: new Date().toISOString(),
            last_error: null,
            locked_at: null,
          })
          .eq('id', typedJob.id)

        if (pushSent) {
          await serviceClient
            .from('notifications')
            .update({ push_sent_at: new Date().toISOString() })
            .eq('id', notificationId)
        }

        results.push({
          message_id: typedJob.message_id,
          status: 'sent',
          push_sent: pushSent,
          notification_id: notificationId,
        })
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Failed to dispatch notification'

        await serviceClient
          .from('message_notification_jobs')
          .update({
            status: 'failed',
            last_error: errorMessage,
            locked_at: null,
          })
          .eq('id', typedJob.id)

        results.push({
          message_id: typedJob.message_id,
          status: 'failed',
          error: errorMessage,
        })
      }
    }

    return new Response(JSON.stringify({ jobs: results }), { status: 200, headers })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected error'
    return new Response(JSON.stringify({ error: message }), { status: 500, headers })
  }
})
