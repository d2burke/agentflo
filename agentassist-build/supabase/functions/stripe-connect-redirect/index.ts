// supabase/functions/stripe-connect-redirect/index.ts
// Simple redirect page for Stripe Connect onboarding.
// Stripe requires https:// URLs for return/refresh — this serves a landing page
// that deep-links back into the Agent Flo iOS app.
//
// Usage:
//   return_url:  https://<project>.supabase.co/functions/v1/stripe-connect-redirect?type=return
//   refresh_url: https://<project>.supabase.co/functions/v1/stripe-connect-redirect?type=refresh

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const APP_SCHEME = 'agentflo'

serve((req) => {
  const url = new URL(req.url)
  const type = url.searchParams.get('type') ?? 'return'

  const deepLink = `${APP_SCHEME}://stripe-connect/${type}`

  const isReturn = type === 'return'
  const title = isReturn ? 'Setup Complete' : 'Continue Setup'
  const message = isReturn
    ? 'Your payout account has been set up. You can return to the app now.'
    : 'Your session expired. Tap below to restart the setup.'
  const buttonText = isReturn ? 'Return to Agent Flo' : 'Retry Setup'

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} — Agent Flo</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #F8F9FA;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
    }
    .card {
      background: white;
      border-radius: 16px;
      padding: 40px 32px;
      max-width: 400px;
      width: 100%;
      text-align: center;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
    }
    .icon { font-size: 48px; margin-bottom: 16px; }
    h1 { font-size: 22px; color: #1A1D29; margin-bottom: 8px; }
    p { font-size: 15px; color: #6B7280; line-height: 1.5; margin-bottom: 24px; }
    .btn {
      display: inline-block;
      background: #1A1D29;
      color: white;
      padding: 14px 32px;
      border-radius: 999px;
      text-decoration: none;
      font-size: 16px;
      font-weight: 600;
    }
    .btn:active { opacity: 0.8; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">${isReturn ? '✅' : '🔄'}</div>
    <h1>${title}</h1>
    <p>${message}</p>
    <a href="${deepLink}" class="btn">${buttonText}</a>
  </div>
  <script>
    // Auto-redirect to app after a brief pause
    setTimeout(function() { window.location.href = '${deepLink}'; }, 1500);
  </script>
</body>
</html>`

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
    status: 200,
  })
})
