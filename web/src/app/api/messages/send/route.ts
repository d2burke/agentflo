import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(request: Request) {
  const payload = await request.json().catch(() => ({}))
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    return NextResponse.json({ error: 'Supabase environment is not configured' }, { status: 500 })
  }

  const supabase = await createClient()
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser()

  let authorization: string | null = null

  if (!userError && user) {
    let {
      data: { session },
    } = await supabase.auth.getSession()

    if (!session?.access_token) {
      const { data, error } = await supabase.auth.refreshSession()
      if (!error && data.session?.access_token) {
        session = data.session
      }
    }

    if (session?.access_token) {
      authorization = `Bearer ${session.access_token}`
    }
  }

  if (!authorization) {
    authorization = request.headers.get('Authorization')
  }

  if (!authorization) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const response = await fetch(`${supabaseUrl}/functions/v1/send-message`, {
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
