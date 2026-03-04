import { Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

interface LoadingSpinnerProps {
  message?: string
  className?: string
}

export function LoadingSpinner({ message, className }: LoadingSpinnerProps) {
  return (
    <div className={cn('flex flex-col items-center justify-center py-16', className)}>
      <Loader2 className="h-8 w-8 animate-spin text-red mb-3" />
      {message && (
        <p className="text-sm text-slate">{message}</p>
      )}
    </div>
  )
}
