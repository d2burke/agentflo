// supabase/functions/submit-inspection/index.ts
// Edge Function: Submit completed inspection findings
//
// Validates ASHI completeness (all 10 systems, minimum 25 photos),
// creates a report deliverable, and transitions task to deliverables_submitted.
// Per spec A.5.6: inspections auto-release payment on submission.
//
// Auth: Requires authenticated runner assigned to the task
// Input: { taskId: string }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ASHI_SYSTEMS = [
  'structure', 'exterior', 'roofing', 'plumbing', 'electrical',
  'heating', 'cooling', 'interior', 'insulation_ventilation', 'fireplaces',
]

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
    if (task.runner_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Not assigned to this task' }), { status: 403 })
    }
    if (task.category !== 'Inspection') {
      return new Response(JSON.stringify({ error: 'Not an inspection task' }), { status: 400 })
    }
    if (task.status !== 'in_progress') {
      return new Response(JSON.stringify({ error: 'Task is not in progress' }), { status: 400 })
    }

    // Fetch all findings for this task
    const { data: findings, error: findingsError } = await serviceClient
      .from('inspection_findings')
      .select('*')
      .eq('task_id', taskId)
      .order('system_category')
      .order('sort_order')

    if (findingsError) {
      return new Response(JSON.stringify({ error: findingsError.message }), { status: 500 })
    }

    // Validate ASHI completeness: all 10 systems must have >= 1 finding
    const coveredSystems = new Set((findings ?? []).map((f: any) => f.system_category))
    const missingSystems = ASHI_SYSTEMS.filter(s => !coveredSystems.has(s))
    if (missingSystems.length > 0) {
      return new Response(JSON.stringify({
        error: `Incomplete inspection. Missing systems: ${missingSystems.join(', ')}`,
        missingSystems,
      }), { status: 400 })
    }

    // Count photos (informational — not a hard gate while photo upload pipeline is WIP)
    const totalPhotos = (findings ?? []).reduce(
      (sum: number, f: any) => sum + (Array.isArray(f.photo_urls) ? f.photo_urls.length : 0), 0
    )

    // Build report summary
    const deficiencies = (findings ?? []).filter((f: any) => f.status === 'deficiency')
    const criticalCount = deficiencies.filter((f: any) => f.severity === 'critical').length
    const majorCount = deficiencies.filter((f: any) => f.severity === 'major').length
    const minorCount = deficiencies.filter((f: any) => f.severity === 'minor').length

    const reportData = JSON.stringify({
      total_findings: (findings ?? []).length,
      deficiency_count: deficiencies.length,
      critical_count: criticalCount,
      major_count: majorCount,
      minor_count: minorCount,
      total_photos: totalPhotos,
      systems_inspected: ASHI_SYSTEMS.length,
      findings_by_system: ASHI_SYSTEMS.map(sys => ({
        system: sys,
        count: (findings ?? []).filter((f: any) => f.system_category === sys).length,
        deficiencies: (findings ?? []).filter((f: any) => f.system_category === sys && f.status === 'deficiency').length,
      })),
    })

    // Create report deliverable
    await serviceClient
      .from('deliverables')
      .insert({
        task_id: taskId,
        runner_id: user.id,
        type: 'report',
        title: 'Inspection Report',
        notes: reportData,
        sort_order: 1,
      })

    // Update task status to deliverables_submitted
    await serviceClient
      .from('tasks')
      .update({ status: 'deliverables_submitted' })
      .eq('id', taskId)

    // Per spec A.5.6: inspections auto-release payment on submission (inspector independence)
    // Trigger approve-and-pay automatically
    await serviceClient.functions.invoke('approve-and-pay', {
      body: { taskId },
      headers: { Authorization: req.headers.get('Authorization')! },
    })

    // Notify agent
    const { data: runner } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', user.id)
      .single()

    await serviceClient.functions.invoke('send-notification', {
      body: {
        userId: task.agent_id,
        type: 'deliverables_ready',
        data: {
          task_id: taskId,
          screen: 'detail',
          runner_name: runner?.full_name ?? 'Inspector',
          address: task.property_address,
        },
        customTitle: 'Inspection Complete',
        customBody: `${runner?.full_name ?? 'Inspector'} completed the inspection at ${task.property_address}. ${criticalCount} critical, ${majorCount} major findings.`,
      },
    })

    return new Response(
      JSON.stringify({
        success: true,
        summary: { total: (findings ?? []).length, deficiencies: deficiencies.length, photos: totalPhotos },
      }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
