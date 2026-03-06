// supabase/functions/accept-runner/index.ts
// Edge Function: Agent accepts a runner's application for a task
//
// Business Logic:
//   1. Validate: task belongs to agent, task.status = 'posted', application.status = 'pending'
//   2. Update application status → 'accepted'
//   3. Assign runner_id to task, update task status → 'accepted', set accepted_at
//   4. Decline all other pending applications for this task
//   5. Calculate platform_fee and runner_payout (price * fee_percentage)
//   6. Notify accepted runner (send-notification)
//   7. Notify declined runners (send-notification)
//
// Auth: Requires authenticated agent who owns the task
// Input: { applicationId: string }
// Output: { task: { id, status, runner_id, accepted_at } }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCorsPreFlight, getCorsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/rate-limit.ts'
import { isValidUUID } from '../_shared/validation.ts'

const PLATFORM_FEE_RATE = 0.15 // 15% — make configurable per market/category in production

serve(async (req) => {
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse
  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    const { applicationId } = await req.json()

    if (!isValidUUID(applicationId)) {
      return new Response(JSON.stringify({ error: 'Invalid applicationId' }), { status: 400, headers })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers })

    const rateLimitResponse = await checkRateLimit(user.id, 'write')
    if (rateLimitResponse) return rateLimitResponse

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch application with task
    const { data: app } = await serviceClient
      .from('task_applications')
      .select('*, task:tasks(*)')
      .eq('id', applicationId)
      .single()

    if (!app) return new Response(JSON.stringify({ error: 'Application not found' }), { status: 404, headers })
    if (app.task.agent_id !== user.id) return new Response(JSON.stringify({ error: 'Not your task' }), { status: 403, headers })
    if (app.task.status !== 'posted') return new Response(JSON.stringify({ error: 'Task not in posted status' }), { status: 400, headers })
    if (app.status !== 'pending') return new Response(JSON.stringify({ error: 'Application not pending' }), { status: 400, headers })

    const fee = Math.round(app.task.price * PLATFORM_FEE_RATE)

    // Accept application
    await serviceClient.from('task_applications').update({ status: 'accepted' }).eq('id', applicationId)

    // Decline others
    await serviceClient.from('task_applications')
      .update({ status: 'declined' })
      .eq('task_id', app.task_id)
      .neq('id', applicationId)
      .eq('status', 'pending')

    // Update task
    const { data: updated } = await serviceClient.from('tasks')
      .update({
        status: 'accepted',
        runner_id: app.runner_id,
        accepted_at: new Date().toISOString(),
        platform_fee: fee,
        runner_payout: app.task.price - fee,
      })
      .eq('id', app.task_id)
      .select()
      .single()

    // Fetch agent name for notification
    const { data: agent } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', user.id)
      .single()

    const agentName = agent?.full_name ?? 'An agent'
    const notifyUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notification`
    const notifyHeaders = {
      Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
      'Content-Type': 'application/json',
    }

    // Notify accepted runner
    try {
      await fetch(notifyUrl, {
        method: 'POST',
        headers: notifyHeaders,
        body: JSON.stringify({
          userId: app.runner_id,
          type: 'task_accepted',
          data: {
            agent_name: agentName,
            category: app.task.category,
            address: app.task.property_address,
            task_id: app.task_id,
          },
        }),
      })
    } catch (e) {
      console.error('[accept-runner] Failed to notify accepted runner:', e)
    }

    // Notify declined runners
    const { data: declined } = await serviceClient
      .from('task_applications')
      .select('runner_id')
      .eq('task_id', app.task_id)
      .eq('status', 'declined')

    for (const d of declined ?? []) {
      try {
        await fetch(notifyUrl, {
          method: 'POST',
          headers: notifyHeaders,
          body: JSON.stringify({
            userId: d.runner_id,
            type: 'task_cancelled',
            data: {
              category: app.task.category,
              address: app.task.property_address,
              reason: 'Another runner was selected.',
              task_id: app.task_id,
            },
          }),
        })
      } catch (e) {
        console.error('[accept-runner] Failed to notify declined runner:', e)
      }
    }

    return new Response(JSON.stringify({ task: updated }), { headers })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers })
  }
})
