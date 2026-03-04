'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Camera, Eye, Box, Home, ClipboardCheck, ArrowLeft } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { InputField } from '@/components/ui/input-field'
import { useAppStore } from '@/stores/app-store'
import { taskService } from '@/services/task-service'
import { usePostTask } from '@/hooks/use-tasks'
import { TASK_CATEGORIES, PLATFORM_FEE_RATE } from '@/lib/constants'
import { formatPrice, cn } from '@/lib/utils'
import { toast } from 'sonner'
import type { TaskCategory } from '@/types/models'

const CATEGORY_ICONS: Record<TaskCategory, React.ReactNode> = {
  Photography: <Camera className="h-5 w-5" />,
  Showing: <Eye className="h-5 w-5" />,
  Staging: <Box className="h-5 w-5" />,
  'Open House': <Home className="h-5 w-5" />,
  Inspection: <ClipboardCheck className="h-5 w-5" />,
}

export default function NewTaskPage() {
  const { user } = useAppStore()
  const router = useRouter()

  const [step, setStep] = useState<'category' | 'form'>('category')
  const [category, setCategory] = useState<TaskCategory | null>(null)

  if (!user) return null

  function selectCategory(cat: TaskCategory) {
    setCategory(cat)
    setStep('form')
  }

  if (step === 'category') {
    return (
      <div className="max-w-2xl">
        <button
          onClick={() => router.back()}
          className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
        >
          <ArrowLeft className="h-4 w-4" /> Back
        </button>

        <h1 className="text-2xl font-extrabold text-navy mb-1">Create a Task</h1>
        <p className="text-sm text-slate mb-8">What do you need help with?</p>

        <div className="grid gap-3 sm:grid-cols-2">
          {(Object.entries(TASK_CATEGORIES) as [TaskCategory, (typeof TASK_CATEGORIES)[TaskCategory]][]).map(
            ([key, meta]) => (
              <button
                key={key}
                onClick={() => selectCategory(key)}
                className="flex items-start gap-4 border border-border rounded-card p-5 bg-surface text-left transition-all hover:border-red hover:shadow-card-hover"
              >
                <div className="h-10 w-10 rounded-md bg-red-glow text-red flex items-center justify-center shrink-0">
                  {CATEGORY_ICONS[key]}
                </div>
                <div className="min-w-0">
                  <h3 className="text-sm font-bold text-navy">{meta.label}</h3>
                  <p className="text-xs text-slate mt-0.5">{meta.description}</p>
                  <p className="text-xs text-blue font-medium mt-1">{meta.suggestedPrice}</p>
                </div>
              </button>
            ),
          )}
        </div>
      </div>
    )
  }

  return (
    <TaskForm
      category={category!}
      agentId={user.id}
      onBack={() => setStep('category')}
    />
  )
}

function TaskForm({
  category,
  agentId,
  onBack,
}: {
  category: TaskCategory
  agentId: string
  onBack: () => void
}) {
  const router = useRouter()
  const postTask = usePostTask()

  const [address, setAddress] = useState('')
  const [scheduledDate, setScheduledDate] = useState('')
  const [scheduledTime, setScheduledTime] = useState('')
  const [priceInput, setPriceInput] = useState('')
  const [instructions, setInstructions] = useState('')
  const [saving, setSaving] = useState(false)
  const [posting, setPosting] = useState(false)

  const priceInCents = Math.round((parseFloat(priceInput) || 0) * 100)
  const fee = Math.round(priceInCents * PLATFORM_FEE_RATE)
  const total = priceInCents + fee

  function getScheduledAt(): string | null {
    if (!scheduledDate) return null
    const time = scheduledTime || '12:00'
    return new Date(`${scheduledDate}T${time}`).toISOString()
  }

  async function handleSaveDraft() {
    if (!address || priceInCents <= 0) {
      toast.error('Please enter an address and price')
      return
    }
    setSaving(true)
    try {
      await taskService.createDraft({
        agentId,
        category,
        propertyAddress: address,
        price: priceInCents,
        instructions: instructions || null,
        scheduledAt: getScheduledAt(),
      })
      toast.success('Draft saved')
      router.push('/tasks')
    } catch (err: any) {
      toast.error(err.message || 'Failed to save draft')
    } finally {
      setSaving(false)
    }
  }

  async function handlePostTask() {
    if (!address || priceInCents <= 0) {
      toast.error('Please enter an address and price')
      return
    }
    setPosting(true)
    try {
      const task = await taskService.createDraft({
        agentId,
        category,
        propertyAddress: address,
        price: priceInCents,
        instructions: instructions || null,
        scheduledAt: getScheduledAt(),
      })
      await postTask.mutateAsync(task.id)
      router.push('/tasks')
    } catch (err: any) {
      toast.error(err.message || 'Failed to post task')
    } finally {
      setPosting(false)
    }
  }

  const meta = TASK_CATEGORIES[category]

  return (
    <div className="max-w-2xl">
      <button
        onClick={onBack}
        className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <div className="flex items-center gap-3 mb-8">
        <div className="h-10 w-10 rounded-md bg-red-glow text-red flex items-center justify-center shrink-0">
          {CATEGORY_ICONS[category]}
        </div>
        <div>
          <h1 className="text-2xl font-extrabold text-navy">{meta.label}</h1>
          <p className="text-sm text-slate">{meta.description}</p>
        </div>
      </div>

      <div className="space-y-5">
        <InputField
          label="Property Address"
          placeholder="123 Main St, Austin, TX 78701"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          required
        />

        <div className="grid grid-cols-2 gap-4">
          <InputField
            label="Date"
            type="date"
            value={scheduledDate}
            onChange={(e) => setScheduledDate(e.target.value)}
          />
          <InputField
            label="Time"
            type="time"
            value={scheduledTime}
            onChange={(e) => setScheduledTime(e.target.value)}
          />
        </div>

        <div>
          <InputField
            label="Your Price"
            type="number"
            placeholder="0.00"
            value={priceInput}
            onChange={(e) => setPriceInput(e.target.value)}
            required
          />
          <p className="text-xs text-slate mt-1.5">Suggested range: {meta.suggestedPrice}</p>
          {priceInCents > 0 && (
            <div className="mt-3 bg-background rounded-md p-3 space-y-1">
              <div className="flex justify-between text-xs text-slate">
                <span>Runner payout</span>
                <span>{formatPrice(priceInCents)}</span>
              </div>
              <div className="flex justify-between text-xs text-slate">
                <span>Service fee (15%)</span>
                <span>{formatPrice(fee)}</span>
              </div>
              <div className="border-t border-border mt-2 pt-2 flex justify-between text-sm font-bold text-navy">
                <span>Total</span>
                <span>{formatPrice(total)}</span>
              </div>
            </div>
          )}
        </div>

        <div>
          <label className="block text-sm font-semibold text-navy mb-1.5">
            Special Instructions
          </label>
          <textarea
            className="w-full rounded-input border border-border bg-surface px-4 py-3 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/30 focus:border-red transition-colors min-h-[100px] resize-y"
            placeholder="Any special instructions for the runner..."
            value={instructions}
            onChange={(e) => setInstructions(e.target.value)}
          />
        </div>

        <div className="flex gap-3 pt-2">
          <PillButton
            variant="secondary"
            fullWidth
            loading={saving}
            onClick={handleSaveDraft}
            disabled={posting}
          >
            Save Draft
          </PillButton>
          <PillButton
            fullWidth
            loading={posting}
            onClick={handlePostTask}
            disabled={saving}
          >
            Post Task
          </PillButton>
        </div>
      </div>
    </div>
  )
}
