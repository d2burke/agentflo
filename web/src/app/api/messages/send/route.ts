import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

const SESSION_REFRESH_WINDOW_MS = 60_000

async function resolveAuthorization(request: Request): Promise<{
  authorization: string | null
  supabase: Awaited<ReturnType<typeof createClient>>
  fromSession: boolean
}> {
  const supabase = await createClient()
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
    return {
      authorization: `Bearer ${session.access_token}`,
      supabase,
      fromSession: true,
    }
  }

  return {
    authorization: request.headers.get('Authorization'),
    supabase,
    fromSession: false,
  }
}

async function forwardSendMessage(
  supabaseUrl: string,
  supabaseAnonKey: string,
  authorization: string,
  payload: unknown,
) {
  return fetch(`${supabaseUrl}/functions/v1/send-message`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: supabaseAnonKey,
      Authorization: authorization,
    },
    body: JSON.stringify(payload),
  })
}

export async function POST(request: Request) {
  const payload = await request.json().catch(() => ({}))
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    return NextResponse.json({ error: 'Supabase environment is not configured' }, { status: 500 })
  }

  const { authorization, supabase, fromSession } = await resolveAuthorization(request)

  if (!authorization) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  let effectiveAuthorization = authorization
  let response = await forwardSendMessage(supabaseUrl, supabaseAnonKey, effectiveAuthorization, payload)

  if (response.status === 401 && fromSession) {
    const { data, error } = await supabase.auth.refreshSession()
    if (!error && data.session?.access_token) {
      effectiveAuthorization = `Bearer ${data.session.access_token}`
      response = await forwardSendMessage(supabaseUrl, supabaseAnonKey, effectiveAuthorization, payload)
    }
  }

  const text = await response.text()
  let parsed: { message?: { id?: string } } | null = null

  if (response.ok && text) {
    try {
      parsed = JSON.parse(text) as { message?: { id?: string } }
    } catch {
      parsed = null
    }
  }

  const messageId = parsed?.message?.id
  if (response.ok && messageId) {
    try {
      if (serviceRoleKey) {
        await fetch(`${supabaseUrl}/functions/v1/process-message-notifications`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            apikey: supabaseAnonKey,
          },
          body: JSON.stringify({
            messageId,
            internalServiceKey: serviceRoleKey,
          }),
        })
      } else {
        await fetch(`${supabaseUrl}/functions/v1/process-message-notifications`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            apikey: supabaseAnonKey,
            Authorization: effectiveAuthorization,
          },
          body: JSON.stringify({ messageId }),
        })
      }
    } catch {
      // Best-effort fallback only. Message delivery should still succeed.
    }
  }

  return new NextResponse(text, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  })
}
