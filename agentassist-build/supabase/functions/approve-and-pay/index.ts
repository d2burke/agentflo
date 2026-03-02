// supabase/functions/approve-and-pay/index.ts
// Edge Function: Agent approves deliverables and triggers payment
//
// Business Logic:
//   1. Validate: task.agent_id = auth user, task.status = 'deliverables_submitted'
//   2. Capture the Stripe PaymentIntent (transitions from hold → captured)
//   3. Schedule runner payout via Stripe Transfer to their Connect account
//   4. Update task: status → 'completed', set completed_at
//   5. Notify runner: "Payment received! $X deposited."
//   6. Prompt both parties for reviews
//
// Auth: Requires authenticated agent who owns the task
// Input: { taskId: string }
// Output: { task: { id, status, completed_at } }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.14.0?target=deno'

serve(async (req) => {
  try {
    const { taskId } = await req.json()

    if (!taskId) {
      return new Response(JSON.stringify({ error: 'taskId is required' }), { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
    )

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Fetch task
    const { data: task } = await serviceClient
      .from('tasks')
      .select('*')
      .eq('id', taskId)
      .single()

    if (!task) {
      return new Response(JSON.stringify({ error: 'Task not found' }), { status: 404 })
    }
    if (task.agent_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Not your task' }), { status: 403 })
    }
    if (task.status !== 'deliverables_submitted') {
      return new Response(
        JSON.stringify({ error: `Cannot approve task with status '${task.status}'` }),
        { status: 400 },
      )
    }

    // Capture Stripe PaymentIntent
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    if (stripeKey && task.stripe_payment_intent_id) {
      const stripe = new Stripe(stripeKey, { apiVersion: '2023-10-16' })

      // Capture the held payment
      await stripe.paymentIntents.capture(task.stripe_payment_intent_id)

      // Transfer runner payout to their Connect account
      if (task.runner_payout && task.runner_id) {
        const { data: runner } = await serviceClient
          .from('users')
          .select('stripe_connect_id')
          .eq('id', task.runner_id)
          .single()

        if (runner?.stripe_connect_id) {
          await stripe.transfers.create({
            amount: task.runner_payout,
            currency: 'usd',
            destination: runner.stripe_connect_id,
            transfer_group: taskId,
            metadata: { task_id: taskId },
          })
        }
      }
    }

    // Update task status
    const { data: updated, error: updateError } = await serviceClient
      .from('tasks')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
      })
      .eq('id', taskId)
      .select()
      .single()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    // Format payout amount for notification
    const payoutFormatted = task.runner_payout
      ? (task.runner_payout / 100).toFixed(2)
      : '0.00'

    // Fetch names for notifications
    const { data: agent } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', user.id)
      .single()

    const { data: runnerUser } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', task.runner_id)
      .single()

    // Notify runner: payment received
    await serviceClient.functions.invoke('send-notification', {
      body: {
        userId: task.runner_id,
        type: 'payment_received',
        data: {
          task_id: taskId,
          screen: 'detail',
          amount: payoutFormatted,
          category: task.category,
          address: task.property_address,
        },
      },
    })

    // Prompt both parties for reviews
    await serviceClient.functions.invoke('send-notification', {
      body: {
        userId: task.agent_id,
        type: 'review_prompt',
        data: {
          task_id: taskId,
          screen: 'review',
          other_name: runnerUser?.full_name ?? 'Runner',
          category: task.category,
          address: task.property_address,
        },
      },
    })

    await serviceClient.functions.invoke('send-notification', {
      body: {
        userId: task.runner_id,
        type: 'review_prompt',
        data: {
          task_id: taskId,
          screen: 'review',
          other_name: agent?.full_name ?? 'Agent',
          category: task.category,
          address: task.property_address,
        },
      },
    })

    return new Response(
      JSON.stringify({ task: updated }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
