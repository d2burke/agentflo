// supabase/functions/cancel-task/index.ts
// Edge Function: Either party cancels a task
//
// Business Logic:
//   1. Validate: caller is agent_id or runner_id, status is cancellable
//   2. Evaluate cancellation fee rules:
//      - draft/posted: no fee, void PaymentIntent
//      - accepted: partial refund, small fee
//      - in_progress: larger fee, partial refund
//   3. Void or refund Stripe PaymentIntent
//   4. Update task: status → 'cancelled', set cancelled_at, cancellation_reason
//   5. Notify the other party
//
// Auth: Requires authenticated user who is agent or runner on the task
// Input: { taskId: string, reason: string }
// Output: { task: { id, status, cancelled_at } }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.14.0?target=deno'

const CANCELLABLE_STATUSES = ['draft', 'posted', 'accepted', 'in_progress']

serve(async (req) => {
  try {
    const { taskId, reason } = await req.json()

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

    // Validate caller is agent or runner on this task
    const isAgent = task.agent_id === user.id
    const isRunner = task.runner_id === user.id
    if (!isAgent && !isRunner) {
      return new Response(JSON.stringify({ error: 'Not authorized to cancel this task' }), { status: 403 })
    }

    // Runners can only cancel tasks they've accepted or are working on
    if (isRunner && !['accepted', 'in_progress'].includes(task.status)) {
      console.error(`Runner ${user.id} attempted to cancel task ${taskId} in status ${task.status}`)
      return new Response(JSON.stringify({ error: 'This task cannot be cancelled at this time' }), { status: 400 })
    }

    // Validate status is cancellable
    if (!CANCELLABLE_STATUSES.includes(task.status)) {
      console.error(`Cancel rejected: task ${taskId} has status ${task.status}`)
      return new Response(JSON.stringify({ error: 'This task cannot be cancelled at this time' }), { status: 400 })
    }

    // Handle Stripe PaymentIntent based on status
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    if (stripeKey && task.stripe_payment_intent_id) {
      const stripe = new Stripe(stripeKey, { apiVersion: '2023-10-16' })

      if (task.status === 'draft' || task.status === 'posted') {
        // No fee — cancel/void the PaymentIntent
        await stripe.paymentIntents.cancel(task.stripe_payment_intent_id)
      } else if (task.status === 'accepted' || task.status === 'in_progress') {
        // For accepted/in_progress, cancel the uncaptured PaymentIntent
        // Cancellation fees would be handled separately if needed
        await stripe.paymentIntents.cancel(task.stripe_payment_intent_id)
      }
    }

    // Update task
    const { data: updated, error: updateError } = await serviceClient
      .from('tasks')
      .update({
        status: 'cancelled',
        cancelled_at: new Date().toISOString(),
        cancellation_reason: reason ?? null,
      })
      .eq('id', taskId)
      .select()
      .single()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    // Decline any pending applications
    await serviceClient
      .from('task_applications')
      .update({ status: 'declined' })
      .eq('task_id', taskId)
      .eq('status', 'pending')

    // Notify the other party
    const cancelledByRole = isAgent ? 'agent' : 'runner'
    const notifyUserId = isAgent ? task.runner_id : task.agent_id

    if (notifyUserId) {
      const { data: canceller } = await serviceClient
        .from('users')
        .select('full_name')
        .eq('id', user.id)
        .single()

      await serviceClient.functions.invoke('send-notification', {
        body: {
          userId: notifyUserId,
          type: 'task_cancelled',
          data: {
            task_id: taskId,
            screen: 'detail',
            category: task.category,
            address: task.property_address,
            reason: reason ?? `Cancelled by ${cancelledByRole}`,
          },
        },
      })
    }

    return new Response(
      JSON.stringify({ task: updated }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
