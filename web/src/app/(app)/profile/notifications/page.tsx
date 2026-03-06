'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, Bell, CheckCircle } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { useAppStore } from '@/stores/app-store'
import { createClient } from '@/lib/supabase/client'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import { getPushPermissionState, requestPushPermissionAndRegister } from '@/lib/firebase'
import type { NotificationPreferences } from '@/types/models'

const PREF_LABELS: { key: keyof Omit<NotificationPreferences, 'user_id'>; label: string; description: string }[] = [
  { key: 'task_updates', label: 'Task Updates', description: 'Status changes, cancellations, completions' },
  { key: 'messages', label: 'Messages', description: 'New messages from agents or runners' },
  { key: 'payment_confirmations', label: 'Payments', description: 'Payment received or sent confirmations' },
  { key: 'new_available_tasks', label: 'New Tasks', description: 'New tasks posted in your service areas' },
  { key: 'weekly_earnings', label: 'Weekly Earnings', description: 'Weekly earnings summary' },
  { key: 'product_updates', label: 'Product Updates', description: 'New features and improvements' },
]

export default function NotificationPreferencesPage() {
  const { user } = useAppStore()
  const router = useRouter()
  const [prefs, setPrefs] = useState<NotificationPreferences | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!user) return
    const supabase = createClient()
    supabase
      .from('notification_preferences')
      .select()
      .eq('user_id', user.id)
      .single()
      .then(({ data }) => {
        if (data) setPrefs(data as NotificationPreferences)
        else {
          setPrefs({
            user_id: user.id,
            task_updates: true,
            messages: true,
            payment_confirmations: true,
            new_available_tasks: true,
            weekly_earnings: true,
            product_updates: true,
          })
        }
      })
  }, [user])

  async function handleSave() {
    if (!prefs || !user) return
    setSaving(true)
    try {
      const supabase = createClient()
      const { error } = await supabase
        .from('notification_preferences')
        .upsert(prefs)
      if (error) throw error
      toast.success('Preferences saved')
    } catch (err: any) {
      toast.error(err.message || 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  function toggle(key: keyof Omit<NotificationPreferences, 'user_id'>) {
    if (!prefs) return
    setPrefs({ ...prefs, [key]: !prefs[key] })
  }

  const [pushState, setPushState] = useState<NotificationPermission | 'unsupported'>('default')
  const [enablingPush, setEnablingPush] = useState(false)

  useEffect(() => {
    setPushState(getPushPermissionState())
  }, [])

  async function handleEnablePush() {
    setEnablingPush(true)
    try {
      await requestPushPermissionAndRegister()
      setPushState(getPushPermissionState())
    } finally {
      setEnablingPush(false)
    }
  }

  if (!user || !prefs) return null

  return (
    <div className="max-w-2xl">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <h1 className="text-2xl font-extrabold text-navy mb-6">Notification Preferences</h1>

      {/* Push notification status */}
      {pushState !== 'unsupported' && (
        <div className="bg-surface border border-border rounded-card px-5 py-4 mb-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Bell className="h-5 w-5 text-red" />
            <div>
              <p className="text-sm font-medium text-navy">Push Notifications</p>
              <p className="text-xs text-slate">
                {pushState === 'granted'
                  ? 'Enabled — you will receive push notifications'
                  : pushState === 'denied'
                    ? 'Blocked — enable in browser settings'
                    : 'Not enabled'}
              </p>
            </div>
          </div>
          {pushState === 'granted' ? (
            <CheckCircle className="h-5 w-5 text-green-600" />
          ) : pushState === 'default' ? (
            <PillButton size="sm" loading={enablingPush} onClick={handleEnablePush}>
              Enable
            </PillButton>
          ) : null}
        </div>
      )}

      <div className="bg-surface border border-border rounded-card divide-y divide-border">
        {PREF_LABELS.map(({ key, label, description }) => (
          <div key={key} className="flex items-center justify-between px-5 py-4">
            <div>
              <p className="text-sm font-medium text-navy">{label}</p>
              <p className="text-xs text-slate">{description}</p>
            </div>
            <button
              onClick={() => toggle(key)}
              className={cn(
                'relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors',
                prefs[key] ? 'bg-red' : 'bg-border',
              )}
            >
              <span
                className={cn(
                  'pointer-events-none inline-block h-5 w-5 rounded-full bg-white shadow transform transition-transform',
                  prefs[key] ? 'translate-x-5' : 'translate-x-0',
                )}
              />
            </button>
          </div>
        ))}
      </div>

      <div className="mt-6">
        <PillButton fullWidth loading={saving} onClick={handleSave}>
          Save Preferences
        </PillButton>
      </div>
    </div>
  )
}
