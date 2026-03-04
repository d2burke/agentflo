// supabase/functions/check-out/index.ts
// Edge Function: Runner checks out from a check-in/check-out task
//
// For Showing, Staging, and Open House categories where the deliverable
// is the runner's presence. Records departure time + GPS, creates a
// checklist deliverable, and transitions to 'deliverables_submitted'.
//
// Auth: Requires authenticated runner assigned to the task
// Input: { taskId: string, lat: number, lng: number }
// Output: { task: { id, status, checked_out_at }, deliverable: { id } }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CHECK_IN_OUT_CATEGORIES = ['Showing', 'Staging', 'Open House']

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
    if (task.status !== 'in_progress') {
      console.error(`Check-out rejected: task ${taskId} has status ${task.status}`)
      return new Response(
        JSON.stringify({ error: 'Cannot check out from this task at this time' }),
        { status: 400 },
      )
    }
    if (!CHECK_IN_OUT_CATEGORIES.includes(task.category)) {
      return new Response(
        JSON.stringify({ error: 'Check-out is only for Showing, Staging, and Open House tasks' }),
        { status: 400 },
      )
    }

    const now = new Date().toISOString()

    // Calculate duration
    const checkedInAt = task.checked_in_at ? new Date(task.checked_in_at) : null
    const checkedOutAt = new Date(now)
    const durationMinutes = checkedInAt
      ? Math.round((checkedOutAt.getTime() - checkedInAt.getTime()) / 60000)
      : null

    // Update task: check-out data + status → deliverables_submitted
    const { data: updated, error: updateError } = await serviceClient
      .from('tasks')
      .update({
        status: 'deliverables_submitted',
        checked_out_at: now,
        checked_out_lat: lat,
        checked_out_lng: lng,
      })
      .eq('id', taskId)
      .select()
      .single()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    // Insert a checklist deliverable with the check-in/check-out record
    const notes = JSON.stringify({
      checked_in_at: task.checked_in_at,
      checked_in_lat: task.checked_in_lat,
      checked_in_lng: task.checked_in_lng,
      checked_out_at: now,
      checked_out_lat: lat,
      checked_out_lng: lng,
      duration_minutes: durationMinutes,
    })

    const { data: deliverable } = await serviceClient
      .from('deliverables')
      .insert({
        task_id: taskId,
        runner_id: user.id,
        type: 'checklist',
        title: 'Check-in / Check-out Record',
        notes,
        sort_order: 1,
      })
      .select('id')
      .single()

    // For Open House tasks: create visitor report deliverable
    if (task.category === 'Open House') {
      const { data: visitors } = await serviceClient
        .from('open_house_visitors')
        .select('*')
        .eq('task_id', taskId)
        .order('created_at', { ascending: true })

      const visitorList = visitors ?? []
      const visitorReport = JSON.stringify({
        total_visitors: visitorList.length,
        pre_approved_count: visitorList.filter((v: any) => v.pre_approved).length,
        very_interested_count: visitorList.filter((v: any) => v.interest_level === 'very_interested').length,
        visitors: visitorList.map((v: any) => ({
          name: v.visitor_name,
          email: v.email,
          phone: v.phone,
          interest_level: v.interest_level,
          pre_approved: v.pre_approved,
          agent_represented: v.agent_represented,
          representing_agent_name: v.representing_agent_name,
          checked_in_at: v.created_at,
        })),
      })

      await serviceClient
        .from('deliverables')
        .insert({
          task_id: taskId,
          runner_id: user.id,
          type: 'report',
          title: 'Open House Visitor Report',
          notes: visitorReport,
          sort_order: 2,
        })
    }

    // Fetch runner name for notification
    const { data: runner } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', user.id)
      .single()

    // Notify agent: runner has checked out
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
        customTitle: 'Runner Checked Out',
        customBody: `${runner?.full_name ?? 'Runner'} checked out from ${task.property_address}${durationMinutes ? ` (${durationMinutes} min)` : ''}`,
      },
    })

    return new Response(
      JSON.stringify({ task: updated, deliverable }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
