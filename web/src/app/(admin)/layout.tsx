'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { ShieldCheck, Users, ClipboardList, ArrowLeft, LogOut } from 'lucide-react'
import { cn } from '@/lib/utils'
import { useAuth } from '@/hooks/use-auth'
import { useAppStore } from '@/stores/app-store'
import { authService } from '@/services/auth-service'

const ADMIN_NAV = [
  { href: '/admin', label: 'Dashboard', icon: ShieldCheck, exact: true },
  { href: '/admin/vetting', label: 'Pending Reviews', icon: ClipboardList },
  { href: '/admin/users', label: 'All Users', icon: Users },
]

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  useAuth()
  const pathname = usePathname()
  const router = useRouter()
  const { reset } = useAppStore()

  async function handleSignOut() {
    await authService.signOut()
    reset()
    router.push('/login')
  }

  return (
    <div className="flex min-h-screen">
      <aside className="hidden lg:flex flex-col w-64 h-screen sticky top-0 border-r border-border bg-surface">
        {/* Header */}
        <div className="h-16 flex items-center px-5 border-b border-border">
          <Link href="/admin" className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-lg bg-navy flex items-center justify-center">
              <ShieldCheck className="h-4 w-4 text-white" />
            </div>
            <span className="text-lg font-extrabold text-navy">Admin</span>
          </Link>
        </div>

        {/* Nav */}
        <nav className="flex-1 py-4 px-2 space-y-1">
          {ADMIN_NAV.map((item) => {
            const isActive = item.exact
              ? pathname === item.href
              : pathname.startsWith(item.href)
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  'flex items-center gap-3 h-10 px-3 rounded-md transition-colors text-sm',
                  isActive
                    ? 'bg-navy/10 text-navy font-semibold'
                    : 'text-slate hover:bg-border-light hover:text-navy',
                )}
              >
                <item.icon className="h-5 w-5 shrink-0" />
                <span>{item.label}</span>
              </Link>
            )
          })}
        </nav>

        {/* Footer */}
        <div className="border-t border-border p-3 space-y-2">
          <Link
            href="/dashboard"
            className="flex items-center gap-2 text-sm text-slate hover:text-navy transition-colors px-1"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to App
          </Link>
          <button
            onClick={handleSignOut}
            className="flex items-center gap-2 text-sm text-slate hover:text-error transition-colors px-1"
          >
            <LogOut className="h-4 w-4" />
            Sign Out
          </button>
        </div>
      </aside>

      <main className="flex-1 min-w-0">
        <div className="max-w-6xl mx-auto px-6 py-8">
          {children}
        </div>
      </main>
    </div>
  )
}
