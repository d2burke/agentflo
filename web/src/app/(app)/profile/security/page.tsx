'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, Shield, Smartphone, Trash2 } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { InputField } from '@/components/ui/input-field'
import { useAppStore } from '@/stores/app-store'
import { authService } from '@/services/auth-service'
import { toast } from 'sonner'

export default function SecurityPage() {
  const { user } = useAppStore()
  const router = useRouter()

  const [factors, setFactors] = useState<any[]>([])
  const [enrolling, setEnrolling] = useState(false)
  const [qrUri, setQrUri] = useState<string | null>(null)
  const [factorId, setFactorId] = useState<string | null>(null)
  const [verifyCode, setVerifyCode] = useState('')
  const [verifying, setVerifying] = useState(false)

  useEffect(() => {
    loadFactors()
  }, [])

  async function loadFactors() {
    try {
      const data = await authService.getMFAFactors()
      setFactors(data.totp ?? [])
    } catch {
      // MFA not available
    }
  }

  async function handleEnroll() {
    setEnrolling(true)
    try {
      const data = await authService.enrollMFA()
      setQrUri(data.totp.uri)
      setFactorId(data.id)
    } catch (err: any) {
      toast.error(err.message || 'Failed to start MFA enrollment')
    } finally {
      setEnrolling(false)
    }
  }

  async function handleVerify() {
    if (!factorId || !verifyCode) return
    setVerifying(true)
    try {
      await authService.verifyMFA(factorId, verifyCode)
      toast.success('MFA enabled successfully')
      setQrUri(null)
      setFactorId(null)
      setVerifyCode('')
      loadFactors()
    } catch (err: any) {
      toast.error(err.message || 'Invalid code')
    } finally {
      setVerifying(false)
    }
  }

  async function handleUnenroll(id: string) {
    try {
      await authService.unenrollMFA(id)
      toast.success('MFA device removed')
      loadFactors()
    } catch (err: any) {
      toast.error(err.message || 'Failed to remove device')
    }
  }

  if (!user) return null

  const hasActiveMFA = factors.some((f: any) => f.factor_type === 'totp' && f.status === 'verified')

  return (
    <div className="max-w-2xl">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <h1 className="text-2xl font-extrabold text-navy mb-6">Account Security</h1>

      {/* MFA Section */}
      <div className="bg-surface border border-border rounded-card p-6 mb-6">
        <div className="flex items-center gap-3 mb-4">
          <Shield className="h-5 w-5 text-navy" />
          <h2 className="text-lg font-bold text-navy">Two-Factor Authentication</h2>
        </div>

        {hasActiveMFA ? (
          <div className="space-y-4">
            <div className="flex items-center gap-2 text-green text-sm font-semibold">
              <Smartphone className="h-4 w-4" /> MFA is enabled
            </div>
            {factors
              .filter((f: any) => f.status === 'verified')
              .map((f: any) => (
                <div key={f.id} className="flex items-center justify-between bg-border-light rounded-md p-3">
                  <div>
                    <p className="text-sm font-medium text-navy">{f.friendly_name || 'Authenticator'}</p>
                    <p className="text-xs text-slate">TOTP</p>
                  </div>
                  <button
                    onClick={() => handleUnenroll(f.id)}
                    className="text-error hover:text-error/80 transition-colors"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              ))}
          </div>
        ) : qrUri ? (
          <div className="space-y-4">
            <p className="text-sm text-slate">
              Scan this QR code with your authenticator app, then enter the verification code below.
            </p>
            <div className="flex justify-center py-4">
              <img
                src={`https://api.qrserver.com/v1/create-qr-code/?data=${encodeURIComponent(qrUri)}&size=200x200`}
                alt="MFA QR Code"
                className="rounded-md"
                width={200}
                height={200}
              />
            </div>
            <InputField
              label="Verification Code"
              placeholder="Enter 6-digit code"
              value={verifyCode}
              onChange={(e) => setVerifyCode(e.target.value)}
              maxLength={6}
            />
            <PillButton fullWidth loading={verifying} onClick={handleVerify}>
              Verify & Enable
            </PillButton>
          </div>
        ) : (
          <div>
            <p className="text-sm text-slate mb-4">
              Add an extra layer of security to your account by requiring a verification code from your authenticator app.
            </p>
            <PillButton loading={enrolling} onClick={handleEnroll}>
              Set Up MFA
            </PillButton>
          </div>
        )}
      </div>
    </div>
  )
}
