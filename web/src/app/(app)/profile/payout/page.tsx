'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, Wallet, ExternalLink, CheckCircle } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { useAppStore } from '@/stores/app-store'
import { taskService } from '@/services/task-service'
import { toast } from 'sonner'

export default function PayoutSettingsPage() {
  const { user } = useAppStore()
  const router = useRouter()
  const [loading, setLoading] = useState(false)

  if (!user) return null

  const hasConnect = !!user.stripe_connect_id

  async function handleSetupPayout() {
    setLoading(true)
    try {
      const { url } = await taskService.createConnectLink()
      window.location.href = url
    } catch (err: any) {
      toast.error(err.message || 'Failed to create payout link')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <h1 className="text-2xl font-extrabold text-navy mb-6">Payout Settings</h1>

      <div className="bg-surface border border-border rounded-card p-6">
        <div className="flex items-center gap-3 mb-4">
          <Wallet className="h-5 w-5 text-navy" />
          <h2 className="text-lg font-bold text-navy">Stripe Connect</h2>
        </div>

        {hasConnect ? (
          <div className="space-y-4">
            <div className="flex items-center gap-2 text-green text-sm font-semibold">
              <CheckCircle className="h-4 w-4" /> Payouts enabled
            </div>
            <p className="text-sm text-slate">
              Your Stripe Connect account is set up. Payouts will be deposited directly to your bank account when tasks are completed.
            </p>
            <PillButton
              variant="secondary"
              icon={<ExternalLink className="h-4 w-4" />}
              loading={loading}
              onClick={handleSetupPayout}
            >
              Update Payout Settings
            </PillButton>
          </div>
        ) : (
          <div className="space-y-4">
            <p className="text-sm text-slate">
              Set up your Stripe Connect account to receive payouts when you complete tasks. You&apos;ll need to provide your bank details and identity verification.
            </p>
            <PillButton
              icon={<ExternalLink className="h-4 w-4" />}
              loading={loading}
              onClick={handleSetupPayout}
            >
              Set Up Payouts
            </PillButton>
          </div>
        )}
      </div>
    </div>
  )
}
