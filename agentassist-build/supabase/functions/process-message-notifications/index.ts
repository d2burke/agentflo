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
}

type MessageRow = {
  id: string
  body: string | null
  task_id: string | null
  message_type: 'text' | 'image' | 'file' | 'system'
  deleted_at: string | null
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
    const bearerToken = authorization.startsWith('Bearer ')
      ? authorization.slice('Bearer '.length)
      : ''
    const apiKey = req.headers.get('apikey') ?? ''
    const isInternalCall = Boolean(serviceRoleKey) &&
      (bearerToken === serviceRoleKey || apiKey === serviceRoleKey)

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

    if (!messageId && !isInternalCall) {
      return new Response(JSON.stringify({ error: 'messageId is required' }), { status: 400, headers })
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey)
    const jobs: NotificationJobRow[] = []

    if (messageId) {
      const { data: job, error: jobError } = await serviceClient
        .from('message_notification_jobs')
        .select('id, message_id, conversation_id, sender_id, recipient_id, status, attempts')
        .eq('message_id', messageId)
        .maybeSingle()

      if (jobError) {
        return new Response(JSON.stringify({ error: jobError.message }), { status: 500, headers })
      }

      if (!job) {
        return new Response(JSON.stringify({ jobs: [] }), { status: 200, headers })
      }

      jobs.push(job as NotificationJobRow)
    } else {
      const limit = Math.max(1, Math.min(Number(input.limit ?? 20), 100))
      const { data: pendingJobs, error: pendingError } = await serviceClient
        .from('message_notification_jobs')
        .select('id, message_id, conversation_id, sender_id, recipient_id, status, attempts')
        .in('status', ['pending', 'failed'])
        .order('created_at', { ascending: true })
        .limit(limit)

      if (pendingError) {
        return new Response(JSON.stringify({ error: pendingError.message }), { status: 500, headers })
      }

      jobs.push(...((pendingJobs ?? []) as NotificationJobRow[]))
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
        .select('id, message_id, conversation_id, sender_id, recipient_id, status, attempts')
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

      const { data: senderProfile } = await serviceClient
        .from('users')
        .select('full_name')
        .eq('id', typedJob.sender_id)
        .maybeSingle()

      const notifyPayload: Record<string, string> = {
        sender_name: senderProfile?.full_name ?? 'Someone',
        message_preview: buildPreview(typedMessage),
        conversation_id: typedJob.conversation_id,
        screen: 'messages',
      }

      if (typedMessage.task_id) {
        notifyPayload.task_id = typedMessage.task_id
      }

      try {
        const notifyResponse = await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${serviceRoleKey}`,
            apikey: serviceRoleKey,
          },
          body: JSON.stringify({
            userId: typedJob.recipient_id,
            type: 'new_message',
            data: notifyPayload,
          }),
        })

        const notifyText = await notifyResponse.text()
        const notifyBody = notifyText ? JSON.parse(notifyText) : {}

        if (!notifyResponse.ok) {
          await serviceClient
            .from('message_notification_jobs')
            .update({
              status: 'failed',
              last_error: notifyBody.error ?? `Notification dispatch failed (${notifyResponse.status})`,
              locked_at: null,
            })
            .eq('id', typedJob.id)

          results.push({
            message_id: typedJob.message_id,
            status: 'failed',
            error: notifyBody.error ?? `Notification dispatch failed (${notifyResponse.status})`,
          })
          continue
        }

        const nextStatus = notifyBody.skipped ? 'skipped' : 'sent'

        await serviceClient
          .from('message_notification_jobs')
          .update({
            status: nextStatus,
            notification_id: notifyBody.notification_id ?? null,
            push_sent: Boolean(notifyBody.push_sent),
            processed_at: new Date().toISOString(),
            last_error: notifyBody.skipped ?? null,
            locked_at: null,
          })
          .eq('id', typedJob.id)

        results.push({
          message_id: typedJob.message_id,
          status: nextStatus,
          push_sent: Boolean(notifyBody.push_sent),
          notification_id: notifyBody.notification_id ?? null,
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
