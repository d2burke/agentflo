'use client'

import { Suspense, useState } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { Briefcase, Zap } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { InputField } from '@/components/ui/input-field'
import { authService } from '@/services/auth-service'
import { useAppStore } from '@/stores/app-store'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'
import type { UserRole } from '@/types/models'

export default function SignupPage() {
  return (
    <Suspense>
      <SignupContent />
    </Suspense>
  )
}

function SignupContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const { setUser } = useAppStore()

  const [step, setStep] = useState<'role' | 'form'>(
    searchParams.get('role') ? 'form' : 'role',
  )
  const [role, setRole] = useState<UserRole>(
    (searchParams.get('role') as UserRole) || 'agent',
  )
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)

  function selectRole(r: UserRole) {
    setRole(r)
    setStep('form')
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!fullName || !email || !password) return

    setLoading(true)
    try {
      const authData = await authService.signUp(email, password, fullName, phone, role)
      if (authData.user) {
        const profile = await authService.fetchUserProfile(authData.user.id)
        setUser(profile)
      }
      router.push('/dashboard')
    } catch (err: any) {
      toast.error(err.message || 'Failed to create account')
    } finally {
      setLoading(false)
    }
  }

  if (step === 'role') {
    return (
      <div>
        <h1 className="text-2xl font-extrabold text-navy mb-1">Get started</h1>
        <p className="text-sm text-slate mb-8">How will you use Agent Flo?</p>

        <div className="space-y-3">
          <RoleCard
            icon={<Briefcase className="h-5 w-5" />}
            title="I&apos;m an Agent"
            description="I need tasks completed — photography, showings, staging, and more."
            selected={false}
            onClick={() => selectRole('agent')}
          />
          <RoleCard
            icon={<Zap className="h-5 w-5" />}
            title="I&apos;m a Runner"
            description="I want to complete tasks and earn money as a licensed professional."
            selected={false}
            onClick={() => selectRole('runner')}
          />
        </div>

        <p className="mt-6 text-center text-sm text-slate">
          Already have an account?{' '}
          <Link href="/login" className="font-semibold text-red hover:text-red-hover transition-colors">
            Sign In
          </Link>
        </p>
      </div>
    )
  }

  return (
    <div>
      <button
        onClick={() => setStep('role')}
        className="text-sm font-medium text-slate hover:text-navy mb-4 transition-colors"
      >
        &larr; Back
      </button>

      <h1 className="text-2xl font-extrabold text-navy mb-1">
        Create your {role === 'agent' ? 'Agent' : 'Runner'} account
      </h1>
      <p className="text-sm text-slate mb-8">
        {role === 'agent'
          ? 'Start posting tasks in minutes.'
          : 'Start earning by completing tasks near you.'}
      </p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <InputField
          label="Full Name"
          placeholder="Jane Smith"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          autoComplete="name"
          required
        />

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
          label="Phone"
          type="tel"
          placeholder="(512) 555-1234"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          autoComplete="tel"
        />

        <InputField
          label="Password"
          type="password"
          placeholder="Create a password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="new-password"
          required
        />

        <PillButton type="submit" fullWidth loading={loading}>
          Create Account
        </PillButton>
      </form>

      <p className="mt-6 text-center text-sm text-slate">
        Already have an account?{' '}
        <Link href="/login" className="font-semibold text-red hover:text-red-hover transition-colors">
          Sign In
        </Link>
      </p>
    </div>
  )
}

function RoleCard({
  icon,
  title,
  description,
  selected,
  onClick,
}: {
  icon: React.ReactNode
  title: string
  description: string
  selected: boolean
  onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'w-full text-left border rounded-card p-5 transition-all hover:border-red hover:shadow-card-hover',
        selected ? 'border-red bg-red-glow' : 'border-border bg-surface',
      )}
    >
      <div className="flex items-start gap-3">
        <div className="h-10 w-10 rounded-md bg-red-glow text-red flex items-center justify-center shrink-0">
          {icon}
        </div>
        <div>
          <h3 className="text-sm font-bold text-navy">{title}</h3>
          <p className="text-xs text-slate mt-0.5">{description}</p>
        </div>
      </div>
    </button>
  )
}
