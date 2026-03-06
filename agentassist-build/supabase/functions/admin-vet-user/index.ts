// supabase/functions/admin-vet-user/index.ts
// Edge Function: Admin approves or rejects a user's vetting
//
// Business Logic:
//   1. Auth check: verify caller is authenticated
//   2. Admin check: verify caller has is_admin = true
//   3. Fetch target user and their vetting records
//   4. Approve: update all pending vetting_records + users.vetting_status
//   5. Reject: update all pending vetting_records + users.vetting_status
//   6. Send notification to the user
//
// Auth: Requires authenticated admin user
// Input: { userId: string, action: 'approve' | 'reject', reviewerNotes?: string }
// Output: { success: true, vetting_status: 'approved' | 'rejected' }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCorsPreFlight, getCorsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/rate-limit.ts'
import { isValidUUID, sanitizeString } from '../_shared/validation.ts'

serve(async (req) => {
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse
  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    const { userId, action, reviewerNotes } = await req.json()

    if (!userId || !action) {
      return new Response(
        JSON.stringify({ error: 'userId and action are required' }),
        { status: 400, headers },
      )
    }

    if (!isValidUUID(userId)) {
      return new Response(
        JSON.stringify({ error: 'Invalid userId format' }),
        { status: 400, headers },
      )
    }

    if (action !== 'approve' && action !== 'reject') {
      return new Response(
        JSON.stringify({ error: 'action must be "approve" or "reject"' }),
        { status: 400, headers },
      )
    }

    // Sanitize optional reviewerNotes
    const sanitizedReviewerNotes = reviewerNotes ? sanitizeString(reviewerNotes, 1000) : reviewerNotes

    // Auth client (caller context)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
    )

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers })
    }

    // Service role client (for privileged operations)
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Verify caller is admin
    const { data: adminUser } = await serviceClient
      .from('users')
      .select('id, is_admin')
      .eq('id', user.id)
      .single()

    if (!adminUser?.is_admin) {
      return new Response(JSON.stringify({ error: 'Forbidden: admin access required' }), { status: 403, headers })
    }

    // Rate limit check (after auth verification)
    const rateLimitResponse = await checkRateLimit(user.id, 'write')
    if (rateLimitResponse) return rateLimitResponse

    // Fetch target user
    const { data: targetUser } = await serviceClient
      .from('users')
      .select('id, full_name, role, vetting_status')
      .eq('id', userId)
      .single()

    if (!targetUser) {
      return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers })
    }

    const newVettingStatus = action === 'approve' ? 'approved' : 'rejected'
    const newRecordStatus = action === 'approve' ? 'approved' : 'rejected'
    const now = new Date().toISOString()

    // Update all pending vetting records for this user
    await serviceClient
      .from('vetting_records')
      .update({
        status: newRecordStatus,
        reviewer_notes: sanitizedReviewerNotes || null,
        reviewed_by: user.id,
        reviewed_at: now,
      })
      .eq('user_id', userId)
      .eq('status', 'pending')

    // Update user's vetting_status
    await serviceClient
      .from('users')
      .update({ vetting_status: newVettingStatus, updated_at: now })
      .eq('id', userId)

    // Send notification to the user
    const notificationType = action === 'approve' ? 'vetting_approved' : 'vetting_rejected'
    const roleAction = targetUser.role === 'agent' ? 'post tasks' : 'apply to tasks'

    try {
      await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notification`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          userId,
          type: notificationType,
          data: {
            action: roleAction,
            reason: sanitizedReviewerNotes || '',
          },
        }),
      })
    } catch (e) {
      // Non-blocking: notification failure shouldn't fail the vetting operation
      console.error('[admin-vet-user] Failed to send notification:', e)
    }

    return new Response(
      JSON.stringify({ success: true, vetting_status: newVettingStatus }),
      { headers },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers })
  }
})
