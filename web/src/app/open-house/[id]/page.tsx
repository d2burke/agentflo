'use client'

import { useState } from 'react'
import { useSearchParams } from 'next/navigation'
import { InputField } from '@/components/ui/input-field'
import { PillButton } from '@/components/ui/pill-button'
import { CheckCircle, Home } from 'lucide-react'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import type { InterestLevel } from '@/types/models'

const INTEREST_OPTIONS: { value: InterestLevel; label: string }[] = [
  { value: 'just_looking', label: 'Just Looking' },
  { value: 'interested', label: 'Interested' },
  { value: 'very_interested', label: 'Very Interested' },
]

export default function OpenHouseCheckinPage() {
  const searchParams = useSearchParams()
  const token = searchParams.get('token')?.trim() ?? ''
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [interest, setInterest] = useState<InterestLevel>('interested')
  const [preApproved, setPreApproved] = useState(false)
  const [hasAgent, setHasAgent] = useState(false)
  const [agentName, setAgentName] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const trimmedName = name.trim()
    const trimmedEmail = email.trim()
    const trimmedPhone = phone.trim()
    const trimmedAgentName = agentName.trim()

    if (!token) {
      toast.error('This check-in link is invalid or has expired.')
      return
    }

    if (!trimmedName) return

    if (!trimmedEmail && !trimmedPhone) {
      toast.error('Please provide an email or phone number.')
      return
    }

    setSubmitting(true)
    try {
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
      if (!supabaseUrl) {
        throw new Error('Check-in is not configured.')
      }

      const response = await fetch(`${supabaseUrl}/functions/v1/open-house-checkin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token,
          visitor_name: trimmedName,
          email: trimmedEmail || null,
          phone: trimmedPhone || null,
          interest_level: interest,
          pre_approved: preApproved,
          agent_represented: hasAgent,
          representing_agent_name: hasAgent && trimmedAgentName ? trimmedAgentName : null,
        }),
      })

      const payload = await response.json().catch(() => null)
      if (!response.ok) {
        throw new Error(payload?.error || 'Failed to check in')
      }

      setSubmitted(true)
    } catch (err: any) {
      toast.error(err.message || 'Failed to check in')
    } finally {
      setSubmitting(false)
    }
  }

  if (submitted) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-6">
        <div className="max-w-md w-full text-center">
          <div className="h-16 w-16 rounded-full bg-green-light text-green flex items-center justify-center mx-auto mb-4">
            <CheckCircle className="h-8 w-8" />
          </div>
          <h1 className="text-2xl font-extrabold text-navy mb-2">Welcome!</h1>
          <p className="text-sm text-slate">You&apos;re checked in. Enjoy the open house!</p>
        </div>
      </div>
    )
  }

  if (!token) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-6">
        <div className="max-w-md w-full text-center">
          <div className="h-16 w-16 rounded-full bg-red-glow text-red flex items-center justify-center mx-auto mb-4">
            <Home className="h-8 w-8" />
          </div>
          <h1 className="text-2xl font-extrabold text-navy mb-2">Invalid Check-In Link</h1>
          <p className="text-sm text-slate">Ask the host to generate a new open house QR code.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-6">
      <div className="max-w-md w-full">
        <div className="flex items-center gap-3 mb-8">
          <div className="h-10 w-10 rounded-lg bg-red flex items-center justify-center">
            <Home className="h-5 w-5 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-extrabold text-navy">Open House Check-In</h1>
            <p className="text-sm text-slate">Welcome! Please sign in below.</p>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <InputField
            label="Your Name"
            placeholder="Jane Smith"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
          <InputField
            label="Email"
            type="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <InputField
            label="Phone"
            type="tel"
            placeholder="(512) 555-1234"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
          />

          <div>
            <label className="block text-sm font-semibold text-navy mb-2">Interest Level</label>
            <div className="flex gap-2">
              {INTEREST_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => setInterest(opt.value)}
                  className={cn(
                    'flex-1 px-3 py-2 rounded-md text-xs font-semibold border transition-colors',
                    interest === opt.value
                      ? 'border-red bg-red-glow text-red'
                      : 'border-border bg-surface text-navy',
                  )}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={preApproved}
              onChange={(e) => setPreApproved(e.target.checked)}
              className="h-4 w-4 rounded border-border text-red focus:ring-red"
            />
            <span className="text-sm text-navy">Pre-approved for financing</span>
          </label>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={hasAgent}
              onChange={(e) => setHasAgent(e.target.checked)}
              className="h-4 w-4 rounded border-border text-red focus:ring-red"
            />
            <span className="text-sm text-navy">I have a real estate agent</span>
          </label>

          {hasAgent && (
            <InputField
              label="Agent Name"
              placeholder="Agent's name"
              value={agentName}
              onChange={(e) => setAgentName(e.target.value)}
            />
          )}

          <PillButton type="submit" fullWidth loading={submitting}>
            Check In
          </PillButton>
        </form>
      </div>
    </div>
  )
}
