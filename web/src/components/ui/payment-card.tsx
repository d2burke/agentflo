import { formatPriceFull } from '@/lib/utils'

interface PaymentCardProps {
  price: number
  fee: number
  isAgent: boolean
  runnerPayout?: number | null
}

export function PaymentCard({ price, fee, isAgent, runnerPayout }: PaymentCardProps) {
  return (
    <div className="bg-surface border border-border rounded-card p-4">
      <p className="text-[9.5px] font-bold text-slate uppercase tracking-[0.08em] mb-3">
        Payment
      </p>
      {isAgent ? (
        <div className="space-y-2">
          <div className="flex justify-between text-xs">
            <span className="text-slate font-medium">Runner Pay</span>
            <span className="font-bold text-navy">{formatPriceFull(price)}</span>
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-slate font-medium">Service Fee</span>
            <span className="font-bold text-navy">{formatPriceFull(fee)}</span>
          </div>
          <div className="border-t border-border-light pt-2 mt-2">
            <div className="flex justify-between">
              <span className="text-xs font-bold text-navy">Total</span>
              <span className="text-base font-extrabold text-red">{formatPriceFull(price + fee)}</span>
            </div>
          </div>
        </div>
      ) : (
        <div className="flex justify-between">
          <span className="text-xs font-bold text-navy">Your Payout</span>
          <span className="text-base font-extrabold text-red">{formatPriceFull(runnerPayout ?? price)}</span>
        </div>
      )}
    </div>
  )
}
