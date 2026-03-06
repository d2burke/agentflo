'use client'

import { useState } from 'react'
import { Modal } from '@/components/ui/modal'
import { PillButton } from '@/components/ui/pill-button'
import { Bell, Zap, MessageSquare, DollarSign } from 'lucide-react'
import {
  requestPushPermissionAndRegister,
  recordPushPromptDismissal,
  getPushPermissionState,
} from '@/lib/firebase'

interface PushPermissionModalProps {
  open: boolean
  onClose: () => void
}

const VALUE_PROPS = [
  { icon: Zap, title: 'Instant alerts', description: 'Know the moment a runner applies or delivers' },
  { icon: MessageSquare, title: 'Stay connected', description: 'Get notified when you receive new messages' },
  { icon: DollarSign, title: 'Payment updates', description: 'Track payouts and payment confirmations' },
]

export function PushPermissionModal({ open, onClose }: PushPermissionModalProps) {
  const [loading, setLoading] = useState(false)
  const permissionState = getPushPermissionState()

  async function handleEnable() {
    setLoading(true)
    try {
      await requestPushPermissionAndRegister()
    } finally {
      setLoading(false)
      onClose()
    }
  }

  function handleDismiss() {
    recordPushPromptDismissal()
    onClose()
  }

  // If browser has permanently denied, show instructions instead
  if (permissionState === 'denied') {
    return (
      <Modal open={open} onClose={onClose} size="sm">
        <div className="p-6 text-center space-y-4">
          <div className="mx-auto h-16 w-16 rounded-full bg-red/10 flex items-center justify-center">
            <Bell className="h-8 w-8 text-red" />
          </div>
          <h3 className="text-lg font-bold text-navy">Notifications are blocked</h3>
          <p className="text-sm text-slate">
            Push notifications are disabled in your browser settings. To enable them, click the lock icon
            in your address bar and allow notifications for this site.
          </p>
          <PillButton fullWidth onClick={onClose}>Got it</PillButton>
        </div>
      </Modal>
    )
  }

  return (
    <Modal open={open} onClose={handleDismiss} size="sm">
      <div className="p-6 space-y-6">
        {/* Icon */}
        <div className="text-center">
          <div className="mx-auto h-16 w-16 rounded-full bg-red/10 flex items-center justify-center">
            <Bell className="h-8 w-8 text-red" />
          </div>
        </div>

        {/* Headline */}
        <h3 className="text-xl font-extrabold text-navy text-center">
          Never miss a task update
        </h3>

        {/* Value props */}
        <div className="space-y-4">
          {VALUE_PROPS.map(({ icon: Icon, title, description }) => (
            <div key={title} className="flex items-start gap-3">
              <Icon className="h-5 w-5 text-red shrink-0 mt-0.5" />
              <div>
                <p className="text-sm font-semibold text-navy">{title}</p>
                <p className="text-xs text-slate">{description}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Actions */}
        <div className="space-y-2">
          <PillButton fullWidth loading={loading} onClick={handleEnable}>
            Enable Notifications
          </PillButton>
          <button
            onClick={handleDismiss}
            className="w-full py-2 text-sm text-slate hover:text-navy transition-colors"
          >
            Not Now
          </button>
        </div>
      </div>
    </Modal>
  )
}
