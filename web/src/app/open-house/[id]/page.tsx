'use client'

import { use, useState } from 'react'
import { InputField } from '@/components/ui/input-field'
import { PillButton } from '@/components/ui/pill-button'
import { CheckCircle, Home } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import type { InterestLevel } from '@/types/models'

const INTEREST_OPTIONS: { value: InterestLevel; label: string }[] = [
  { value: 'just_looking', label: 'Just Looking' },
  { value: 'interested', label: 'Interested' },
  { value: 'very_interested', label: 'Very Interested' },
]

export default function OpenHouseCheckinPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: taskId } = use(params)
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
    if (!name) return

    setSubmitting(true)
    try {
      const supabase = createClient()
      const { error } = await supabase.from('open_house_visitors').insert({
        task_id: taskId,
        visitor_name: name,
        email: email || null,
        phone: phone || null,
        interest_level: interest,
        pre_approved: preApproved,
        agent_represented: hasAgent,
        representing_agent_name: hasAgent ? agentName : null,
      })
      if (error) throw error
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
