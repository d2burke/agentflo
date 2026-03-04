'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { LayoutDashboard, ListTodo, MessageSquare, Bell, User } from 'lucide-react'
import { cn } from '@/lib/utils'

const TABS = [
  { href: '/dashboard', label: 'Home', icon: LayoutDashboard },
  { href: '/tasks', label: 'Tasks', icon: ListTodo },
  { href: '/messages', label: 'Messages', icon: MessageSquare },
  { href: '/notifications', label: 'Alerts', icon: Bell },
  { href: '/profile', label: 'Profile', icon: User },
]

export function MobileNav() {
  const pathname = usePathname()

  return (
    <nav className="lg:hidden fixed bottom-0 inset-x-0 z-40">
      <div className="mx-4 mb-4 bg-surface/90 backdrop-blur-md border border-border rounded-tab-bar shadow-tab-bar">
        <div className="flex items-center justify-around h-13">
          {TABS.map((tab) => {
            const isActive = pathname.startsWith(tab.href)
            return (
              <Link
                key={tab.href}
                href={tab.href}
                className={cn(
                  'flex flex-col items-center gap-0.5 px-4 py-2 rounded-xl transition-colors',
                  isActive ? 'text-red' : 'text-slate',
                )}
              >
                <tab.icon className="h-5 w-5" />
                <span className="text-[10px] font-semibold">{tab.label}</span>
              </Link>
            )
          })}
        </div>
      </div>
    </nav>
  )
}
