'use client'

import { useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useUserDetail, useApproveUser, useRejectUser } from '@/hooks/use-admin'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { PillButton } from '@/components/ui/pill-button'
import { Avatar } from '@/components/ui/avatar'
import {
  ArrowLeft, CheckCircle, XCircle, Shield, FileText, Building2, Camera, ExternalLink,
} from 'lucide-react'
import { cn, formatDate } from '@/lib/utils'
import type { VettingRecord } from '@/types/models'

const RECORD_TYPE_META: Record<string, { label: string; icon: React.ReactNode }> = {
  license: { label: 'Real Estate License', icon: <Shield className="h-4 w-4" /> },
  photo_id: { label: 'Photo ID', icon: <Camera className="h-4 w-4" /> },
  brokerage: { label: 'Brokerage Verification', icon: <Building2 className="h-4 w-4" /> },
  background_check: { label: 'Background Check', icon: <FileText className="h-4 w-4" /> },
}

const LICENSE_LOOKUP_URLS: Record<string, string> = {
  TX: 'https://www.trec.texas.gov/apps/license-holder-search',
  VA: 'https://www.dpor.virginia.gov/LicenseLookup',
}

function VettingRecordCard({ record }: { record: VettingRecord }) {
  const meta = RECORD_TYPE_META[record.type] ?? { label: record.type, icon: <FileText className="h-4 w-4" /> }
  const data = record.submitted_data ?? {}

  return (
    <div className="rounded-card border border-border bg-white p-4">
      <div className="flex items-center gap-2 mb-3">
        <div className="h-8 w-8 rounded-lg bg-border-light flex items-center justify-center text-slate">
          {meta.icon}
        </div>
        <span className="text-sm font-semibold text-navy">{meta.label}</span>
        <span className={cn(
          'ml-auto inline-flex items-center px-2 py-0.5 rounded-badge text-[10px] font-bold uppercase',
          record.status === 'approved' && 'bg-green-50 text-green-700',
          record.status === 'rejected' && 'bg-red-50 text-red-700',
          record.status === 'pending' && 'bg-amber-50 text-amber-700',
        )}>
          {record.status}
        </span>
      </div>

      {/* Submitted data */}
      {Object.keys(data).length > 0 && (
        <div className="space-y-1 mb-3">
          {Object.entries(data).map(([key, value]) => {
            if (key === 'file_url' && value) {
              return (
                <div key={key} className="flex items-center gap-2">
                  <span className="text-xs text-slate capitalize">{key.replace(/_/g, ' ')}:</span>
                  <a
                    href={value}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-xs text-red hover:underline inline-flex items-center gap-1"
                  >
                    View Document <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              )
            }
            return (
              <div key={key} className="flex items-center gap-2">
                <span className="text-xs text-slate capitalize">{key.replace(/_/g, ' ')}:</span>
                <span className="text-xs text-navy font-medium">{value || '—'}</span>
              </div>
            )
          })}
        </div>
      )}

      {record.reviewer_notes && (
        <p className="text-xs text-slate italic border-t border-border pt-2 mt-2">
          Reviewer: {record.reviewer_notes}
        </p>
      )}
      {record.reviewed_at && (
        <p className="text-[10px] text-slate mt-1">
          Reviewed {formatDate(record.reviewed_at)}
        </p>
      )}
    </div>
  )
}

