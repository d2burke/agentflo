// supabase/functions/approve-and-pay/index.ts
// Edge Function: Agent approves deliverables and triggers payment
//
// Fee Model (agent pays):
//   - task.price       = runner's pay (what the agent set when creating the task)
//   - task.platform_fee = 15% of price (service fee, charged to agent on top)
//   - task.runner_payout = price (runner gets the full amount)
//   - PaymentIntent amount = price + platform_fee (total agent charge)
//
// Business Logic:
//   1. Validate: task.agent_id = auth user, task.status = 'deliverables_submitted'
//   2. Capture the Stripe PaymentIntent (amount = price + platform_fee)
//   3. Transfer runner_payout (= price) to runner's Connect account
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
      console.error(`Approve rejected: task ${taskId} has status ${task.status}`)
      return new Response(
        JSON.stringify({ error: 'This task cannot be approved at this time' }),
        { status: 400 },
      )
    }

    // Verify deliverables exist before capturing payment
    const { count: deliverableCount } = await serviceClient
      .from('deliverables')
      .select('*', { count: 'exact', head: true })
      .eq('task_id', taskId)

    // For check-in/check-out categories, check-out data on the task counts as a deliverable
    const isCheckInOut = ['Showing', 'Staging', 'Open House'].includes(task.category)
    if ((!deliverableCount || deliverableCount === 0) && !(isCheckInOut && task.checked_out_at)) {
      return new Response(
        JSON.stringify({ error: 'No deliverables found for this task' }),
        { status: 400 },
      )
    }

    // Capture Stripe PaymentIntent
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    if (stripeKey && task.stripe_payment_intent_id) {
      const stripe = new Stripe(stripeKey, { apiVersion: '2023-10-16' })

      // Capture the held payment (idempotency key prevents double-capture)
      await stripe.paymentIntents.capture(task.stripe_payment_intent_id, {}, {
        idempotencyKey: `approve-${taskId}`,
      })

      // Transfer runner payout to their Connect account
      if (task.runner_payout && task.runner_id) {
        const { data: runner } = await serviceClient
          .from('users')
          .select('stripe_connect_id')
          .eq('id', task.runner_id)
          .single()

        if (!runner?.stripe_connect_id) {
          console.error(`Runner ${task.runner_id} has no stripe_connect_id — cannot transfer payout`)
          return new Response(
            JSON.stringify({
              error: 'Runner has not set up their payout method. Payment was captured but payout cannot be transferred. Please contact the runner to set up payouts.',
            }),
            { headers: { 'Content-Type': 'application/json' }, status: 400 },
          )
        }

        // Idempotency key prevents duplicate transfers on retry
        await stripe.transfers.create({
          amount: task.runner_payout,
          currency: 'usd',
          destination: runner.stripe_connect_id,
          transfer_group: taskId,
          metadata: { task_id: taskId },
        }, {
          idempotencyKey: `transfer-${taskId}`,
        })
      }
    }

    // Update task status — atomic check prevents race condition
    const { data: updated, error: updateError } = await serviceClient
      .from('tasks')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
      })
      .eq('id', taskId)
      .eq('status', 'deliverables_submitted')
      .select()
      .single()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    // Format payout amount for notification
    const payoutFormatted = task.runner_payout
      ? (task.runner_payout / 100).toFixed(2)
      : '0.00'

    // Fetch names for notifications (batched query)
    const { data: users } = await serviceClient
      .from('users')
      .select('id, full_name')
      .in('id', [user.id, task.runner_id])

    const userMap = Object.fromEntries((users ?? []).map((u: any) => [u.id, u.full_name]))
    const agentName = userMap[user.id] ?? 'Agent'
    const runnerName = userMap[task.runner_id] ?? 'Runner'

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
          other_name: runnerName,
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
          other_name: agentName,
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
