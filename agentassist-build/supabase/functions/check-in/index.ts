// supabase/functions/check-in/index.ts
// Edge Function: Runner checks in at a task location
//
// Records the runner's arrival time and GPS coordinates.
// Transitions task from 'accepted' → 'in_progress'.
//
// Auth: Requires authenticated runner assigned to the task
// Input: { taskId: string, lat: number, lng: number }
// Output: { task: { id, status, checked_in_at } }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Only these categories use GPS check-in; others use start-task
const CHECK_IN_CATEGORIES = ['Showing', 'Staging', 'Open House']

serve(async (req) => {
  try {
    const { taskId, lat, lng } = await req.json()

    if (!taskId) {
      return new Response(JSON.stringify({ error: 'taskId is required' }), { status: 400 })
    }
    if (lat == null || lng == null) {
      return new Response(JSON.stringify({ error: 'lat and lng are required' }), { status: 400 })
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
    if (task.runner_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Not assigned to this task' }), { status: 403 })
    }
    if (task.status !== 'accepted') {
      console.error(`Check-in rejected: task ${taskId} has status ${task.status}`)
      return new Response(
        JSON.stringify({ error: 'Cannot check in to this task at this time' }),
        { status: 400 },
      )
    }
    if (!CHECK_IN_CATEGORIES.includes(task.category)) {
      return new Response(
        JSON.stringify({ error: 'This task type does not require GPS check-in. Use start-task instead.' }),
        { status: 400 },
      )
    }

    // Update task: check-in data + status → in_progress
    const now = new Date().toISOString()
    const { data: updated, error: updateError } = await serviceClient
      .from('tasks')
      .update({
        status: 'in_progress',
        checked_in_at: now,
        checked_in_lat: lat,
        checked_in_lng: lng,
      })
      .eq('id', taskId)
      .select()
      .single()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    // Fetch runner name for notification
    const { data: runner } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', user.id)
      .single()

    // Notify agent: runner has checked in
    await serviceClient.functions.invoke('send-notification', {
      body: {
        userId: task.agent_id,
        type: 'task_in_progress',
        data: {
          task_id: taskId,
          screen: 'detail',
          runner_name: runner?.full_name ?? 'Runner',
          category: task.category,
          address: task.property_address,
        },
        customTitle: 'Runner Checked In',
        customBody: `${runner?.full_name ?? 'Runner'} has arrived at ${task.property_address}`,
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
