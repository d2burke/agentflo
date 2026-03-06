'use client'

import { useState, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { useAppStore } from '@/stores/app-store'
import { useMyVettingRecords, useSubmitVetting, useUploadPhotoId } from '@/hooks/use-vetting'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { PillButton } from '@/components/ui/pill-button'
import {
  ArrowLeft, Shield, Camera, Building2, CheckCircle, Clock, XCircle, Upload, FileText,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import type { VettingRecord } from '@/types/models'

// ── US States ──

const US_STATES = [
  'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA',
  'KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
  'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT',
  'VA','WA','WV','WI','WY','DC',
]

// ── Status helpers ──

function StatusBadge({ status }: { status: string }) {
  return (
    <span className={cn(
      'inline-flex items-center gap-1 px-2 py-0.5 rounded-badge text-[10px] font-bold uppercase',
      status === 'approved' && 'bg-green-50 text-green-700',
      status === 'rejected' && 'bg-red-50 text-red-700',
      status === 'pending' && 'bg-amber-50 text-amber-700',
    )}>
      {status === 'approved' && <CheckCircle className="h-3 w-3" />}
      {status === 'pending' && <Clock className="h-3 w-3" />}
      {status === 'rejected' && <XCircle className="h-3 w-3" />}
      {status}
    </span>
  )
}

// ── Step Cards ──

function LicenseStep({
  record,
  onSubmit,
  isSubmitting,
}: {
  record?: VettingRecord
  onSubmit: (data: Record<string, string>) => void
  isSubmitting: boolean
}) {
  const { user } = useAppStore()
  const [licenseNumber, setLicenseNumber] = useState(
    record?.submitted_data?.license_number ?? user?.license_number ?? '',
  )
  const [state, setState] = useState(
    record?.submitted_data?.state ?? user?.license_state ?? '',
  )
  const [expiry, setExpiry] = useState(record?.submitted_data?.expiry ?? '')

  const isApproved = record?.status === 'approved'
  const canSubmit = licenseNumber.trim() && state && !isApproved

  return (
    <div className="rounded-card border border-border bg-white p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="h-9 w-9 rounded-lg bg-blue-50 flex items-center justify-center text-blue-600">
            <Shield className="h-5 w-5" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-navy">Real Estate License</h3>
            <p className="text-xs text-slate">Enter your license details for verification</p>
          </div>
        </div>
        {record && <StatusBadge status={record.status} />}
      </div>

      {record?.reviewer_notes && record.status === 'rejected' && (
        <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-100">
          <p className="text-xs text-red-700 font-medium">Reviewer feedback:</p>
          <p className="text-xs text-red-600 mt-1">{record.reviewer_notes}</p>
        </div>
      )}

      <div className="space-y-3">
        <div>
          <label className="text-xs font-semibold text-navy block mb-1">License Number *</label>
          <input
            type="text"
            value={licenseNumber}
            onChange={(e) => setLicenseNumber(e.target.value)}
            disabled={isApproved}
            placeholder="e.g., TX-456123"
            className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/20 disabled:opacity-50"
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-semibold text-navy block mb-1">State *</label>
            <select
              value={state}
              onChange={(e) => setState(e.target.value)}
              disabled={isApproved}
              className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-sm text-navy focus:outline-none focus:ring-2 focus:ring-red/20 disabled:opacity-50"
            >
              <option value="">Select state</option>
              {US_STATES.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs font-semibold text-navy block mb-1">Expiration Date</label>
            <input
              type="date"
              value={expiry}
              onChange={(e) => setExpiry(e.target.value)}
              disabled={isApproved}
              className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-sm text-navy focus:outline-none focus:ring-2 focus:ring-red/20 disabled:opacity-50"
            />
          </div>
        </div>

        {!isApproved && (
          <PillButton
            onClick={() => onSubmit({ license_number: licenseNumber.trim(), state, ...(expiry && { expiry }) })}
            loading={isSubmitting}
            disabled={!canSubmit}
            className="w-full mt-2"
          >
            {record?.status === 'rejected' ? 'Resubmit' : record?.status === 'pending' ? 'Update' : 'Submit License'}
          </PillButton>
        )}
      </div>
    </div>
  )
}

function PhotoIdStep({
  record,
  userId,
  onSubmit,
  isSubmitting,
}: {
  record?: VettingRecord
  userId: string
  onSubmit: (data: Record<string, string>) => void
  isSubmitting: boolean
}) {
  const uploadPhotoId = useUploadPhotoId()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [uploadedUrl, setUploadedUrl] = useState<string | null>(
    record?.submitted_data?.file_url ?? null,
  )

  const isApproved = record?.status === 'approved'

  const handleFileSelect = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    // Preview
    const reader = new FileReader()
    reader.onload = () => setPreviewUrl(reader.result as string)
    reader.readAsDataURL(file)

    // Upload
    const url = await uploadPhotoId.mutateAsync({ userId, file })
    setUploadedUrl(url)
  }, [userId, uploadPhotoId])

  return (
    <div className="rounded-card border border-border bg-white p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="h-9 w-9 rounded-lg bg-purple-50 flex items-center justify-center text-purple-600">
            <Camera className="h-5 w-5" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-navy">Photo ID</h3>
            <p className="text-xs text-slate">Upload a government-issued photo ID</p>
          </div>
        </div>
        {record && <StatusBadge status={record.status} />}
      </div>

      {record?.reviewer_notes && record.status === 'rejected' && (
        <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-100">
          <p className="text-xs text-red-700 font-medium">Reviewer feedback:</p>
          <p className="text-xs text-red-600 mt-1">{record.reviewer_notes}</p>
        </div>
      )}

      {!isApproved && (
        <>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/png,application/pdf"
            className="hidden"
            onChange={handleFileSelect}
          />

          <button
            onClick={() => fileInputRef.current?.click()}
            disabled={uploadPhotoId.isPending}
            className="w-full border-2 border-dashed border-border rounded-lg p-6 flex flex-col items-center gap-2 hover:border-red/30 hover:bg-red/5 transition-colors"
          >
            {previewUrl ? (
              <img src={previewUrl} alt="ID preview" className="h-32 object-contain rounded" />
            ) : uploadedUrl ? (
              <div className="flex items-center gap-2 text-green-600">
                <FileText className="h-6 w-6" />
                <span className="text-sm font-medium">Document uploaded</span>
              </div>
            ) : (
              <>
                <Upload className="h-8 w-8 text-slate" />
                <span className="text-sm text-slate">Click to upload photo ID</span>
                <span className="text-xs text-slate/70">JPEG, PNG, or PDF up to 10MB</span>
              </>
            )}
          </button>

          {uploadPhotoId.isPending && (
            <p className="text-xs text-slate text-center mt-2">Uploading...</p>
          )}

          <PillButton
            onClick={() => onSubmit({ file_url: uploadedUrl! })}
            loading={isSubmitting}
            disabled={!uploadedUrl || uploadPhotoId.isPending}
            className="w-full mt-3"
          >
            {record?.status === 'rejected' ? 'Resubmit' : record?.status === 'pending' ? 'Update' : 'Submit Photo ID'}
          </PillButton>
        </>
      )}

      {isApproved && (
        <div className="flex items-center gap-2 p-3 rounded-lg bg-green-50">
          <CheckCircle className="h-4 w-4 text-green-600" />
          <span className="text-xs text-green-700 font-medium">Photo ID verified</span>
        </div>
      )}
    </div>
  )
}

function BrokerageStep({
  record,
  onSubmit,
  isSubmitting,
}: {
  record?: VettingRecord
  onSubmit: (data: Record<string, string>) => void
  isSubmitting: boolean
}) {
  const { user } = useAppStore()
  const [brokerageName, setBrokerageName] = useState(
    record?.submitted_data?.brokerage_name ?? user?.brokerage ?? '',
  )
  const [officePhone, setOfficePhone] = useState(
    record?.submitted_data?.office_phone ?? '',
  )

  const isApproved = record?.status === 'approved'
  const canSubmit = brokerageName.trim() && !isApproved

  return (
    <div className="rounded-card border border-border bg-white p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="h-9 w-9 rounded-lg bg-green-50 flex items-center justify-center text-green-600">
            <Building2 className="h-5 w-5" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-navy">Brokerage Verification</h3>
            <p className="text-xs text-slate">Provide your brokerage details</p>
          </div>
        </div>
        {record && <StatusBadge status={record.status} />}
      </div>

      {record?.reviewer_notes && record.status === 'rejected' && (
        <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-100">
          <p className="text-xs text-red-700 font-medium">Reviewer feedback:</p>
          <p className="text-xs text-red-600 mt-1">{record.reviewer_notes}</p>
        </div>
      )}

      <div className="space-y-3">
        <div>
          <label className="text-xs font-semibold text-navy block mb-1">Brokerage Name *</label>
          <input
            type="text"
            value={brokerageName}
            onChange={(e) => setBrokerageName(e.target.value)}
            disabled={isApproved}
            placeholder="e.g., Keller Williams Realty"
            className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/20 disabled:opacity-50"
          />
        </div>
        <div>
          <label className="text-xs font-semibold text-navy block mb-1">Office Phone</label>
          <input
            type="tel"
            value={officePhone}
            onChange={(e) => setOfficePhone(e.target.value)}
            disabled={isApproved}
            placeholder="e.g., (512) 555-9000"
            className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/20 disabled:opacity-50"
          />
        </div>

        {!isApproved && (
          <PillButton
            onClick={() => onSubmit({ brokerage_name: brokerageName.trim(), ...(officePhone && { office_phone: officePhone }) })}
            loading={isSubmitting}
            disabled={!canSubmit}
            className="w-full mt-2"
          >
            {record?.status === 'rejected' ? 'Resubmit' : record?.status === 'pending' ? 'Update' : 'Submit Brokerage'}
          </PillButton>
        )}
      </div>
    </div>
  )
}

// ── Main Page ──

export default function VerificationPage() {
  const { user } = useAppStore()
  const router = useRouter()
  const { data: records, isLoading } = useMyVettingRecords()
  const submitVetting = useSubmitVetting()
  const [submittingType, setSubmittingType] = useState<string | null>(null)

  if (!user) return null

  const licenseRecord = records?.find((r) => r.type === 'license')
  const photoIdRecord = records?.find((r) => r.type === 'photo_id')
  const brokerageRecord = records?.find((r) => r.type === 'brokerage')

  const approvedCount = records?.filter((r) => r.status === 'approved').length ?? 0
  const totalSteps = 3
  const allApproved = user.vetting_status === 'approved'

  function handleSubmit(type: string) {
    return (data: Record<string, string>) => {
      setSubmittingType(type)
      submitVetting.mutate(
        { type: type as 'license' | 'photo_id' | 'brokerage', submittedData: data },
        { onSettled: () => setSubmittingType(null) },
      )
    }
  }

  return (
    <div className="max-w-2xl">
      {/* Header */}
      <button
        onClick={() => router.push('/profile')}
        className="flex items-center gap-1 text-sm text-slate hover:text-navy transition-colors mb-4"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Profile
      </button>

      <div className="mb-6">
        <h1 className="text-xl font-extrabold text-navy">Account Verification</h1>
        <p className="text-sm text-slate mt-1">
          Complete the steps below to verify your account. Once approved, you can{' '}
          {user.role === 'agent' ? 'post tasks' : 'apply to tasks'} on Agent Flo.
        </p>
      </div>

      {/* Overall status */}
      {allApproved ? (
        <div className="rounded-card border border-green-200 bg-green-50 p-4 mb-6 flex items-center gap-3">
          <CheckCircle className="h-6 w-6 text-green-600" />
          <div>
            <p className="text-sm font-bold text-green-800">Account Verified</p>
            <p className="text-xs text-green-700">Your identity has been verified. You have full access to Agent Flo.</p>
          </div>
        </div>
      ) : (
        <div className="rounded-card border border-border bg-white p-4 mb-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-navy uppercase">Verification Progress</span>
            <span className="text-xs text-slate">{approvedCount}/{totalSteps} steps approved</span>
          </div>
          <div className="w-full h-2 bg-border-light rounded-full overflow-hidden">
            <div
              className="h-full bg-red rounded-full transition-all duration-500"
              style={{ width: `${(approvedCount / totalSteps) * 100}%` }}
            />
          </div>
          {user.vetting_status === 'pending' && (
            <p className="text-xs text-amber-600 mt-2 flex items-center gap-1">
              <Clock className="h-3 w-3" />
              Your submissions are under review. You&apos;ll be notified once approved.
            </p>
          )}
        </div>
      )}

      {isLoading ? (
        <LoadingSpinner message="Loading verification status..." />
      ) : (
        <div className="space-y-4">
          <LicenseStep
            record={licenseRecord}
            onSubmit={handleSubmit('license')}
            isSubmitting={submittingType === 'license'}
          />
          <PhotoIdStep
            record={photoIdRecord}
            userId={user.id}
            onSubmit={handleSubmit('photo_id')}
            isSubmitting={submittingType === 'photo_id'}
          />
          <BrokerageStep
            record={brokerageRecord}
            onSubmit={handleSubmit('brokerage')}
            isSubmitting={submittingType === 'brokerage'}
          />
        </div>
      )}
    </div>
  )
}
