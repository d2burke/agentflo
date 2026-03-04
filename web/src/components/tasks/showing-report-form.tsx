'use client'

import { useState } from 'react'
import { InputField } from '@/components/ui/input-field'
import { PillButton } from '@/components/ui/pill-button'
import { BUYER_INTEREST_OPTIONS } from '@/lib/constants'
import { createClient } from '@/lib/supabase/client'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import type { BuyerInterest } from '@/types/models'

interface ShowingReportFormProps {
  taskId: string
  runnerId: string
  onComplete?: () => void
}

export function ShowingReportForm({ taskId, runnerId, onComplete }: ShowingReportFormProps) {
  const [buyerName, setBuyerName] = useState('')
  const [buyerInterest, setBuyerInterest] = useState<BuyerInterest>('somewhat_interested')
  const [feedback, setFeedback] = useState('')
  const [followUp, setFollowUp] = useState('')
  const [nextSteps, setNextSteps] = useState('')
  const [submitting, setSubmitting] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!buyerName) return

    setSubmitting(true)
    try {
      const supabase = createClient()
      const { error } = await supabase.from('showing_reports').insert({
        task_id: taskId,
        runner_id: runnerId,
        buyer_name: buyerName,
        buyer_interest: buyerInterest,
        property_feedback: feedback || null,
        follow_up_notes: followUp || null,
        next_steps: nextSteps || null,
      })
      if (error) throw error
      toast.success('Report submitted')
      onComplete?.()
    } catch (err: any) {
      toast.error(err.message || 'Failed to submit report')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <InputField
        label="Buyer Name"
        placeholder="Enter buyer's name"
        value={buyerName}
        onChange={(e) => setBuyerName(e.target.value)}
        required
      />

      <div>
        <label className="block text-sm font-semibold text-navy mb-2">Buyer Interest</label>
        <div className="grid grid-cols-2 gap-2">
          {BUYER_INTEREST_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              type="button"
              onClick={() => setBuyerInterest(opt.value as BuyerInterest)}
              className={cn(
                'px-3 py-2 rounded-md text-xs font-semibold border transition-colors',
                buyerInterest === opt.value
                  ? 'border-red bg-red-glow text-red'
                  : 'border-border bg-surface text-navy hover:border-red',
              )}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label className="block text-sm font-semibold text-navy mb-1.5">Property Feedback</label>
        <textarea
          className="w-full rounded-input border border-border bg-surface px-4 py-3 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/30 focus:border-red transition-colors min-h-[80px] resize-y"
          placeholder="What did the buyer think of the property?"
          value={feedback}
          onChange={(e) => setFeedback(e.target.value)}
        />
      </div>

      <div>
        <label className="block text-sm font-semibold text-navy mb-1.5">Follow Up Notes</label>
        <textarea
          className="w-full rounded-input border border-border bg-surface px-4 py-3 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/30 focus:border-red transition-colors min-h-[80px] resize-y"
          placeholder="Any follow-up actions needed?"
          value={followUp}
          onChange={(e) => setFollowUp(e.target.value)}
        />
      </div>

      <InputField
        label="Next Steps"
        placeholder="Recommended next steps"
        value={nextSteps}
        onChange={(e) => setNextSteps(e.target.value)}
      />

      <PillButton type="submit" fullWidth loading={submitting}>
        Submit Report
      </PillButton>
    </form>
  )
}
