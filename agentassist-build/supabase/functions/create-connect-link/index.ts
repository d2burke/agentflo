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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    if (!stripeKey) {
      console.error('STRIPE_SECRET_KEY is not set')
      return new Response(JSON.stringify({ error: 'Payment service not configured' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      })
    }

    const stripe = new Stripe(stripeKey, {
      apiVersion: '2023-10-16',
      httpClient: Stripe.createFetchHttpClient(),
    })

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    // Create Supabase client with auth context
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      console.error('Auth error:', authError?.message)
      return new Response(JSON.stringify({ error: 'Unauthorized', detail: authError?.message }), {
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
      console.error('Profile error:', profileError?.message)
      return new Response(JSON.stringify({ error: 'User profile not found', detail: profileError?.message }), {
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

    const email = profile.email || user.email
    let accountId = profile.stripe_connect_id

    // Helper to create a fresh Stripe Express account
    // Pre-fill as much as possible so the runner only needs to add bank details + verify identity
    async function createExpressAccount(): Promise<string> {
      console.log('Creating new Stripe Express account for user:', user!.id)
      const account = await stripe.accounts.create({
        type: 'express',
        country: 'US',
        email,
        metadata: { supabase_user_id: user!.id },
        capabilities: {
          transfers: { requested: true },
        },
        business_type: 'individual',
        business_profile: {
          product_description: 'Real estate task services via Agent Flo',
          mcc: '7299', // Miscellaneous personal services
          url: 'https://agentflo.app',
        },
        individual: {
          email,
          first_name: profile.full_name?.split(' ')[0] ?? undefined,
          last_name: profile.full_name?.split(' ').slice(1).join(' ') ?? undefined,
        },
      })

      // Save connect account ID to profile
      const { error: updateErr } = await serviceClient
        .from('users')
        .update({ stripe_connect_id: account.id })
        .eq('id', user!.id)

      if (updateErr) {
        console.error('Failed to save stripe_connect_id:', updateErr.message)
      }

      return account.id
    }

    if (!accountId) {
      // No existing account — create one
      accountId = await createExpressAccount()
    } else {
      // Verify the existing account is still valid on Stripe
      try {
        const existing = await stripe.accounts.retrieve(accountId)
        console.log('Existing account status:', accountId, 'charges_enabled:', existing.charges_enabled, 'payouts_enabled:', existing.payouts_enabled)
      } catch (stripeErr) {
        const err = stripeErr as any
        console.warn(`Existing Stripe account ${accountId} failed retrieval:`, err?.message)
        // Account was deleted, invalid, or inaccessible — create a new one
        accountId = await createExpressAccount()
      }
    }

    // Create Account Link for onboarding/updating
    // Stripe requires https:// URLs — use the redirect function to deep-link back to the app
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const redirectBase = `${supabaseUrl}/functions/v1/stripe-connect-redirect`

    console.log('Creating account link for:', accountId)
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${redirectBase}?type=refresh`,
      return_url: `${redirectBase}?type=return`,
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
    const error = err as any
    console.error('create-connect-link error:', error?.message, error?.type, error?.statusCode, error?.code)
    return new Response(JSON.stringify({
      error: error?.message ?? 'Unknown error',
      type: error?.type,
      code: error?.code,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: error?.statusCode || 500,
    })
  }
})
