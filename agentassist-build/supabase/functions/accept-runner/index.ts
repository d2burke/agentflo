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

const PLATFORM_FEE_RATE = 0.15 // 15% — make configurable per market/category in production

serve(async (req) => {
  try {
    const { applicationId } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

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

    if (!app) return new Response(JSON.stringify({ error: 'Application not found' }), { status: 404 })
    if (app.task.agent_id !== user.id) return new Response(JSON.stringify({ error: 'Not your task' }), { status: 403 })
    if (app.task.status !== 'posted') return new Response(JSON.stringify({ error: 'Task not in posted status' }), { status: 400 })
    if (app.status !== 'pending') return new Response(JSON.stringify({ error: 'Application not pending' }), { status: 400 })

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

    // TODO: Notify accepted runner
    // TODO: Notify declined runners

    return new Response(JSON.stringify({ task: updated }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
