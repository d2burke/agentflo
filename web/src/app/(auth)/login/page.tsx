'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { PillButton } from '@/components/ui/pill-button'
import { InputField } from '@/components/ui/input-field'
import { authService } from '@/services/auth-service'
import { useAppStore } from '@/stores/app-store'
import { toast } from 'sonner'

export default function LoginPage() {
  const router = useRouter()
  const { setUser, setLoading } = useAppStore()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLocalLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!email || !password) return

    setLocalLoading(true)
    try {
      const { user: authUser } = await authService.signIn(email, password)
      if (authUser) {
        const profile = await authService.fetchUserProfile(authUser.id)
        setUser(profile)
      }
      router.push('/dashboard')
    } catch (err: any) {
      toast.error(err.message || 'Failed to sign in')
    } finally {
      setLocalLoading(false)
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-extrabold text-navy mb-1">Welcome back</h1>
      <p className="text-sm text-slate mb-8">Sign in to your Agent Flo account</p>

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

        <InputField
          label="Password"
          type="password"
          placeholder="Enter your password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="current-password"
          required
        />

        <div className="flex justify-end">
          <Link
            href="/forgot-password"
            className="text-sm font-medium text-red hover:text-red-hover transition-colors"
          >
            Forgot password?
          </Link>
        </div>

        <PillButton type="submit" fullWidth loading={loading}>
          Sign In
        </PillButton>
      </form>

      <p className="mt-6 text-center text-sm text-slate">
        Don&apos;t have an account?{' '}
        <Link href="/signup" className="font-semibold text-red hover:text-red-hover transition-colors">
          Sign Up
        </Link>
      </p>
    </div>
  )
}
