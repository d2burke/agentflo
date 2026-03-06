// supabase/functions/register-push-token/index.ts
// Edge Function: Register a device push token for notifications
//
// Called by iOS and web clients after obtaining a push token.
// Upserts the token (deactivates old tokens for the same user+platform).
//
// Auth: Requires authenticated user
// Input: { token: string, platform: 'ios' | 'web' }
// Output: { success: true }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCorsPreFlight, getCorsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/rate-limit.ts'
import { isValidPlatform } from '../_shared/validation.ts'

serve(async (req) => {
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse
  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    const { token, platform } = await req.json()

    if (typeof token !== 'string' || token.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'token must be a non-empty string' }),
        { status: 400, headers },
      )
    }

    if (!isValidPlatform(platform)) {
      return new Response(
        JSON.stringify({ error: 'platform must be ios, web, or android' }),
        { status: 400, headers },
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
    )

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers })
    }

    const rateLimitResponse = await checkRateLimit(user.id, 'write')
    if (rateLimitResponse) return rateLimitResponse

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Deactivate other tokens for this user+platform (one active token per platform)
    await serviceClient
      .from('push_tokens')
      .update({ is_active: false })
      .eq('user_id', user.id)
      .eq('platform', platform)
      .neq('token', token)

    // Upsert the new token
    await serviceClient
      .from('push_tokens')
      .upsert(
        {
          user_id: user.id,
          token,
          platform,
          is_active: true,
        },
        { onConflict: 'user_id,token' },
      )

    return new Response(
      JSON.stringify({ success: true }),
      { headers },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers })
  }
})
