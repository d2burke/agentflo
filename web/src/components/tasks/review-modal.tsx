'use client'

import { useState } from 'react'
import { Star } from 'lucide-react'
import { Modal } from '@/components/ui/modal'
import { PillButton } from '@/components/ui/pill-button'
import { useSubmitReview } from '@/hooks/use-tasks'
import { cn } from '@/lib/utils'

interface ReviewModalProps {
  open: boolean
  onClose: () => void
  taskId: string
  reviewerId: string
  revieweeId: string
  revieweeName: string
  category: string
}

const POSITIVE_TAGS = [
  'On time',
  'Great communication',
  'Quality work',
  'Professional',
  'Above & beyond',
  'Followed instructions',
]

const IMPROVEMENT_TAGS = [
  'Punctuality',
  'Communication',
  'Work quality',
  'Professionalism',
  'Following instructions',
]

export function ReviewModal({
  open,
  onClose,
  taskId,
  reviewerId,
  revieweeId,
  revieweeName,
  category,
}: ReviewModalProps) {
  const [rating, setRating] = useState(0)
  const [hoveredStar, setHoveredStar] = useState(0)
  const [wentWell, setWentWell] = useState<Set<string>>(new Set())
  const [couldImprove, setCouldImprove] = useState<Set<string>>(new Set())
  const [otherText, setOtherText] = useState('')

  const submitReview = useSubmitReview()
  const isHighRating = rating >= 4

  function toggleTag(tag: string, set: Set<string>, setFn: (s: Set<string>) => void) {
    const next = new Set(set)
    if (next.has(tag)) next.delete(tag)
    else next.add(tag)
    setFn(next)
  }

  function buildComment(): string | null {
    const parts: Record<string, unknown> = {}

    if (wentWell.size > 0) {
      parts.went_well = Array.from(wentWell).sort()
    }
    if (couldImprove.size > 0) {
      parts.could_improve = Array.from(couldImprove).sort()
    }
    const trimmed = otherText.trim()
    if (trimmed) {
      parts.other = trimmed
    }

    if (Object.keys(parts).length === 0) return null
    return JSON.stringify(parts)
  }

  function handleSubmit() {
    submitReview.mutate(
      {
        taskId,
        reviewerId,
        revieweeId,
        rating,
        comment: buildComment(),
      },
      {
        onSuccess: () => {
          onClose()
        },
      },
    )
  }

  return (
    <Modal open={open} onClose={onClose} title="Leave a Review" size="md">
      <div className="px-6 py-5 space-y-6 max-h-[70vh] overflow-y-auto">
        {/* Header */}
        <div className="text-center">
          <h3 className="text-lg font-bold text-navy">How was {revieweeName}?</h3>
          <p className="text-xs text-slate mt-1">{category}</p>
        </div>

        {/* Star rating */}
        <div className="flex justify-center gap-2">
          {[1, 2, 3, 4, 5].map((star) => (
            <button
              key={star}
              type="button"
              className="p-1 transition-transform hover:scale-110"
              onMouseEnter={() => setHoveredStar(star)}
              onMouseLeave={() => setHoveredStar(0)}
              onClick={() => setRating(star)}
            >
              <Star
                className={cn(
                  'h-9 w-9 transition-colors',
                  star <= (hoveredStar || rating)
                    ? 'fill-amber text-amber'
                    : 'fill-none text-slate-light',
                )}
              />
            </button>
          ))}
        </div>

        {/* Tag sections — appear after rating selected */}
        {rating > 0 && (
          <>
            {/* Primary tags */}
            <div>
              <p className="text-xs font-semibold text-slate mb-3">
                {isHighRating ? 'What went well?' : 'What could they have done better?'}
              </p>
              <div className="flex flex-wrap gap-2">
                {POSITIVE_TAGS.map((tag) => (
                  <TagChip
                    key={tag}
                    label={tag}
                    selected={wentWell.has(tag)}
                    onClick={() => toggleTag(tag, wentWell, setWentWell)}
                  />
                ))}
              </div>
            </div>

            {/* Improvement tags */}
            <div>
              <p className="text-xs font-semibold text-slate mb-3">
                What could have been improved?
              </p>
              <div className="flex flex-wrap gap-2">
                {IMPROVEMENT_TAGS.map((tag) => (
                  <TagChip
                    key={tag}
                    label={tag}
                    selected={couldImprove.has(tag)}
                    onClick={() => toggleTag(tag, couldImprove, setCouldImprove)}
                  />
                ))}
              </div>
            </div>

            {/* Other text */}
            <div>
              <p className="text-xs font-semibold text-slate mb-2">Anything else? (optional)</p>
              <textarea
                className="w-full rounded-input border border-border bg-surface px-4 py-3 text-sm text-navy placeholder:text-slate-light focus:outline-none focus:ring-2 focus:ring-red/20 focus:border-red transition-colors min-h-[80px] resize-y"
                placeholder="Share more details..."
                value={otherText}
                onChange={(e) => setOtherText(e.target.value)}
                rows={3}
              />
            </div>

            {/* Submit */}
            <PillButton
              fullWidth
              loading={submitReview.isPending}
              disabled={rating === 0}
              onClick={handleSubmit}
            >
              Submit Review
            </PillButton>
          </>
        )}
      </div>
    </Modal>
  )
}

// ── Tag Chip ──

function TagChip({
  label,
  selected,
  onClick,
}: {
  label: string
  selected: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'px-4 py-2 rounded-pill text-xs font-semibold transition-all',
        selected
          ? 'bg-navy text-white'
          : 'bg-surface text-slate border border-border hover:bg-border-light',
      )}
    >
      {label}
    </button>
  )
}
