// supabase/functions/submit-deliverables/index.ts
// Edge Function: Runner submits deliverables for a task
//
// Business Logic:
//   1. Validate: runner_id = auth user, task.status = 'in_progress' or 'revision_requested'
//   2. Validate deliverable entries (type, file_url required)
//   3. Insert deliverable records into deliverables table
//   4. Update task: status → 'deliverables_submitted'
//   5. Notify agent: "Deliverables ready for review"
//
// Auth: Requires authenticated runner assigned to the task
// Input: { taskId: string, deliverables: [{ type, file_url, title, notes, sort_order }] }
// Output: { task: { id, status }, deliverables: [{ id, file_url, title }] }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const VALID_TYPES = ['photo', 'document', 'report', 'checklist']

serve(async (req) => {
  try {
    const { taskId, deliverables } = await req.json()

    if (!taskId) {
      return new Response(
        JSON.stringify({ error: 'taskId is required' }),
        { status: 400 },
      )
    }

    const hasDeliverables = Array.isArray(deliverables) && deliverables.length > 0

    // Validate deliverable entries only if provided
    if (hasDeliverables) {
      for (const d of deliverables) {
        if (!d.type || !VALID_TYPES.includes(d.type)) {
          return new Response(
            JSON.stringify({ error: `Invalid deliverable type: ${d.type}. Must be one of: ${VALID_TYPES.join(', ')}` }),
            { status: 400 },
          )
        }
        if (!d.file_url && d.type !== 'checklist') {
          return new Response(
            JSON.stringify({ error: 'Each non-checklist deliverable must have a file_url' }),
            { status: 400 },
          )
        }
      }
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

    // Fetch task and validate
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
    if (task.status !== 'in_progress' && task.status !== 'revision_requested') {
      console.error(`Submit deliverables rejected: task ${taskId} has status ${task.status}`)
      return new Response(
        JSON.stringify({ error: 'Deliverables cannot be submitted for this task at this time' }),
        { status: 400 },
      )
    }

    // Insert deliverable records (if any provided)
    let inserted: any[] = []
    if (hasDeliverables) {
      const records = deliverables.map((d: any, i: number) => ({
        task_id: taskId,
        runner_id: user.id,
        type: d.type,
        file_url: d.file_url,
        thumbnail_url: d.thumbnail_url ?? null,
        title: d.title ?? null,
        notes: d.notes ?? null,
        sort_order: d.sort_order ?? i + 1,
      }))

      const { data, error: insertError } = await serviceClient
        .from('deliverables')
        .insert(records)
        .select()

      if (insertError) {
        return new Response(JSON.stringify({ error: insertError.message }), { status: 500 })
      }
      inserted = data ?? []
    }

    // Update task status
    const { data: updated, error: updateError } = await serviceClient
      .from('tasks')
      .update({ status: 'deliverables_submitted' })
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

    // Notify agent
    await serviceClient.functions.invoke('send-notification', {
      body: {
        userId: task.agent_id,
        type: 'deliverables_ready',
        data: {
          task_id: taskId,
          screen: 'detail',
          runner_name: runner?.full_name ?? 'Runner',
          address: task.property_address,
        },
      },
    })

    return new Response(
      JSON.stringify({ task: updated, deliverables: inserted }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
