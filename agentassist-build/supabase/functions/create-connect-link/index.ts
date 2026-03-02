// supabase/functions/create-connect-link/index.ts
// Edge Function: Creates a Stripe Connect Account (if needed) + Account Link for onboarding
//
// Flow:
//   1. Get authenticated user (must be a runner)
//   2. Check if user already has a stripe_connect_id
//   3. If not, create a Stripe Express Connect Account
//   4. Create an Account Link for onboarding / updating
//   5. Return { url, account_id }
//
// Auth: Requires authenticated runner
// Input: {} (no body needed)
// Output: { url: string, account_id: string }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.14.0?target=deno'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with auth context
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    // Fetch user profile
    const { data: profile, error: profileError } = await serviceClient
      .from('users')
      .select('stripe_connect_id, email, full_name, role')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'User profile not found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404,
      })
    }

    if (profile.role !== 'runner') {
      return new Response(JSON.stringify({ error: 'Only runners can connect bank accounts' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    let accountId = profile.stripe_connect_id

    // Create Stripe Connect Express Account if needed
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        email: profile.email,
        metadata: { supabase_user_id: user.id },
        capabilities: {
          transfers: { requested: true },
        },
        business_type: 'individual',
        individual: {
          email: profile.email,
        },
      })
      accountId = account.id

      // Save connect account ID to profile
      await serviceClient
        .from('users')
        .update({ stripe_connect_id: accountId })
        .eq('id', user.id)
    }

    // Create Account Link for onboarding/updating
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: 'agentassist://stripe-connect/refresh',
      return_url: 'agentassist://stripe-connect/return',
      type: 'account_onboarding',
    })

    return new Response(JSON.stringify({
      url: accountLink.url,
      account_id: accountId,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
