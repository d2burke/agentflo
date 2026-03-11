import { NextResponse } from 'next/server'
import { createClient as createServerClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

const SESSION_REFRESH_WINDOW_MS = 60_000

type MessageJobRow = {
  id: string
  message_id: string
  sender_id: string
  recipient_id: string
  conversation_id: string
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

function buildMessagePreview(message: MessageRow) {
  if (message.deleted_at) return '[deleted]'

  const trimmed = (message.body ?? '').trim()
  if (trimmed.length > 0) {
    return trimmed.length > 100 ? `${trimmed.slice(0, 97)}...` : trimmed
  }

  if (message.message_type === 'image') return 'Sent an image'
  if (message.message_type === 'file') return 'Sent a file'

  return 'New message'
}

async function resolveAuthorization(request: Request): Promise<string | null> {
  const supabase = await createServerClient()
  const {
    data: { session: initialSession },
  } = await supabase.auth.getSession()

  let session = initialSession
  const expiresSoon = session?.expires_at
    ? (session.expires_at * 1000) <= (Date.now() + SESSION_REFRESH_WINDOW_MS)
    : false

  if (!session?.access_token || expiresSoon) {
    const { data, error } = await supabase.auth.refreshSession()
    if (!error && data.session?.access_token) {
      session = data.session
    }
  }

  if (session?.access_token) {
    return `Bearer ${session.access_token}`
  }

  return request.headers.get('Authorization')
}

export async function POST(request: Request) {
  const payload = await request.json().catch(() => ({}))
  const messageId = payload.messageId ?? payload.message_id ?? null
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return NextResponse.json({ error: 'Supabase environment is not configured' }, { status: 500 })
  }

  if (!messageId || typeof messageId !== 'string') {
    return NextResponse.json({ error: 'messageId is required' }, { status: 400 })
  }

  const authorization = await resolveAuthorization(request)
  if (!authorization) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const userClient = createAdminClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  })
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser()

  if (authError || !user) {
    return NextResponse.json({ error: authError?.message ?? 'Unauthorized' }, { status: 401 })
  }

  const admin = createAdminClient(supabaseUrl, serviceRoleKey)

  const { data: job, error: jobError } = await admin
    .from('message_notification_jobs')
    .select('id, message_id, sender_id, recipient_id, conversation_id, status, attempts')
    .eq('message_id', messageId)
    .maybeSingle()

  if (jobError) {
    return NextResponse.json({ error: jobError.message }, { status: 500 })
  }

  if (!job) {
    return NextResponse.json({ jobs: [] }, { status: 200 })
  }

  const typedJob = job as MessageJobRow

  if (typedJob.sender_id !== user.id) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  if (typedJob.status === 'sent' || typedJob.status === 'skipped') {
    return NextResponse.json({
      jobs: [{ message_id: typedJob.message_id, status: typedJob.status, push_sent: typedJob.status === 'sent' }],
    }, { status: 200 })
  }

  const { data: message, error: messageError } = await admin
    .from('messages')
    .select('id, body, task_id, message_type, deleted_at')
    .eq('id', typedJob.message_id)
    .maybeSingle()

  if (messageError || !message) {
    await admin
      .from('message_notification_jobs')
      .update({
        status: 'failed',
        attempts: typedJob.attempts + 1,
        last_error: messageError?.message ?? 'Message not found',
        processed_at: new Date().toISOString(),
      })
      .eq('id', typedJob.id)

    return NextResponse.json({ error: messageError?.message ?? 'Message not found' }, { status: 500 })
  }

  const typedMessage = message as MessageRow

  if (typedMessage.deleted_at || typedMessage.message_type === 'system') {
    await admin
      .from('message_notification_jobs')
      .update({
        status: 'skipped',
        attempts: typedJob.attempts + 1,
        last_error: 'message_not_notifiable',
        processed_at: new Date().toISOString(),
      })
      .eq('id', typedJob.id)

    return NextResponse.json({
      jobs: [{ message_id: typedJob.message_id, status: 'skipped', push_sent: false }],
    }, { status: 200 })
  }

  const { data: senderProfile } = await admin
    .from('users')
    .select('full_name')
    .eq('id', typedJob.sender_id)
    .maybeSingle()

  const senderName = senderProfile?.full_name ?? 'Someone'
  const preview = buildMessagePreview(typedMessage)

  const notificationResponse = await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
    },
    body: JSON.stringify({
      userId: typedJob.recipient_id,
      type: 'new_message',
      data: {
        sender_name: senderName,
        message_preview: preview,
        conversation_id: typedJob.conversation_id,
        task_id: typedMessage.task_id,
        screen: 'messages',
      },
      customTitle: senderName,
      customBody: preview,
    }),
  })

  const notificationBody = await notificationResponse.json().catch(() => ({}))
  const processedAt = new Date().toISOString()

  if (!notificationResponse.ok) {
    const errorMessage = notificationBody?.error ?? 'Failed to dispatch notification'
    await admin
      .from('message_notification_jobs')
      .update({
        status: 'failed',
        attempts: typedJob.attempts + 1,
        push_sent: false,
        last_error: errorMessage,
        processed_at: processedAt,
      })
      .eq('id', typedJob.id)

    return NextResponse.json({ error: errorMessage }, { status: 500 })
  }

  const skipped = typeof notificationBody?.skipped === 'string' ? notificationBody.skipped : null
  const status = skipped ? 'skipped' : 'sent'
  const pushSent = Boolean(notificationBody?.push_sent)

  await admin
    .from('message_notification_jobs')
    .update({
      status,
      attempts: typedJob.attempts + 1,
      push_sent: pushSent,
      notification_id: notificationBody?.notification_id ?? null,
      last_error: skipped,
      processed_at: processedAt,
    })
    .eq('id', typedJob.id)

  return NextResponse.json({
    jobs: [{
      message_id: typedJob.message_id,
      status,
      push_sent: pushSent,
      notification_id: notificationBody?.notification_id ?? null,
    }],
  }, { status: 200 })
}
