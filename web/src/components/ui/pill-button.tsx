'use client'

import { forwardRef } from 'react'
import { Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger'
type ButtonSize = 'sm' | 'md' | 'lg'

interface PillButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
  size?: ButtonSize
  loading?: boolean
  icon?: React.ReactNode
  fullWidth?: boolean
}

const variantStyles: Record<ButtonVariant, string> = {
  primary: 'bg-red text-white hover:bg-red-hover active:scale-[0.98]',
  secondary: 'bg-border-light text-navy hover:bg-border active:scale-[0.98]',
  outline: 'bg-transparent border border-border text-navy hover:bg-border-light active:scale-[0.98]',
  ghost: 'bg-transparent text-slate hover:bg-border-light active:scale-[0.98]',
  danger: 'bg-error text-white hover:bg-error/90 active:scale-[0.98]',
}

const sizeStyles: Record<ButtonSize, string> = {
  sm: 'h-8 px-4 text-xs font-semibold',
  md: 'h-11 px-6 text-sm font-semibold',
  lg: 'h-12 px-8 text-base font-bold',
}

const PillButton = forwardRef<HTMLButtonElement, PillButtonProps>(
  ({ className, variant = 'primary', size = 'md', loading, disabled, icon, fullWidth, children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          'inline-flex items-center justify-center gap-2 rounded-pill transition-all',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red/20',
          'disabled:opacity-50 disabled:pointer-events-none',
          variantStyles[variant],
          sizeStyles[size],
          fullWidth && 'w-full',
          className,
        )}
        disabled={disabled || loading}
        {...props}
      >
        {loading ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : icon ? (
          icon
        ) : null}
        {children}
      </button>
    )
  },
)
PillButton.displayName = 'PillButton'

export { PillButton }
export type { PillButtonProps }
