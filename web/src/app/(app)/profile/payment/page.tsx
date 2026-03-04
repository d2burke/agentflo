'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, CreditCard, Plus } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { EmptyState } from '@/components/ui/empty-state'
import { useAppStore } from '@/stores/app-store'
import { taskService } from '@/services/task-service'
import { toast } from 'sonner'

export default function PaymentMethodsPage() {
  const { user } = useAppStore()
  const router = useRouter()
  const [loading, setLoading] = useState(false)

  if (!user) return null

  async function handleAddPayment() {
    setLoading(true)
    try {
      const { setupIntent, ephemeralKey, customer, publishableKey } = await taskService.createSetupIntent()
      // In a full implementation, this would open Stripe Elements
      // For now, redirect to a Stripe-hosted setup page or use inline elements
      toast.info('Stripe payment setup would open here')
    } catch (err: any) {
      toast.error(err.message || 'Failed to set up payment')
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

      <h1 className="text-2xl font-extrabold text-navy mb-6">Payment Methods</h1>

      {user.stripe_customer_id ? (
        <div className="bg-surface border border-border rounded-card p-5 mb-4">
          <div className="flex items-center gap-3">
            <CreditCard className="h-5 w-5 text-slate" />
            <div>
              <p className="text-sm font-semibold text-navy">Payment method on file</p>
              <p className="text-xs text-slate">Managed via Stripe</p>
            </div>
          </div>
        </div>
      ) : (
        <EmptyState
          icon={<CreditCard className="h-10 w-10" />}
          title="No payment methods"
          description="Add a payment method to post tasks."
          action={
            <PillButton icon={<Plus className="h-4 w-4" />} loading={loading} onClick={handleAddPayment}>
              Add Payment Method
            </PillButton>
          }
        />
      )}
    </div>
  )
}
