'use client'

import { use, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  ArrowLeft, MapPin, Calendar, FileText, DollarSign,
  MessageSquare, CheckCircle, Clock, Download,
  Camera, Star, Play, LogIn, LogOut as LogOutIcon, Check, ChevronRight,
} from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { StatusBadge } from '@/components/ui/status-badge'
import { CategoryIcon } from '@/components/ui/category-icon'
import { Avatar } from '@/components/ui/avatar'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { EmptyState } from '@/components/ui/empty-state'
import { Modal } from '@/components/ui/modal'
import { PaymentCard } from '@/components/ui/payment-card'
import { RunnerCard } from '@/components/ui/runner-card'
import { StatChip, StatChipsRow } from '@/components/ui/stat-chip'
import { LiveCounterCard } from '@/components/ui/live-counter-card'
import { CheckInCard } from '@/components/tasks/check-in-card'
import { PhotoUpload } from '@/components/tasks/photo-upload'
import { ShowingReportForm } from '@/components/tasks/showing-report-form'
import { OpenHouseQR } from '@/components/tasks/open-house-qr'
import { ReviewModal } from '@/components/tasks/review-modal'
import { useAppStore } from '@/stores/app-store'
import {
  useTask, useDeliverables, useApplications, useVisitors,
  useCancelTask, useApproveAndPay, useApplyForTask, useStartTask,
  useMyReview,
} from '@/hooks/use-tasks'
import { formatPrice, formatPriceFull, formatDateTime, timeAgo, cn } from '@/lib/utils'
import { TASK_CATEGORIES, PLATFORM_FEE_RATE } from '@/lib/constants'
import type { TaskStatus, TaskCategory, Deliverable, OpenHouseVisitor } from '@/types/models'

