// supabase/functions/submit-vetting/index.ts
// Edge Function: User submits vetting records (license, photo ID, brokerage)
//
// Business Logic:
//   1. Auth check: verify caller is authenticated
//   2. Validate input: record type, submitted_data, optional file_url
//   3. Upsert vetting_record for the user (if rejected, allow resubmission)
//   4. Update users.vetting_status to 'pending' if not already
//   5. Update users license/brokerage fields for quick access
//
// Auth: Requires authenticated user
// Input: { type: 'license'|'photo_id'|'brokerage', submittedData: Record<string, string> }
// Output: { success: true, record: VettingRecord }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCorsPreFlight, getCorsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/rate-limit.ts'
import { sanitizeString } from '../_shared/validation.ts'

const VALID_TYPES = ['license', 'photo_id', 'brokerage']

serve(async (req) => {
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse
  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    const { type, submittedData } = await req.json()

    // Validate type
    if (!type || !VALID_TYPES.includes(type)) {
      return new Response(
        JSON.stringify({ error: `type must be one of: ${VALID_TYPES.join(', ')}` }),
        { status: 400, headers },
      )
    }

    // Validate submittedData exists
    if (!submittedData || typeof submittedData !== 'object') {
      return new Response(
        JSON.stringify({ error: 'submittedData object is required' }),
        { status: 400, headers },
      )
    }

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

    // Rate limit
    const rateLimitResponse = await checkRateLimit(user.id, 'write')
    if (rateLimitResponse) return rateLimitResponse

    // Service role client for privileged operations
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Sanitize all string values in submittedData
    const sanitizedData: Record<string, string> = {}
    for (const [key, value] of Object.entries(submittedData)) {
      if (typeof value === 'string') {
        sanitizedData[sanitizeString(key, 50)] = sanitizeString(value as string, 500)
      }
    }

    // Validate type-specific required fields
    if (type === 'license') {
      if (!sanitizedData.license_number || !sanitizedData.state) {
        return new Response(
          JSON.stringify({ error: 'license_number and state are required for license type' }),
          { status: 400, headers },
        )
      }
      if (!/^[A-Z]{2}$/.test(sanitizedData.state)) {
        return new Response(
          JSON.stringify({ error: 'state must be a 2-letter uppercase code (e.g., TX, VA)' }),
          { status: 400, headers },
        )
      }
    }

    if (type === 'photo_id') {
      if (!sanitizedData.file_url) {
        return new Response(
          JSON.stringify({ error: 'file_url is required for photo_id type' }),
          { status: 400, headers },
        )
      }
    }

    if (type === 'brokerage') {
      if (!sanitizedData.brokerage_name) {
        return new Response(
          JSON.stringify({ error: 'brokerage_name is required for brokerage type' }),
          { status: 400, headers },
        )
      }
    }

    // Check for existing record of this type (for resubmission)
    const { data: existingRecords } = await serviceClient
      .from('vetting_records')
      .select('id, status')
      .eq('user_id', user.id)
      .eq('type', type)

    let record
    const existingRecord = existingRecords?.[0]

    if (existingRecord && existingRecord.status === 'rejected') {
      // Resubmission: update the rejected record back to pending
      const { data, error } = await serviceClient
        .from('vetting_records')
        .update({
          status: 'pending',
          submitted_data: sanitizedData,
          reviewer_notes: null,
          reviewed_by: null,
          reviewed_at: null,
        })
        .eq('id', existingRecord.id)
        .select()
        .single()

      if (error) throw error
      record = data
    } else if (existingRecord && existingRecord.status === 'pending') {
      // Already pending — update the submitted data
      const { data, error } = await serviceClient
        .from('vetting_records')
        .update({ submitted_data: sanitizedData })
        .eq('id', existingRecord.id)
        .select()
        .single()

      if (error) throw error
      record = data
    } else if (existingRecord && existingRecord.status === 'approved') {
      // Already approved — no resubmission needed
      return new Response(
        JSON.stringify({ error: 'This record type is already approved' }),
        { status: 400, headers },
      )
    } else {
      // New record
      const { data, error } = await serviceClient
        .from('vetting_records')
        .insert({
          user_id: user.id,
          type,
          status: 'pending',
          submitted_data: sanitizedData,
        })
        .select()
        .single()

      if (error) throw error
      record = data
    }

    // Update user fields for quick access
    const userUpdate: Record<string, unknown> = { updated_at: new Date().toISOString() }

    if (type === 'license') {
      userUpdate.license_number = sanitizedData.license_number
      userUpdate.license_state = sanitizedData.state
    }

    if (type === 'brokerage') {
      userUpdate.brokerage = sanitizedData.brokerage_name
    }

    // Update vetting_status to 'pending' if currently 'not_started' or 'rejected'
    const { data: currentUser } = await serviceClient
      .from('users')
      .select('vetting_status')
      .eq('id', user.id)
      .single()

    if (currentUser && (currentUser.vetting_status === 'not_started' || currentUser.vetting_status === 'rejected')) {
      userUpdate.vetting_status = 'pending'
    }

    await serviceClient
      .from('users')
      .update(userUpdate)
      .eq('id', user.id)

    return new Response(
      JSON.stringify({ success: true, record }),
      { headers },
    )
  } catch (err) {
    console.error('[submit-vetting] Error:', err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers })
  }
})
