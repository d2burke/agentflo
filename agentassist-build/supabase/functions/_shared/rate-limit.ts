// Shared rate limiting for edge functions
// Uses the check_rate_limit PL/pgSQL function from 20240118000004_rate_limiting.sql

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const LIMITS: Record<string, { maxRequests: number; windowSeconds: number }> = {
  read:  { maxRequests: 60,  windowSeconds: 60 },
  write: { maxRequests: 10,  windowSeconds: 60 },
  auth:  { maxRequests: 3,   windowSeconds: 60 },
}

/**
 * Check rate limit for a given user/action.
 * Returns null if allowed, or a 429 Response if rate limited.
 */
export async function checkRateLimit(
  userId: string,
  actionType: 'read' | 'write' | 'auth',
): Promise<Response | null> {
  const limit = LIMITS[actionType]
  if (!limit) return null

  try {
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { data: allowed } = await serviceClient.rpc('check_rate_limit', {
      p_identifier: userId,
      p_action_type: actionType,
      p_max_requests: limit.maxRequests,
      p_window_seconds: limit.windowSeconds,
    })

    if (allowed === false) {
      return new Response(
        JSON.stringify({ error: 'Too many requests. Please try again later.' }),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': String(limit.windowSeconds),
          },
        },
      )
    }
  } catch (err) {
    // Don't block requests if rate limiting fails
    console.error('[rate-limit] Check failed:', err)
  }

  return null
}