export default function TaskDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const router = useRouter()
  const { user } = useAppStore()
  const { data: task, isLoading } = useTask(id)
  const showDeliverables = task && ['deliverables_submitted', 'completed', 'revision_requested', 'in_progress'].includes(task.status)
  const { data: deliverables = [] } = useDeliverables(id, !!showDeliverables)
  const showApplications = task && task.status === 'posted' && user?.role === 'agent'
  const { data: applications = [] } = useApplications(id, !!showApplications)
  const isOpenHouse = task?.category === 'Open House'
  const { data: visitors = [] } = useVisitors(id, isOpenHouse && !!task)

  const cancelTask = useCancelTask()
  const approveAndPay = useApproveAndPay()
  const applyForTask = useApplyForTask()
  const startTask = useStartTask()

  const [showCancelModal, setShowCancelModal] = useState(false)
  const [cancelReason, setCancelReason] = useState('')
  const [showReviewModal, setShowReviewModal] = useState(false)

  const isCompleted = task?.status === 'completed'
  const { data: existingReview } = useMyReview(id, user?.id, isCompleted)

  if (isLoading) return <LoadingSpinner message="Loading task..." />
  if (!task || !user) return null

  const isAgent = user.role === 'agent'
  const isRunner = user.role === 'runner'
  const isMyTask = isAgent ? task.agent_id === user.id : task.runner_id === user.id
  const meta = TASK_CATEGORIES[task.category]
  const fee = task.platform_fee ?? Math.round(task.price * PLATFORM_FEE_RATE)
  const isLive = task.category === 'Open House' && task.status === 'in_progress'
  const canMessage = isMyTask && ['accepted', 'in_progress', 'deliverables_submitted', 'revision_requested'].includes(task.status)

  function handleCancel() {
    cancelTask.mutate(
      { taskId: task!.id, reason: cancelReason || undefined },
      { onSuccess: () => { setShowCancelModal(false); router.push('/tasks') } },
    )
  }

  function handleExportLeads() {
    if (visitors.length === 0) return
    const header = 'Name,Email,Phone,Interest,Pre-Approved,Agent Represented,Agent Name,Notes,Date\n'
    const rows = visitors.map(v =>
      [v.visitor_name, v.email ?? '', v.phone ?? '', v.interest_level, v.pre_approved ? 'Yes' : 'No', v.agent_represented ? 'Yes' : 'No', v.representing_agent_name ?? '', v.notes ?? '', v.created_at ?? '']
        .map(f => `"${String(f).replace(/"/g, '""')}"`)
        .join(',')
    ).join('\n')
    const blob = new Blob([header + rows], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `open-house-leads-${task!.id.slice(0, 8)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="max-w-4xl">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <div className="lg:grid lg:grid-cols-3 lg:gap-6">
        {/* Main column */}
        <div className="lg:col-span-2 space-y-[9px]">
          {/* Hero Card */}
          <div className="bg-surface border border-border rounded-card p-4">
            {/* Header row */}
            <div className="flex items-center gap-3 mb-2">
              <CategoryIcon category={task.category} size="md" />
              <div className="flex-1 min-w-0">
                <p className="text-[17px] font-extrabold text-navy truncate">{meta?.label ?? task.category}</p>
              </div>
              <span className="text-[19px] font-extrabold text-navy shrink-0">{formatPrice(task.price)}</span>
            </div>

            <StatusBadge status={task.status} category={task.category} className="mb-3" />

            {/* Map placeholder */}
            {task.property_lat && task.property_lng && (
              <div className={cn(
                'w-full h-[124px] rounded-card-inner bg-border-light mb-3 flex items-center justify-center',
                isCompleted && 'opacity-55',
              )}>
                <MapPin className="h-6 w-6 text-slate-light" />
              </div>
            )}

            {/* Detail rows */}
            <div className="space-y-0">
              <TaskDetailRow
                icon={<MapPin className="h-3.5 w-3.5" />}
                label="Location"
                value={task.property_address}
              />
              {task.scheduled_at && (
                <TaskDetailRow
                  icon={<Calendar className="h-3.5 w-3.5" />}
                  label="Scheduled"
                  value={formatDateTime(task.scheduled_at)}
                />
              )}
              {task.instructions && (
                <TaskDetailRow
                  icon={<FileText className="h-3.5 w-3.5" />}
                  label="Instructions"
                  value={task.instructions}
                  isLast
                />
              )}
            </div>
          </div>

          {/* Live Counter (Open House in-progress) */}
          {isLive && (
            <LiveCounterCard
              count={visitors.length}
              subtitle="Current Visitors"
              meta={visitors.length > 0 ? `${visitors.filter(v => v.interest_level === 'very_interested').length} highly interested` : undefined}
            />
          )}

          {/* Stat Chips */}
          <StatChipsSection task={task} deliverables={deliverables} visitors={visitors} />

          {/* Check-in / Check-out info */}
          {task.checked_in_at && (
            <div className="bg-[var(--color-status-active-bg)] border border-green/20 rounded-card p-4">
              <div className="flex items-center gap-2 text-green text-sm font-semibold mb-2">
                <LogIn className="h-4 w-4" /> Checked In
              </div>
              <p className="text-xs text-slate">{formatDateTime(task.checked_in_at)}</p>
              {task.checked_out_at && (
                <>
                  <div className="flex items-center gap-2 text-green text-sm font-semibold mt-3 mb-2">
                    <LogOutIcon className="h-4 w-4" /> Checked Out
                  </div>
                  <p className="text-xs text-slate">{formatDateTime(task.checked_out_at)}</p>
                </>
              )}
            </div>
          )}

          {/* Task Execution -- Runner in-progress actions */}
          {isRunner && isMyTask && task.status === 'in_progress' && (
            <div className="space-y-[9px]">
              {['Showing', 'Staging', 'Open House'].includes(task.category) && (
                <CheckInCard task={task} />
              )}
              {task.category === 'Photography' && (
                <div className="bg-surface border border-border rounded-card p-4">
                  <h2 className="text-sm font-bold text-navy mb-3">Upload Photos</h2>
                  <PhotoUpload taskId={task.id} runnerId={user.id} />
                </div>
              )}
              {task.category === 'Open House' && (
                <OpenHouseQR task={task} />
              )}
              {task.category === 'Showing' && task.checked_out_at && (
                <div className="bg-surface border border-border rounded-card p-4">
                  <h2 className="text-sm font-bold text-navy mb-3">Showing Report</h2>
                  <ShowingReportForm taskId={task.id} runnerId={user.id} />
                </div>
              )}
            </div>
          )}

          {/* Deliverables */}
          {showDeliverables && (
            <DeliverablesSection
              task={task}
              deliverables={deliverables}
              visitors={visitors}
              onExportLeads={handleExportLeads}
            />
          )}

          {/* Applications (agent only, posted tasks) */}
          {showApplications && applications.length > 0 && (
            <div className="bg-surface border border-border rounded-card p-4">
              <h2 className="text-sm font-bold text-navy mb-3">
                Applicants ({applications.length})
              </h2>
              <div className="space-y-3">
                {applications.map((app) => (
                  <div key={app.id} className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Avatar
                        src={app.runner?.avatar_url}
                        name={app.runner?.full_name ?? 'Runner'}
                        size="sm"
                      />
                      <div>
                        <p className="text-[13px] font-bold text-navy">{app.runner?.full_name}</p>
                        <p className="text-[10.5px] text-slate-light">{timeAgo(app.created_at)}</p>
                      </div>
                    </div>
                    {app.status === 'pending' && (
                      <PillButton size="sm" onClick={() => {/* acceptRunner */}}>
                        Accept
                      </PillButton>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Sidebar column */}
        <div className="mt-4 lg:mt-0 space-y-[9px]">
          {/* Payment Card */}
          <PaymentCard
            price={task.price}
            fee={fee}
            isAgent={isAgent}
            runnerPayout={task.runner_payout}
          />

          {/* Runner/Agent Card */}
          {isAgent && task.runner_id && task.agent && (
            <RunnerCard
              person={task.agent}
              label="Accepted"
              timestamp={task.accepted_at}
              status={task.status}
              category={task.category}
              taskId={task.id}
              showMessage={canMessage}
            />
          )}
          {isRunner && task.agent && (
            <RunnerCard
              person={task.agent}
              label="Posted"
              timestamp={task.posted_at}
              status={task.status}
              category={task.category}
              taskId={task.id}
              showMessage={canMessage}
            />
          )}

          {/* Actions */}
          <div className="space-y-[9px]">
            {isAgent && isMyTask && (
              <AgentActions
                status={task.status}
                taskId={task.id}
                onCancel={() => setShowCancelModal(true)}
                onApprove={() =>
                  approveAndPay.mutate(task.id, {
                    onSuccess: () => setShowReviewModal(true),
                  })
                }
                approvingLoading={approveAndPay.isPending}
                hasReview={!!existingReview}
                onReview={() => setShowReviewModal(true)}
              />
            )}
            {isRunner && (
              <RunnerActions
                status={task.status}
                taskId={task.id}
                isMyTask={isMyTask}
                category={task.category}
                onAccept={() => applyForTask.mutate(task.id)}
                onStart={() => startTask.mutate(task.id)}
                acceptLoading={applyForTask.isPending}
                startLoading={startTask.isPending}
                hasPayoutSetup={!!user?.stripe_connect_id}
                hasReview={!!existingReview}
                onReview={() => setShowReviewModal(true)}
              />
            )}
          </div>

          {/* Timeline */}
          <div className="bg-surface border border-border rounded-card p-4">
            <p className="text-[9.5px] font-bold text-slate uppercase tracking-[0.08em] mb-3">
              Timeline
            </p>
            <div className="space-y-3">
              <TimelineItem label="Created" date={task.created_at} />
              <TimelineItem label="Posted" date={task.posted_at} />
              <TimelineItem label="Accepted" date={task.accepted_at} />
              {task.checked_in_at && <TimelineItem label="Checked In" date={task.checked_in_at} />}
              {task.checked_out_at && <TimelineItem label="Checked Out" date={task.checked_out_at} />}
              <TimelineItem label="Completed" date={task.completed_at} />
              {task.cancelled_at && <TimelineItem label="Cancelled" date={task.cancelled_at} />}
            </div>
          </div>
        </div>
      </div>

      {/* Cancel modal */}
      <Modal open={showCancelModal} onClose={() => setShowCancelModal(false)} title="Cancel Task">
        <p className="text-sm text-slate mb-4">
          {task.runner_id
            ? 'This task has already been accepted. Are you sure you want to cancel?'
            : 'Are you sure you want to cancel this task?'}
        </p>
        <textarea
          className="w-full rounded-input border border-border bg-surface px-4 py-3 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/30 focus:border-red transition-colors min-h-[80px] resize-y mb-4"
          placeholder="Reason for cancellation (optional)"
          value={cancelReason}
          onChange={(e) => setCancelReason(e.target.value)}
        />
        <div className="flex gap-3">
          <button
            onClick={() => setShowCancelModal(false)}
            className="flex-1 h-[42px] bg-surface border-[1.5px] border-[#E8E8EE] rounded-[13px] text-xs font-bold text-navy hover:bg-border-light transition-colors"
          >
            Keep Task
          </button>
          <button
            onClick={handleCancel}
            disabled={cancelTask.isPending}
            className="flex-1 h-[42px] bg-gradient-to-br from-[#1A1A2E] to-[#2A2A4E] rounded-[13px] text-xs font-bold text-white hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            {cancelTask.isPending ? 'Cancelling...' : 'Cancel Task'}
          </button>
        </div>
      </Modal>

      {/* Review modal */}
      {task.status === 'completed' && (
        <ReviewModal
          open={showReviewModal}
          onClose={() => setShowReviewModal(false)}
          taskId={task.id}
          reviewerId={user.id}
          revieweeId={isAgent ? (task.runner_id ?? '') : task.agent_id}
          revieweeName={
            isAgent
              ? (task.agent?.full_name ?? 'the runner')
              : (task.agent?.full_name ?? 'the agent')
          }
          category={meta?.label ?? task.category}
        />
      )}
    </div>
  )
}

// ── Sub-components ──

function TaskDetailRow({ icon, label, value, isLast }: { icon: React.ReactNode; label: string; value: string; isLast?: boolean }) {
  return (
    <div className={cn('flex items-start gap-3 py-3', !isLast && 'border-b border-border-light')}>
      <div className="flex items-center justify-center h-[26px] w-[26px] rounded-lg bg-border-light text-slate shrink-0">
        {icon}
      </div>
      <div className="min-w-0">
        <p className="text-[9px] font-bold text-slate uppercase tracking-[0.07em]">{label}</p>
        <p className="text-xs font-semibold text-navy mt-0.5">{value}</p>
      </div>
    </div>
  )
}

function StatChipsSection({ task, deliverables, visitors }: {
  task: { category: TaskCategory; status: TaskStatus; category_form_data?: Record<string, string> | null; checked_in_at?: string | null; checked_out_at?: string | null }
  deliverables: Deliverable[]
  visitors: OpenHouseVisitor[]
}) {
  const formData = task.category_form_data
  const chips: { value: string; label: string; accent?: boolean }[] = []

  switch (task.category) {
    case 'Photography':
      if (deliverables.length > 0) chips.push({ value: String(deliverables.length), label: 'Photos', accent: true })
      if (formData?.rooms) chips.push({ value: formData.rooms, label: 'Rooms' })
      break
    case 'Open House':
      if (visitors.length > 0) {
        chips.push({ value: String(visitors.length), label: 'Visitors', accent: true })
        const leads = visitors.filter(v => v.interest_level === 'very_interested').length
        if (leads > 0) chips.push({ value: String(leads), label: 'Leads', accent: true })
      }
      break
    case 'Staging':
      if (formData?.rooms) chips.push({ value: formData.rooms, label: 'Rooms' })
      if (task.checked_in_at && task.checked_out_at) {
        const hrs = Math.round((new Date(task.checked_out_at).getTime() - new Date(task.checked_in_at).getTime()) / 3600000 * 10) / 10
        chips.push({ value: `${hrs}h`, label: 'Duration' })
      }
      break
    case 'Inspection':
      if (formData?.sqft) chips.push({ value: formData.sqft, label: 'Sq Ft' })
      break
  }

  if (chips.length === 0) return null

  return (
    <StatChipsRow>
      {chips.map((c) => (
        <StatChip key={c.label} value={c.value} label={c.label} accent={c.accent} />
      ))}
    </StatChipsRow>
  )
}

function DeliverablesSection({ task, deliverables, visitors, onExportLeads }: {
  task: { id: string; category: TaskCategory; status: TaskStatus }
  deliverables: Deliverable[]
  visitors: OpenHouseVisitor[]
  onExportLeads: () => void
}) {
  const photos = deliverables.filter(d => d.type === 'photo')
  const reports = deliverables.filter(d => d.type === 'report' || d.type === 'document')
  const showingNotes = deliverables.find(d => d.type === 'report')
  const checklists = deliverables.filter(d => d.type === 'checklist')

  return (
    <div className="bg-surface border border-border rounded-card p-4">
      <p className="text-[9.5px] font-bold text-slate uppercase tracking-[0.08em] mb-3">
        Deliverables
      </p>

      {deliverables.length === 0 && visitors.length === 0 ? (
        <EmptyState
          icon={<Camera className="h-6 w-6" />}
          title="No deliverables yet"
          description="Deliverables will appear here once submitted."
        />
      ) : (
        <div className="space-y-3">
          {/* Showing: notes bubble */}
          {task.category === 'Showing' && showingNotes && (
            <div className="bg-border-light rounded-xl p-3">
              <p className="text-xs text-navy italic">{showingNotes.notes}</p>
            </div>
          )}

          {/* Photography: photo grid */}
          {task.category === 'Photography' && photos.length > 0 && (
            <div>
              <div className="grid grid-cols-3 gap-0.5 rounded-lg overflow-hidden">
                {photos.slice(0, 6).map((p, i) => (
                  <div key={p.id} className="aspect-square bg-background relative">
                    {p.file_url && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.file_url} alt={p.title ?? ''} className="w-full h-full object-cover" />
                    )}
                    {photos.length > 6 && i === 5 && (
                      <div className="absolute inset-0 bg-navy/60 flex items-center justify-center">
                        <span className="text-white text-sm font-bold">+{photos.length - 6} more</span>
                      </div>
                    )}
                  </div>
                ))}
              </div>
              {photos.length > 0 && photos[0].file_url && (
                <a
                  href={photos[0].file_url}
                  download
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1.5 text-xs font-bold text-red mt-2 hover:text-red-hover"
                >
                  <Download className="h-3.5 w-3.5" /> Download Photos
                </a>
              )}
            </div>
          )}

          {/* Staging: checklist */}
          {task.category === 'Staging' && checklists.length > 0 && (
            <div className="space-y-2">
              {checklists.map((c) => (
                <div key={c.id} className="flex items-center gap-3">
                  <div className="flex items-center justify-center h-5 w-5 rounded-full bg-green text-white shrink-0">
                    <Check className="h-3 w-3" />
                  </div>
                  <span className="text-xs font-semibold text-navy">{c.title ?? c.notes ?? 'Item'}</span>
                </div>
              ))}
            </div>
          )}

          {/* Open House: visitor report */}
          {task.category === 'Open House' && visitors.length > 0 && (
            <div className="space-y-2">
              {visitors.slice(0, 5).map((v) => (
                <div key={v.id} className="flex items-center justify-between py-2 border-b border-border-light last:border-0">
                  <div>
                    <p className="text-xs font-bold text-navy">{v.visitor_name}</p>
                    <p className="text-[10px] text-slate">{v.email ?? ''}</p>
                  </div>
                  <span className={cn(
                    'text-[10px] font-semibold px-2 py-0.5 rounded',
                    v.interest_level === 'very_interested' ? 'bg-[var(--color-status-active-bg)] text-[var(--color-status-active-text)]'
                      : v.interest_level === 'interested' ? 'bg-[var(--color-status-working-bg)] text-[var(--color-status-working-text)]'
                      : 'bg-border-light text-slate',
                  )}>
                    {v.interest_level.replace(/_/g, ' ')}
                  </span>
                </div>
              ))}
              {visitors.length > 5 && (
                <p className="text-[10px] text-slate text-center">+{visitors.length - 5} more visitors</p>
              )}
              <button
                onClick={onExportLeads}
                className="flex items-center justify-center gap-2 w-full h-[37px] bg-border-light rounded-[10px] text-xs font-bold text-navy mt-1 hover:bg-border transition-colors"
              >
                <Download className="h-3.5 w-3.5" /> Export Leads
              </button>
            </div>
          )}

          {/* Inspection: report button */}
          {task.category === 'Inspection' && reports.length > 0 && (
            <div>
              {reports[0].file_url ? (
                <a
                  href={reports[0].file_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-2 w-full h-[42px] bg-gradient-to-br from-[#1A1A2E] to-[#2A2A4E] rounded-[13px] text-xs font-bold text-white hover:opacity-90 transition-opacity"
                >
                  View Full Inspection Report <ChevronRight className="h-3.5 w-3.5" />
                </a>
              ) : (
                <p className="text-xs text-slate italic">Report pending...</p>
              )}
            </div>
          )}

          {/* Generic fallback for other deliverables */}
          {!['Photography', 'Showing', 'Staging', 'Open House', 'Inspection'].includes(task.category) && deliverables.length > 0 && (
            <div className="grid gap-3 sm:grid-cols-2">
              {deliverables.map((d) => (
                <DeliverableCard key={d.id} deliverable={d} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

function AgentActions({
  status,
  taskId,
  onCancel,
  onApprove,
  approvingLoading,
  hasReview,
  onReview,
}: {
  status: TaskStatus
  taskId: string
  onCancel: () => void
  onApprove: () => void
  approvingLoading: boolean
  hasReview: boolean
  onReview: () => void
}) {
  if (status === 'completed') {
    return (
      <div className="space-y-[9px]">
        <div className="flex items-center gap-2 text-[var(--color-status-active-text)] text-sm font-semibold bg-[var(--color-status-active-bg)] rounded-card p-4">
          <CheckCircle className="h-5 w-5" /> Completed
        </div>
        {!hasReview && (
          <button
            onClick={onReview}
            className="flex items-center justify-center gap-2 w-full h-[42px] bg-surface border-[1.5px] border-[#E8E8EE] rounded-[13px] text-xs font-bold text-navy hover:bg-border-light transition-colors"
          >
            <Star className="h-4 w-4" /> Leave Review
          </button>
        )}
      </div>
    )
  }

  if (status === 'cancelled') return null

  return (
    <div className="space-y-[9px]">
      {status === 'deliverables_submitted' && (
        <button
          onClick={onApprove}
          disabled={approvingLoading}
          className="flex items-center justify-center gap-2 w-full h-[42px] bg-gradient-to-br from-[#1A1A2E] to-[#2A2A4E] rounded-[13px] text-xs font-bold text-white hover:opacity-90 transition-opacity disabled:opacity-50"
        >
          {approvingLoading ? 'Processing...' : 'Approve & Release Payment'}
        </button>
      )}
      {['posted', 'accepted', 'in_progress'].includes(status) && (
        <button
          onClick={onCancel}
          className="flex items-center justify-center w-full h-[42px] bg-surface border-[1.5px] border-[#E8E8EE] rounded-[13px] text-xs font-bold text-red hover:bg-border-light transition-colors"
        >
          Cancel Task
        </button>
      )}
    </div>
  )
}

function RunnerActions({
  status,
  taskId,
  isMyTask,
  category,
  onAccept,
  onStart,
  acceptLoading,
  startLoading,
  hasPayoutSetup,
  hasReview,
  onReview,
}: {
  status: TaskStatus
  taskId: string
  isMyTask: boolean
  category: string
  onAccept: () => void
  onStart: () => void
  acceptLoading: boolean
  startLoading: boolean
  hasPayoutSetup: boolean
  hasReview: boolean
  onReview: () => void
}) {
  if (status === 'posted' && !isMyTask) {
    return (
      <div className="space-y-[9px]">
        {!hasPayoutSetup && (
          <div className="bg-[var(--color-status-working-bg)] border border-amber/20 rounded-card p-4">
            <p className="text-xs font-semibold text-[var(--color-status-working-text)] mb-2">Payout setup required</p>
            <Link href="/profile/payout">
              <PillButton size="sm" variant="secondary">Set Up Payouts</PillButton>
            </Link>
          </div>
        )}
        <button
          onClick={onAccept}
          disabled={acceptLoading || !hasPayoutSetup}
          className="flex items-center justify-center gap-2 w-full h-[42px] bg-gradient-to-br from-[#1A1A2E] to-[#2A2A4E] rounded-[13px] text-xs font-bold text-white hover:opacity-90 transition-opacity disabled:opacity-50"
        >
          {acceptLoading ? 'Accepting...' : 'Accept Task'}
        </button>
      </div>
    )
  }

  if (status === 'accepted' && isMyTask) {
    return (
      <button
        onClick={onStart}
        disabled={startLoading}
        className="flex items-center justify-center gap-2 w-full h-[42px] bg-gradient-to-br from-[#1A1A2E] to-[#2A2A4E] rounded-[13px] text-xs font-bold text-white hover:opacity-90 transition-opacity disabled:opacity-50"
      >
        <Play className="h-4 w-4" /> {startLoading ? 'Starting...' : 'Start Task'}
      </button>
    )
  }

  if (status === 'deliverables_submitted' && isMyTask) {
    return (
      <div className="flex items-center gap-2 text-[var(--color-status-pending-text)] text-sm font-semibold bg-[var(--color-status-pending-bg)] rounded-card p-4">
        <Clock className="h-5 w-5" /> Awaiting Review
      </div>
    )
  }

  if (status === 'completed') {
    return (
      <div className="space-y-[9px]">
        <div className="flex items-center gap-2 text-[var(--color-status-active-text)] text-sm font-semibold bg-[var(--color-status-active-bg)] rounded-card p-4">
          <CheckCircle className="h-5 w-5" /> Completed
        </div>
        {!hasReview && isMyTask && (
          <button
            onClick={onReview}
            className="flex items-center justify-center gap-2 w-full h-[42px] bg-surface border-[1.5px] border-[#E8E8EE] rounded-[13px] text-xs font-bold text-navy hover:bg-border-light transition-colors"
          >
            <Star className="h-4 w-4" /> Leave Review
          </button>
        )}
      </div>
    )
  }

  return null
}

function DeliverableCard({ deliverable }: { deliverable: Deliverable }) {
  return (
    <div className="bg-surface border border-border rounded-card overflow-hidden">
      {deliverable.file_url && deliverable.type === 'photo' && (
        <div className="aspect-video bg-background relative">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={deliverable.file_url}
            alt={deliverable.title ?? 'Deliverable'}
            className="w-full h-full object-cover"
          />
        </div>
      )}
      <div className="p-3">
        <p className="text-xs font-semibold text-navy">{deliverable.title ?? deliverable.type}</p>
        {deliverable.notes && (
          <p className="text-[10px] text-slate mt-1">{deliverable.notes}</p>
        )}
        {deliverable.file_url && deliverable.type !== 'photo' && (
          <a
            href={deliverable.file_url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-[10px] font-semibold text-red hover:text-red-hover mt-2 inline-block"
          >
            View File
          </a>
        )}
      </div>
    </div>
  )
}

function TimelineItem({ label, date }: { label: string; date?: string | null }) {
  if (!date) return null
  return (
    <div className="flex items-center gap-3">
      <div className="h-2 w-2 rounded-full bg-[var(--color-status-active-dot)] shrink-0" />
      <div className="flex-1 flex justify-between text-xs">
        <span className="font-medium text-navy">{label}</span>
        <span className="text-slate">{timeAgo(date)}</span>
      </div>
    </div>
  )
}
