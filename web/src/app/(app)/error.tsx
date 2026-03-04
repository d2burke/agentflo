'use client'

import { PillButton } from '@/components/ui/pill-button'
import { AlertTriangle } from 'lucide-react'

export default function AppError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] text-center px-6">
      <div className="h-16 w-16 rounded-full bg-error-light text-error flex items-center justify-center mb-4">
        <AlertTriangle className="h-8 w-8" />
      </div>
      <h2 className="text-xl font-extrabold text-navy mb-2">Something went wrong</h2>
      <p className="text-sm text-slate mb-6 max-w-md">
        {error.message || 'An unexpected error occurred. Please try again.'}
      </p>
      <PillButton onClick={reset}>Try Again</PillButton>
    </div>
  )
}
