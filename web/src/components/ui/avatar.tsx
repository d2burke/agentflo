'use client'

import { useState } from 'react'
import { cn, getInitials } from '@/lib/utils'

interface AvatarProps {
  src?: string | null
  name: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  className?: string
}

const SIZES = {
  sm: 'h-8 w-8 text-xs',
  md: 'h-10 w-10 text-sm',
  lg: 'h-12 w-12 text-base',
  xl: 'h-18 w-18 text-xl',
}

const PX_SIZES = {
  sm: 32,
  md: 40,
  lg: 48,
  xl: 72,
}

export function Avatar({ src, name, size = 'md', className }: AvatarProps) {
  const [imgError, setImgError] = useState(false)

  if (src && !imgError) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={src}
        alt={name}
        width={PX_SIZES[size]}
        height={PX_SIZES[size]}
        className={cn('rounded-full object-cover shrink-0', SIZES[size], className)}
        onError={() => setImgError(true)}
      />
    )
  }

  return (
    <div
      className={cn(
        'rounded-full bg-red-light text-red font-bold flex items-center justify-center shrink-0',
        SIZES[size],
        className,
      )}
    >
      {getInitials(name)}
    </div>
  )
}
