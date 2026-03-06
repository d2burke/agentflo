// supabase/functions/post-task/index.ts
// Edge Function: Transitions a task from draft → posted
//
// Business Logic:
//   1. Validate required fields (address, price, category)
//   2. Geocode property address → lat/lng (Google Maps Geocoding API)
//   3. Create Stripe PaymentIntent (uncaptured) for the task price
//   4. Update task status to 'posted', set posted_at
//   5. Find nearby runners (PostGIS query against service_areas)
//   6. Send notifications to nearby runners via send-notification function
//
// Auth: Requires authenticated agent who owns the task
// Input: { taskId: string }
// Output: { id, status, stripe_payment_intent_id, posted_at }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCorsPreFlight, getCorsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/rate-limit.ts'
import { isValidUUID } from '../_shared/validation.ts'

serve(async (req) => {
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse

  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    const { taskId } = await req.json()

    if (!isValidUUID(taskId)) {
      return new Response(JSON.stringify({ error: 'Invalid taskId' }), { status: 400, headers })
    }

    // Create Supabase client with auth context from request
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers })
    }

    // Rate limit: write action (10/min)
    const rateLimitResponse = await checkRateLimit(user.id, 'write')
    if (rateLimitResponse) return rateLimitResponse

    // Fetch the task and validate ownership + status
    const { data: task, error: fetchError } = await supabase
      .from('tasks')
      .select('*')
      .eq('id', taskId)
      .eq('agent_id', user.id)
      .single()

    if (fetchError || !task) {
      return new Response(JSON.stringify({ error: 'Task not found' }), { status: 404 })
    }

    if (task.status !== 'draft') {
      return new Response(
        JSON.stringify({ error: `Cannot post task with status '${task.status}'` }),
        { status: 400 }
      )
    }

    // Validate required fields
    if (!task.property_address || !task.price || !task.category) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: address, price, category' }),
        { status: 400 }
      )
    }

    // Validate price range (in cents: $0.01 to $10,000)
    if (!Number.isInteger(task.price) || task.price <= 0 || task.price > 1000000) {
      return new Response(
        JSON.stringify({ error: 'Price must be between $0.01 and $10,000' }),
        { status: 400 }
      )
    }

    // Validate category
    const VALID_CATEGORIES = ['Photography', 'Showing', 'Staging', 'Open House', 'Inspection']
    if (!VALID_CATEGORIES.includes(task.category)) {
      return new Response(
        JSON.stringify({ error: `Invalid category. Must be one of: ${VALID_CATEGORIES.join(', ')}` }),
        { status: 400 }
      )
    }

    // Validate address is not empty/whitespace
    if (!task.property_address.trim()) {
      return new Response(
        JSON.stringify({ error: 'Property address cannot be empty' }),
        { status: 400 }
      )
    }

    // Step 2 — Geocode address via Google Maps Geocoding API
    let lat: number | null = task.property_lat
    let lng: number | null = task.property_lng

    const googleMapsKey = Deno.env.get('GOOGLE_MAPS_API_KEY')
    if (googleMapsKey && !lat) {
      try {
        const geocodeUrl = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(task.property_address)}&key=${googleMapsKey}`
        const geocodeRes = await fetch(geocodeUrl)
        const geocodeData = await geocodeRes.json()

        if (geocodeData.status === 'OK' && geocodeData.results?.length > 0) {
          lat = geocodeData.results[0].geometry.location.lat
          lng = geocodeData.results[0].geometry.location.lng
        } else {
          console.warn(`[post-task] Geocoding failed for "${task.property_address}": ${geocodeData.status}`)
        }
      } catch (geoErr) {
        console.error('[post-task] Geocoding error:', geoErr)
      }
    }

    // TODO: Step 3 — Create Stripe PaymentIntent (uncaptured)
    // Agent-pays model: hold price + 15% service fee
    // const fee = Math.round(task.price * 0.15)
    // const paymentIntent = await stripe.paymentIntents.create({
    //   amount: task.price + fee,
    //   currency: 'usd',
    //   capture_method: 'manual',
    //   customer: agentProfile.stripe_customer_id,
    //   metadata: { task_id: taskId, runner_pay: task.price, platform_fee: fee }
    // })

    // Step 4 — Update task status using service role client
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: updated, error: updateError } = await serviceClient
      .from('tasks')
      .update({
        status: 'posted',
        posted_at: new Date().toISOString(),
        property_lat: lat,
        property_lng: lng,
        // stripe_payment_intent_id: paymentIntent.id,
      })
      .eq('id', taskId)
      .select('id, status, posted_at, stripe_payment_intent_id')
      .single()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    // Step 5 — Find nearby runners via PostGIS
    if (lat && lng) {
      try {
        const { data: nearbyRunners } = await serviceClient.rpc('find_nearby_runners', {
          task_lat: lat,
          task_lng: lng,
        })

        // Step 6 — Notify nearby runners (skip the posting agent)
        const notifyUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notification`
        const notifyHeaders = {
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          'Content-Type': 'application/json',
        }

        for (const runner of nearbyRunners ?? []) {
          if (runner.runner_id === user.id) continue
          try {
            await fetch(notifyUrl, {
              method: 'POST',
              headers: notifyHeaders,
              body: JSON.stringify({
                userId: runner.runner_id,
                type: 'new_task_nearby',
                data: {
                  category: task.category,
                  distance: `${runner.distance_miles.toFixed(1)} mi`,
                  price: (task.price / 100).toFixed(0),
                  task_id: taskId,
                },
              }),
            })
          } catch (e) {
            console.error(`[post-task] Failed to notify runner ${runner.runner_id}:`, e)
          }
        }
      } catch (e) {
        console.error('[post-task] Nearby runner lookup failed:', e)
      }
    }

    return new Response(JSON.stringify(updated), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