export default function VettingDetailPage() {
  const { userId } = useParams<{ userId: string }>()
  const router = useRouter()
  const { data: user, isLoading } = useUserDetail(userId)
  const approveUser = useApproveUser()
  const rejectUser = useRejectUser()
  const [notes, setNotes] = useState('')

  function handleApprove() {
    approveUser.mutate({ userId, notes }, {
      onSuccess: () => router.push('/admin/vetting'),
    })
  }

  function handleReject() {
    if (!notes.trim()) {
      return // Require notes for rejection
    }
    rejectUser.mutate({ userId, notes }, {
      onSuccess: () => router.push('/admin/vetting'),
    })
  }

  if (isLoading || !user) {
    return <LoadingSpinner message="Loading user..." />
  }

  const isPending = user.vetting_status === 'pending'
  const lookupUrl = user.license_state ? LICENSE_LOOKUP_URLS[user.license_state] : null

  return (
    <div className="max-w-3xl">
      {/* Header */}
      <button
        onClick={() => router.back()}
        className="flex items-center gap-1 text-sm text-slate hover:text-navy transition-colors mb-4"
      >
        <ArrowLeft className="h-4 w-4" />
        Back
      </button>

      {/* User profile card */}
      <div className="rounded-card border border-border bg-white p-6 mb-6">
        <div className="flex items-start gap-4">
          <Avatar src={user.avatar_url} name={user.full_name} size="lg" />
          <div className="flex-1">
            <h1 className="text-xl font-extrabold text-navy">{user.full_name}</h1>
            <p className="text-sm text-slate">{user.email}</p>
            {user.phone && <p className="text-sm text-slate">{user.phone}</p>}
            <div className="flex items-center gap-3 mt-2">
              <span className={cn(
                'inline-flex items-center px-2.5 py-0.5 rounded-badge text-xs font-bold uppercase',
                user.role === 'agent' ? 'bg-blue-50 text-blue-700' : 'bg-green-50 text-green-700',
              )}>
                {user.role}
              </span>
              <span className={cn(
                'inline-flex items-center px-2.5 py-0.5 rounded-badge text-xs font-bold uppercase',
                user.vetting_status === 'approved' && 'bg-green-50 text-green-700',
                user.vetting_status === 'rejected' && 'bg-red-50 text-red-700',
                user.vetting_status === 'pending' && 'bg-amber-50 text-amber-700',
                user.vetting_status === 'not_started' && 'bg-border-light text-slate',
              )}>
                {user.vetting_status}
              </span>
            </div>
          </div>
        </div>

        {/* License info */}
        <div className="mt-4 pt-4 border-t border-border grid grid-cols-2 gap-4">
          <div>
            <p className="text-[10px] text-slate uppercase font-bold mb-1">License Number</p>
            <p className="text-sm text-navy">{user.license_number || '—'}</p>
          </div>
          <div>
            <p className="text-[10px] text-slate uppercase font-bold mb-1">License State</p>
            <p className="text-sm text-navy">{user.license_state || '—'}</p>
          </div>
          <div>
            <p className="text-[10px] text-slate uppercase font-bold mb-1">Brokerage</p>
            <p className="text-sm text-navy">{user.brokerage || '—'}</p>
          </div>
          <div>
            <p className="text-[10px] text-slate uppercase font-bold mb-1">Joined</p>
            <p className="text-sm text-navy">{formatDate(user.created_at)}</p>
          </div>
        </div>

        {lookupUrl && (
          <a
            href={lookupUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 mt-3 text-xs text-red hover:underline"
          >
            Verify license on state website <ExternalLink className="h-3 w-3" />
          </a>
        )}
      </div>

      {/* Vetting records */}
      <h2 className="text-lg font-bold text-navy mb-3">Vetting Records</h2>
      {user.vetting_records?.length > 0 ? (
        <div className="space-y-3 mb-6">
          {user.vetting_records.map((record) => (
            <VettingRecordCard key={record.id} record={record} />
          ))}
        </div>
      ) : (
        <p className="text-sm text-slate mb-6">No vetting records submitted.</p>
      )}

      {/* Approve / Reject */}
      {isPending && (
        <div className="rounded-card border border-border bg-white p-6">
          <h2 className="text-lg font-bold text-navy mb-3">Review Decision</h2>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Reviewer notes (required for rejection)..."
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/20 resize-none"
            rows={3}
          />
          <div className="flex gap-3 mt-4">
            <PillButton
              onClick={handleApprove}
              loading={approveUser.isPending}
              icon={<CheckCircle className="h-4 w-4" />}
              className="bg-green-600 hover:bg-green-700"
            >
              Approve
            </PillButton>
            <PillButton
              variant="danger"
              onClick={handleReject}
              loading={rejectUser.isPending}
              disabled={!notes.trim()}
              icon={<XCircle className="h-4 w-4" />}
            >
              Reject
            </PillButton>
          </div>
        </div>
      )}
    </div>
  )
}
