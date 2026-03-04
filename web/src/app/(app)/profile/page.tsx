'use client'

import { useRouter } from 'next/navigation'
import { useAppStore } from '@/stores/app-store'
import { authService } from '@/services/auth-service'
import { Avatar } from '@/components/ui/avatar'
import {
  User, CreditCard, Wallet, Shield, Bell, ChevronRight, LogOut,
} from 'lucide-react'
import { cn } from '@/lib/utils'

const MENU_ITEMS = [
  { href: '/profile/personal', label: 'Personal Info', icon: User },
  { href: '/profile/payment', label: 'Payment Methods', icon: CreditCard },
  { href: '/profile/payout', label: 'Payout Settings', icon: Wallet, runnerOnly: true },
  { href: '/profile/security', label: 'Account Security', icon: Shield },
  { href: '/profile/notifications', label: 'Notification Preferences', icon: Bell },
]

export default function ProfilePage() {
  const { user, reset } = useAppStore()
  const router = useRouter()

  if (!user) return null

  async function handleSignOut() {
    await authService.signOut()
    reset()
    router.push('/login')
  }

  return (
    <div className="max-w-2xl">
      {/* Header card */}
      <div className="bg-surface border border-border rounded-card p-6 mb-6">
        <div className="flex items-center gap-4">
          <Avatar src={user.avatar_url} name={user.full_name} size="lg" />
          <div>
            <h1 className="text-xl font-extrabold text-navy">{user.full_name}</h1>
            <p className="text-sm text-slate capitalize">{user.role}</p>
            <p className="text-xs text-slate mt-0.5">{user.email}</p>
          </div>
        </div>
      </div>

      {/* Menu */}
      <div className="bg-surface border border-border rounded-card overflow-hidden">
        {MENU_ITEMS
          .filter((item) => !item.runnerOnly || user.role === 'runner')
          .map((item, i) => (
            <button
              key={item.href}
              onClick={() => router.push(item.href)}
              className={cn(
                'w-full flex items-center gap-3 px-5 py-4 text-left hover:bg-border-light transition-colors',
                i > 0 && 'border-t border-border',
              )}
            >
              <item.icon className="h-5 w-5 text-slate" />
              <span className="flex-1 text-sm font-medium text-navy">{item.label}</span>
              <ChevronRight className="h-4 w-4 text-slate" />
            </button>
          ))}
      </div>

      {/* Sign out */}
      <button
        onClick={handleSignOut}
        className="flex items-center gap-2 text-sm text-error hover:text-error/80 transition-colors mt-6 px-1"
      >
        <LogOut className="h-4 w-4" />
        Sign Out
      </button>
    </div>
  )
}
