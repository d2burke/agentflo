import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

async function resolveAuthorization(request: Request): Promise<string | null> {
  const supabase = await createClient()
  const {
    data: { session: initialSession },
  } = await supabase.auth.getSession()

  let session = initialSession

  if (!session?.access_token) {
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
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    return NextResponse.json({ error: 'Supabase environment is not configured' }, { status: 500 })
  }

  const authorization = await resolveAuthorization(request)

  if (!authorization) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const response = await fetch(`${supabaseUrl}/functions/v1/process-message-notifications`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: supabaseAnonKey,
      Authorization: authorization,
    },
    body: JSON.stringify(payload),
  })

  const text = await response.text()

  return new NextResponse(text, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  })
}
