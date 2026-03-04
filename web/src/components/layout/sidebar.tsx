'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard, ListTodo, MessageSquare, Bell, User, LogOut, PanelLeftClose, PanelLeft,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { Avatar } from '@/components/ui/avatar'
import { useAppStore } from '@/stores/app-store'
import { authService } from '@/services/auth-service'
import { useRouter } from 'next/navigation'

const NAV_ITEMS = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/tasks', label: 'Tasks', icon: ListTodo },
  { href: '/messages', label: 'Messages', icon: MessageSquare },
  { href: '/notifications', label: 'Notifications', icon: Bell },
  { href: '/profile', label: 'Profile', icon: User },
]

export function Sidebar() {
  const pathname = usePathname()
  const router = useRouter()
  const { user, sidebarCollapsed, toggleSidebar, reset } = useAppStore()

  async function handleSignOut() {
    await authService.signOut()
    reset()
    router.push('/login')
  }

  return (
    <aside
      className={cn(
        'hidden lg:flex flex-col h-screen sticky top-0 border-r border-border bg-surface transition-all duration-300',
        sidebarCollapsed ? 'w-16' : 'w-64',
      )}
    >
      {/* Logo */}
      <div className={cn('h-16 flex items-center border-b border-border', sidebarCollapsed ? 'px-3 justify-center' : 'px-5')}>
        <Link href="/dashboard" className="flex items-center gap-2">
          <div className="h-8 w-8 rounded-lg bg-red flex items-center justify-center shrink-0">
            <span className="text-white font-extrabold text-sm">A</span>
          </div>
          {!sidebarCollapsed && (
            <span className="text-lg font-extrabold text-navy">Agent Flo</span>
          )}
        </Link>
      </div>

      {/* Nav items */}
      <nav className="flex-1 py-4 px-2 space-y-1">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 rounded-md transition-colors',
                sidebarCollapsed ? 'h-10 w-10 mx-auto justify-center' : 'h-10 px-3',
                isActive
                  ? 'bg-red-glow text-red font-semibold'
                  : 'text-slate hover:bg-border-light hover:text-navy',
              )}
              title={sidebarCollapsed ? item.label : undefined}
            >
              <item.icon className="h-5 w-5 shrink-0" />
              {!sidebarCollapsed && (
                <span className="text-sm">{item.label}</span>
              )}
            </Link>
          )
        })}
      </nav>

      {/* Collapse toggle */}
      <div className="px-2 pb-2">
        <button
          onClick={toggleSidebar}
          className="flex items-center gap-3 h-10 w-full rounded-md text-slate hover:bg-border-light hover:text-navy transition-colors justify-center"
          title={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {sidebarCollapsed ? (
            <PanelLeft className="h-5 w-5" />
          ) : (
            <>
              <PanelLeftClose className="h-5 w-5" />
              <span className="text-sm">Collapse</span>
            </>
          )}
        </button>
      </div>

      {/* User card */}
      <div className={cn('border-t border-border p-3', sidebarCollapsed && 'flex justify-center')}>
        {user && !sidebarCollapsed && (
          <div className="flex items-center gap-3 mb-2">
            <Avatar src={user.avatar_url} name={user.full_name} size="sm" />
            <div className="min-w-0">
              <p className="text-sm font-semibold text-navy truncate">{user.full_name}</p>
              <p className="text-xs text-slate capitalize">{user.role}</p>
            </div>
          </div>
        )}
        <button
          onClick={handleSignOut}
          className={cn(
            'flex items-center gap-2 text-sm text-slate hover:text-error transition-colors',
            sidebarCollapsed ? 'h-10 w-10 justify-center rounded-md hover:bg-error-light' : 'px-1',
          )}
          title="Sign out"
        >
          <LogOut className="h-4 w-4" />
          {!sidebarCollapsed && <span>Sign Out</span>}
        </button>
      </div>
    </aside>
  )
}
