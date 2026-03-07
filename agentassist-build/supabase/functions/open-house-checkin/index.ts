// supabase/functions/open-house-checkin/index.ts
// Edge Function: Public web-based open house visitor check-in
//
// GET  ?token=<token> → Returns self-contained HTML check-in form
// POST { token, visitor_name, email, phone, interest_level, ... } → Inserts visitor record
//
// Auth: Public (no auth required — visitors don't have accounts)
// The token maps to a task's qr_code_token column.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

const VALID_INTEREST_LEVELS = new Set(['just_looking', 'interested', 'very_interested'])

async function findActiveOpenHouseTaskByToken(serviceClient: any, token: string) {
  return await serviceClient
    .from('tasks')
    .select('id, property_address, category, agent_id, status')
    .eq('qr_code_token', token)
    .eq('category', 'Open House')
    .eq('status', 'in_progress')
    .single()
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const serviceClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  try {
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const token = url.searchParams.get('token')?.trim()

      if (!token) {
        return new Response('Missing token', { status: 400, headers: corsHeaders })
      }

      // Look up the active open house by QR token.
      const { data: task, error } = await findActiveOpenHouseTaskByToken(serviceClient, token)

      if (error || !task) {
        return new Response(renderErrorPage('Invalid or expired check-in link.'), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
        })
      }

      // Get agent name
      const { data: agent } = await serviceClient
        .from('users')
        .select('full_name, brokerage')
        .eq('id', task.agent_id)
        .single()

      const html = renderCheckInPage(token, task.property_address, agent?.full_name, agent?.brokerage)
      return new Response(html, {
        headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
      })
    }

    if (req.method === 'POST') {
      const body = await req.json()
      const rawToken = typeof body.token === 'string' ? body.token.trim() : ''
      const visitorName = typeof body.visitor_name === 'string' ? body.visitor_name.trim() : ''
      const email = typeof body.email === 'string' ? body.email.trim() : ''
      const phone = typeof body.phone === 'string' ? body.phone.trim() : ''
      const interestLevel = VALID_INTEREST_LEVELS.has(body.interest_level)
        ? body.interest_level
        : 'interested'
      const agentRepresented = body.agent_represented === true
      const representingAgentName = typeof body.representing_agent_name === 'string'
        ? body.representing_agent_name.trim()
        : ''

      if (!rawToken || !visitorName) {
        return new Response(JSON.stringify({ error: 'token and visitor_name are required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      if (!email && !phone) {
        return new Response(JSON.stringify({ error: 'Email or phone is required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      // Look up the active open house by token.
      const { data: task, error: taskError } = await findActiveOpenHouseTaskByToken(serviceClient, rawToken)

      if (taskError || !task) {
        return new Response(JSON.stringify({ error: 'Invalid or expired check-in link.' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      // Insert visitor record
      const { data: visitor, error: insertError } = await serviceClient
        .from('open_house_visitors')
        .insert({
          task_id: task.id,
          visitor_name: visitorName,
          email: email || null,
          phone: phone || null,
          interest_level: interestLevel,
          pre_approved: body.pre_approved === true,
          agent_represented: agentRepresented,
          representing_agent_name: agentRepresented && representingAgentName ? representingAgentName : null,
        })
        .select('id')
        .single()

      if (insertError) {
        return new Response(JSON.stringify({ error: insertError.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      return new Response(JSON.stringify({ success: true, visitorId: visitor.id }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

function renderCheckInPage(token: string, address: string, agentName?: string, brokerage?: string): string {
  const functionUrl = Deno.env.get('SUPABASE_URL') + '/functions/v1/open-house-checkin'
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>Open House Check-In</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F8F9FB; color: #0A1628; min-height: 100dvh; }
    .container { max-width: 420px; margin: 0 auto; padding: 24px 20px; }
    .header { text-align: center; margin-bottom: 32px; }
    .header h1 { font-size: 24px; font-weight: 700; margin-bottom: 8px; }
    .header p { font-size: 14px; color: #64748B; }
    .header .address { font-size: 16px; color: #0A1628; font-weight: 600; margin-top: 4px; }
    .header .agent { font-size: 13px; color: #94A3B8; margin-top: 4px; }
    .field { margin-bottom: 20px; }
    .field label { display: block; font-size: 13px; font-weight: 600; color: #64748B; margin-bottom: 6px; }
    .field input, .field select { width: 100%; padding: 14px 16px; font-size: 16px; border: 1.5px solid #E2E8F0; border-radius: 12px; background: #fff; appearance: none; -webkit-appearance: none; }
    .field input:focus, .field select:focus { outline: none; border-color: #C8102E; }
    .interest-row { display: flex; gap: 8px; }
    .interest-btn { flex: 1; padding: 14px 8px; border: 1.5px solid #E2E8F0; border-radius: 12px; background: #fff; font-size: 13px; font-weight: 600; text-align: center; cursor: pointer; transition: all 0.15s; }
    .interest-btn.active { background: #C8102E; color: #fff; border-color: #C8102E; }
    .toggle-row { display: flex; align-items: center; justify-content: space-between; padding: 14px 0; }
    .toggle-row label { font-size: 15px; font-weight: 500; }
    .toggle { width: 48px; height: 28px; border-radius: 14px; background: #E2E8F0; position: relative; cursor: pointer; transition: background 0.2s; }
    .toggle.on { background: #C8102E; }
    .toggle::after { content: ''; position: absolute; top: 2px; left: 2px; width: 24px; height: 24px; border-radius: 12px; background: #fff; transition: transform 0.2s; }
    .toggle.on::after { transform: translateX(20px); }
    .submit-btn { width: 100%; padding: 16px; background: #C8102E; color: #fff; font-size: 17px; font-weight: 700; border: none; border-radius: 999px; cursor: pointer; margin-top: 8px; }
    .submit-btn:disabled { opacity: 0.5; }
    .success { text-align: center; padding: 60px 20px; }
    .success .check { width: 64px; height: 64px; background: #22C55E; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; }
    .success .check svg { width: 32px; height: 32px; fill: #fff; }
    .success h2 { font-size: 24px; margin-bottom: 8px; }
    .success p { color: #64748B; font-size: 15px; }
    .privacy { font-size: 11px; color: #94A3B8; text-align: center; margin-top: 24px; line-height: 1.4; }
    .error-msg { color: #C8102E; font-size: 13px; margin-top: 8px; display: none; }
    .loading { display: none; }
    .loading.show { display: inline; }
  </style>
</head>
<body>
  <div class="container" id="form-container">
    <div class="header">
      <h1>Welcome!</h1>
      <p>Open House Check-In</p>
      <div class="address">${escapeHtml(address)}</div>
      ${agentName ? `<div class="agent">Hosted by ${escapeHtml(agentName)}${brokerage ? ' · ' + escapeHtml(brokerage) : ''}</div>` : ''}
    </div>

    <form id="checkin-form" onsubmit="return submitForm(event)">
      <div class="field">
        <label>Your Name *</label>
        <input type="text" id="visitor_name" required placeholder="Full name" autocomplete="name">
      </div>
      <div class="field">
        <label>Email</label>
        <input type="email" id="email" placeholder="email@example.com" autocomplete="email">
      </div>
      <div class="field">
        <label>Phone</label>
        <input type="tel" id="phone" placeholder="(555) 123-4567" autocomplete="tel">
      </div>
      <div class="field">
        <label>Interest Level</label>
        <div class="interest-row">
          <div class="interest-btn" onclick="setInterest(this, 'just_looking')">Just Looking</div>
          <div class="interest-btn active" onclick="setInterest(this, 'interested')">Interested</div>
          <div class="interest-btn" onclick="setInterest(this, 'very_interested')">Very Interested</div>
        </div>
      </div>
      <div class="toggle-row">
        <label>Pre-approved for financing?</label>
        <div class="toggle" id="pre_approved" onclick="toggleSwitch(this)"></div>
      </div>
      <div class="toggle-row">
        <label>Working with an agent?</label>
        <div class="toggle" id="agent_represented" onclick="toggleSwitch(this); toggleAgentName()"></div>
      </div>
      <div class="field" id="agent-name-field" style="display:none">
        <label>Agent Name</label>
        <input type="text" id="representing_agent_name" placeholder="Agent's name">
      </div>
      <div class="error-msg" id="error-msg"></div>
      <button type="submit" class="submit-btn" id="submit-btn">Check In</button>
      <div class="privacy">By checking in, you consent to sharing your contact information with the listing agent for follow-up purposes.</div>
    </form>
  </div>

  <div class="container success" id="success-container" style="display:none">
    <div class="check"><svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg></div>
    <h2>You're Checked In!</h2>
    <p>Thank you for visiting. The listing agent will follow up with you.</p>
  </div>

  <script>
    let interestLevel = 'interested';
    function setInterest(el, level) {
      document.querySelectorAll('.interest-btn').forEach(b => b.classList.remove('active'));
      el.classList.add('active');
      interestLevel = level;
    }
    function toggleSwitch(el) { el.classList.toggle('on'); }
    function toggleAgentName() {
      const f = document.getElementById('agent-name-field');
      f.style.display = document.getElementById('agent_represented').classList.contains('on') ? 'block' : 'none';
    }
    async function submitForm(e) {
      e.preventDefault();
      const email = document.getElementById('email').value.trim();
      const phone = document.getElementById('phone').value.trim();
      const errEl = document.getElementById('error-msg');
      if (!email && !phone) { errEl.textContent = 'Please provide an email or phone number.'; errEl.style.display = 'block'; return false; }
      errEl.style.display = 'none';
      const btn = document.getElementById('submit-btn');
      btn.disabled = true; btn.textContent = 'Checking in...';
      try {
        const res = await fetch('${functionUrl}', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            token: '${token}',
            visitor_name: document.getElementById('visitor_name').value.trim(),
            email: email || null, phone: phone || null,
            interest_level: interestLevel,
            pre_approved: document.getElementById('pre_approved').classList.contains('on'),
            agent_represented: document.getElementById('agent_represented').classList.contains('on'),
            representing_agent_name: document.getElementById('representing_agent_name').value.trim() || null,
          })
        });
        const data = await res.json();
        if (data.success) {
          document.getElementById('form-container').style.display = 'none';
          document.getElementById('success-container').style.display = 'block';
        } else {
          errEl.textContent = data.error || 'Something went wrong.'; errEl.style.display = 'block';
          btn.disabled = false; btn.textContent = 'Check In';
        }
      } catch (err) {
        errEl.textContent = 'Network error. Please try again.'; errEl.style.display = 'block';
        btn.disabled = false; btn.textContent = 'Check In';
      }
      return false;
    }
  </script>
</body>
</html>`
}

function renderErrorPage(message: string): string {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Error</title>
<style>body{font-family:-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100dvh;background:#F8F9FB;color:#0A1628;text-align:center;padding:20px;} h1{font-size:20px;margin-bottom:8px;} p{color:#64748B;}</style>
</head><body><div><h1>Oops!</h1><p>${escapeHtml(message)}</p></div></body></html>`
}

function escapeHtml(str: string): string {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}
