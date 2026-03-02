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

serve(async (req) => {
  try {
    const { taskId } = await req.json()

    // Create Supabase client with auth context from request
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

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

    // TODO: Step 2 — Geocode address
    // const { lat, lng } = await geocodeAddress(task.property_address)

    // TODO: Step 3 — Create Stripe PaymentIntent (uncaptured)
    // const paymentIntent = await stripe.paymentIntents.create({
    //   amount: task.price,
    //   currency: 'usd',
    //   capture_method: 'manual',
    //   metadata: { task_id: taskId }
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
        // property_lat: lat,
        // property_lng: lng,
        // stripe_payment_intent_id: paymentIntent.id,
      })
      .eq('id', taskId)
      .select()
      .single()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    // TODO: Step 5 — Find nearby runners via PostGIS
    // TODO: Step 6 — Notify runners via send-notification

    return new Response(JSON.stringify(updated), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
