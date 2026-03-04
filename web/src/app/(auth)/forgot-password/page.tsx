'use client'

import { useState } from 'react'
import Link from 'next/link'
import { PillButton } from '@/components/ui/pill-button'
import { InputField } from '@/components/ui/input-field'
import { authService } from '@/services/auth-service'
import { toast } from 'sonner'
import { CheckCircle2 } from 'lucide-react'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [sent, setSent] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!email) return

    setLoading(true)
    try {
      await authService.resetPassword(email)
      setSent(true)
    } catch (err: any) {
      toast.error(err.message || 'Failed to send reset email')
    } finally {
      setLoading(false)
    }
  }

  if (sent) {
    return (
      <div className="text-center">
        <div className="h-12 w-12 rounded-full bg-green-light text-green flex items-center justify-center mx-auto mb-4">
          <CheckCircle2 className="h-6 w-6" />
        </div>
        <h1 className="text-2xl font-extrabold text-navy mb-2">Check your email</h1>
        <p className="text-sm text-slate mb-6">
          We sent a password reset link to <strong className="text-navy">{email}</strong>
        </p>
        <Link
          href="/login"
          className="text-sm font-semibold text-red hover:text-red-hover transition-colors"
        >
          Back to Sign In
        </Link>
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-2xl font-extrabold text-navy mb-1">Reset password</h1>
      <p className="text-sm text-slate mb-8">
        Enter your email and we&apos;ll send you a reset link.
      </p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <InputField
          label="Email"
          type="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoComplete="email"
          required
        />

        <PillButton type="submit" fullWidth loading={loading}>
          Send Reset Link
        </PillButton>
      </form>

      <p className="mt-6 text-center text-sm text-slate">
        Remember your password?{' '}
        <Link href="/login" className="font-semibold text-red hover:text-red-hover transition-colors">
          Sign In
        </Link>
      </p>
    </div>
  )
}
