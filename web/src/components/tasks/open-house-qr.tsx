'use client'

import { useState, useEffect } from 'react'
import { QRCodeSVG } from 'qrcode.react'
import { Copy, Check } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { taskService } from '@/services/task-service'
import { toast } from 'sonner'
import type { AgentTask } from '@/types/models'

export function OpenHouseQR({ task }: { task: AgentTask }) {
  const [token, setToken] = useState(task.qr_code_token ?? '')
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!token) generateToken()
  }, [])

  async function generateToken() {
    const newToken = crypto.randomUUID()
    try {
      await taskService.setQRCodeToken(task.id, newToken)
      setToken(newToken)
    } catch (err: any) {
      toast.error('Failed to generate QR code')
    }
  }

  // The visitor check-in URL that the QR code points to
  const checkinUrl = `${typeof window !== 'undefined' ? window.location.origin : ''}/open-house/${task.id}?token=${token}`

  function copyLink() {
    navigator.clipboard.writeText(checkinUrl)
    setCopied(true)
    toast.success('Link copied')
    setTimeout(() => setCopied(false), 2000)
  }

  if (!token) return null

  return (
    <div className="bg-surface border border-border rounded-card p-6 text-center">
      <h3 className="text-lg font-bold text-navy mb-2">Open House Check-In</h3>
      <p className="text-sm text-slate mb-6">Visitors scan this QR code to check in</p>

      <div className="inline-block p-4 bg-white rounded-xl shadow-card">
        <QRCodeSVG
          value={checkinUrl}
          size={200}
          level="M"
          includeMargin={false}
        />
      </div>

      <div className="mt-6 space-y-3">
        <PillButton
          variant="secondary"
          fullWidth
          icon={copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
          onClick={copyLink}
        >
          {copied ? 'Copied!' : 'Copy Check-In Link'}
        </PillButton>
      </div>
    </div>
  )
}
