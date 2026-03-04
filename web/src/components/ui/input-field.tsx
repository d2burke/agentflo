'use client'

import { forwardRef, useState } from 'react'
import { Eye, EyeOff, X } from 'lucide-react'
import { cn } from '@/lib/utils'

interface InputFieldProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string
  error?: string
  clearable?: boolean
  onClear?: () => void
}

const InputField = forwardRef<HTMLInputElement, InputFieldProps>(
  ({ className, label, error, type, clearable, onClear, ...props }, ref) => {
    const [showPassword, setShowPassword] = useState(false)
    const isPassword = type === 'password'
    const inputType = isPassword && showPassword ? 'text' : type

    return (
      <div className="space-y-1.5">
        {label && (
          <label className="block text-sm font-semibold text-navy">
            {label}
          </label>
        )}
        <div className="relative">
          <input
            ref={ref}
            type={inputType}
            className={cn(
              'flex h-12 w-full rounded-input border bg-surface px-4 text-sm text-navy',
              'placeholder:text-slate-light',
              'transition-all duration-200',
              'focus:outline-none focus:border-red focus:ring-2 focus:ring-red/20',
              error
                ? 'border-error ring-2 ring-error/20'
                : 'border-border hover:border-slate-light',
              (isPassword || clearable) && 'pr-11',
              className,
            )}
            {...props}
          />
          {isPassword && (
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-light hover:text-slate"
              tabIndex={-1}
            >
              {showPassword ? <EyeOff className="h-4.5 w-4.5" /> : <Eye className="h-4.5 w-4.5" />}
            </button>
          )}
          {clearable && props.value && (
            <button
              type="button"
              onClick={onClear}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-light hover:text-slate"
              tabIndex={-1}
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>
        {error && (
          <p className="text-xs font-medium text-error">{error}</p>
        )}
      </div>
    )
  },
)
InputField.displayName = 'InputField'

export { InputField }
