'use client'

import { use, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  ArrowLeft, MapPin, Calendar, FileText, DollarSign,
  MessageSquare, User, AlertTriangle, CheckCircle, Clock,
  Camera, Eye, Box, Home, ClipboardCheck, Play, LogIn, LogOut as LogOutIcon, Star,
} from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { StatusBadge } from '@/components/ui/status-badge'
import { CategoryIcon } from '@/components/ui/category-icon'
import { Avatar } from '@/components/ui/avatar'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { EmptyState } from '@/components/ui/empty-state'
import { Modal } from '@/components/ui/modal'
import { CheckInCard } from '@/components/tasks/check-in-card'
import { PhotoUpload } from '@/components/tasks/photo-upload'
import { ShowingReportForm } from '@/components/tasks/showing-report-form'
import { OpenHouseQR } from '@/components/tasks/open-house-qr'
import { ReviewModal } from '@/components/tasks/review-modal'
import { useAppStore } from '@/stores/app-store'
import {
  useTask, useDeliverables, useApplications,
  useCancelTask, useApproveAndPay, useApplyForTask, useStartTask,
  useMyReview,
} from '@/hooks/use-tasks'
import { formatPrice, formatPriceFull, formatDateTime, timeAgo, cn } from '@/lib/utils'
import { TASK_CATEGORIES, PLATFORM_FEE_RATE } from '@/lib/constants'
import type { TaskStatus, Deliverable } from '@/types/models'

export default function TaskDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const router = useRouter()
  const { user } = useAppStore()
  const { data: task, isLoading } = useTask(id)
  const showDeliverables = task && ['deliverables_submitted', 'completed', 'revision_requested', 'in_progress'].includes(task.status)
  const { data: deliverables = [] } = useDeliverables(id, !!showDeliverables)
  const showApplications = task && task.status === 'posted' && user?.role === 'agent'
  const { data: applications = [] } = useApplications(id, !!showApplications)

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

  function handleCancel() {
    cancelTask.mutate(
      { taskId: task!.id, reason: cancelReason || undefined },
      { onSuccess: () => { setShowCancelModal(false); router.push('/tasks') } },
    )
  }

  return (
    <div className="max-w-4xl">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <div className="lg:grid lg:grid-cols-3 lg:gap-8">
        {/* Main column */}
        <div className="lg:col-span-2 space-y-6">
          {/* Header */}
          <div className="flex items-start gap-4">
            <CategoryIcon category={task.category} size="lg" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <h1 className="text-xl font-extrabold text-navy">{meta?.label ?? task.category}</h1>
                <StatusBadge status={task.status} />
              </div>
              <p className="text-2xl font-extrabold text-navy">{formatPrice(task.price)}</p>
            </div>
          </div>

          {/* Details */}
          <div className="bg-surface border border-border rounded-card p-5 space-y-4">
            <DetailRow icon={<MapPin className="h-4 w-4" />} label="Location" value={task.property_address} />
            {task.scheduled_at && (
              <DetailRow icon={<Calendar className="h-4 w-4" />} label="Scheduled" value={formatDateTime(task.scheduled_at)} />
            )}
            {task.instructions && (
              <DetailRow icon={<FileText className="h-4 w-4" />} label="Instructions" value={task.instructions} />
            )}

            {/* Payment breakdown */}
            <div className="border-t border-border pt-4">
              <div className="flex items-center gap-2 mb-3">
                <DollarSign className="h-4 w-4 text-slate" />
                <span className="text-sm font-semibold text-navy">Payment</span>
              </div>
              {isAgent ? (
                <div className="space-y-1.5 text-sm">
                  <div className="flex justify-between text-slate">
                    <span>Runner payout</span>
                    <span>{formatPriceFull(task.price)}</span>
                  </div>
                  <div className="flex justify-between text-slate">
                    <span>Service fee</span>
                    <span>{formatPriceFull(fee)}</span>
                  </div>
                  <div className="flex justify-between font-bold text-navy border-t border-border pt-1.5 mt-1.5">
                    <span>Total</span>
                    <span>{formatPriceFull(task.price + fee)}</span>
                  </div>
                </div>
              ) : (
                <div className="flex justify-between text-sm font-bold text-navy">
                  <span>Your payout</span>
                  <span>{formatPriceFull(task.runner_payout ?? task.price)}</span>
                </div>
              )}
            </div>
          </div>

          {/* Check-in / Check-out info */}
          {task.checked_in_at && (
            <div className="bg-green-light border border-green/20 rounded-card p-4">
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

          {/* Task Execution — Runner in-progress actions */}
          {isRunner && isMyTask && task.status === 'in_progress' && (
            <div className="space-y-6">
              {/* Check-in/out for applicable categories */}
              {['Showing', 'Staging', 'Open House'].includes(task.category) && (
                <CheckInCard task={task} />
              )}

              {/* Category-specific tools */}
              {task.category === 'Photography' && (
                <div>
                  <h2 className="text-lg font-bold text-navy mb-4">Upload Photos</h2>
                  <PhotoUpload taskId={task.id} runnerId={user.id} />
                </div>
              )}

              {task.category === 'Open House' && (
                <OpenHouseQR task={task} />
              )}

              {task.category === 'Showing' && task.checked_out_at && (
                <div>
                  <h2 className="text-lg font-bold text-navy mb-4">Showing Report</h2>
                  <ShowingReportForm taskId={task.id} runnerId={user.id} />
                </div>
              )}
            </div>
          )}

          {/* Deliverables */}
          {showDeliverables && (
            <div>
              <h2 className="text-lg font-bold text-navy mb-4">Deliverables</h2>
              {deliverables.length > 0 ? (
                <div className="grid gap-3 sm:grid-cols-2">
                  {deliverables.map((d) => (
                    <DeliverableCard key={d.id} deliverable={d} />
                  ))}
                </div>
              ) : (
                <EmptyState
                  icon={<Camera className="h-8 w-8" />}
                  title="No deliverables yet"
                  description="Deliverables will appear here once submitted."
                />
              )}
            </div>
          )}

          {/* Applications (agent only, posted tasks) */}
          {showApplications && applications.length > 0 && (
            <div>
              <h2 className="text-lg font-bold text-navy mb-4">
                Applicants ({applications.length})
              </h2>
              <div className="space-y-3">
                {applications.map((app) => (
                  <div key={app.id} className="flex items-center justify-between bg-surface border border-border rounded-card p-4">
                    <div className="flex items-center gap-3">
                      <Avatar
                        src={app.runner?.avatar_url}
                        name={app.runner?.full_name ?? 'Runner'}
                        size="sm"
                      />
                      <div>
                        <p className="text-sm font-semibold text-navy">{app.runner?.full_name}</p>
                        <p className="text-xs text-slate">{timeAgo(app.created_at)}</p>
                      </div>
                    </div>
                    {app.status === 'pending' && (
                      <PillButton size="sm" onClick={() => {/* acceptRunner would go here */}}>
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
        <div className="mt-6 lg:mt-0 space-y-4">
          {/* Runner info (for agent) */}
          {isAgent && task.runner_id && task.agent && (
            <div className="bg-surface border border-border rounded-card p-5">
              <h3 className="text-sm font-semibold text-navy mb-3">Assigned Runner</h3>
              <div className="flex items-center gap-3">
                <Avatar src={task.agent?.avatar_url} name={task.agent?.full_name ?? ''} size="md" />
                <div>
                  <p className="text-sm font-semibold text-navy">{task.agent?.full_name}</p>
                  {task.accepted_at && (
                    <p className="text-xs text-slate">Accepted {timeAgo(task.accepted_at)}</p>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Agent info (for runner) */}
          {isRunner && task.agent && (
            <div className="bg-surface border border-border rounded-card p-5">
              <h3 className="text-sm font-semibold text-navy mb-3">Posted by</h3>
              <div className="flex items-center gap-3">
                <Avatar src={task.agent.avatar_url} name={task.agent.full_name} size="md" />
                <p className="text-sm font-semibold text-navy">{task.agent.full_name}</p>
              </div>
            </div>
          )}

          {/* Message button */}
          {isMyTask && ['accepted', 'in_progress', 'deliverables_submitted', 'revision_requested'].includes(task.status) && (
            <Link href={`/messages?taskId=${task.id}`}>
              <PillButton variant="secondary" fullWidth icon={<MessageSquare className="h-4 w-4" />}>
                Message
              </PillButton>
            </Link>
          )}

          {/* Actions */}
          <div className="space-y-3">
            {/* Agent actions */}
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

            {/* Runner actions */}
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
          <div className="bg-surface border border-border rounded-card p-5">
            <h3 className="text-sm font-semibold text-navy mb-3">Timeline</h3>
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
          <PillButton variant="secondary" fullWidth onClick={() => setShowCancelModal(false)}>
            Keep Task
          </PillButton>
          <PillButton variant="danger" fullWidth loading={cancelTask.isPending} onClick={handleCancel}>
            Cancel Task
          </PillButton>
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

function DetailRow({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-start gap-3">
      <div className="text-slate mt-0.5">{icon}</div>
      <div>
        <p className="text-xs font-semibold text-slate">{label}</p>
        <p className="text-sm text-navy">{value}</p>
      </div>
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
      <div className="space-y-3">
        <div className="flex items-center gap-2 text-green text-sm font-semibold bg-green-light rounded-card p-4">
          <CheckCircle className="h-5 w-5" /> Completed
        </div>
        {!hasReview && (
          <PillButton variant="secondary" fullWidth onClick={onReview} icon={<Star className="h-4 w-4" />}>
            Leave Review
          </PillButton>
        )}
      </div>
    )
  }

  if (status === 'cancelled') return null

  return (
    <>
      {status === 'deliverables_submitted' && (
        <PillButton fullWidth loading={approvingLoading} onClick={onApprove}>
          Approve & Release Payment
        </PillButton>
      )}
      {['posted', 'accepted', 'in_progress'].includes(status) && (
        <PillButton variant="danger" fullWidth onClick={onCancel}>
          Cancel Task
        </PillButton>
      )}
    </>
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
      <div className="space-y-3">
        {!hasPayoutSetup && (
          <div className="bg-amber-light border border-amber/20 rounded-card p-4">
            <p className="text-xs font-semibold text-amber mb-2">Payout setup required</p>
            <Link href="/profile/payout">
              <PillButton size="sm" variant="secondary">Set Up Payouts</PillButton>
            </Link>
          </div>
        )}
        <PillButton fullWidth loading={acceptLoading} onClick={onAccept} disabled={!hasPayoutSetup}>
          Accept Task
        </PillButton>
      </div>
    )
  }

  if (status === 'accepted' && isMyTask) {
    return (
      <PillButton fullWidth loading={startLoading} onClick={onStart} icon={<Play className="h-4 w-4" />}>
        Start Task
      </PillButton>
    )
  }

  if (status === 'deliverables_submitted' && isMyTask) {
    return (
      <div className="flex items-center gap-2 text-blue text-sm font-semibold bg-blue-light rounded-card p-4">
        <Clock className="h-5 w-5" /> Awaiting Review
      </div>
    )
  }

  if (status === 'completed') {
    return (
      <div className="space-y-3">
        <div className="flex items-center gap-2 text-green text-sm font-semibold bg-green-light rounded-card p-4">
          <CheckCircle className="h-5 w-5" /> Completed
        </div>
        {!hasReview && isMyTask && (
          <PillButton variant="secondary" fullWidth onClick={onReview} icon={<Star className="h-4 w-4" />}>
            Leave Review
          </PillButton>
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
          <img
            src={deliverable.file_url}
            alt={deliverable.title ?? 'Deliverable'}
            className="w-full h-full object-cover"
          />
        </div>
      )}
      <div className="p-3">
        <p className="text-sm font-semibold text-navy">{deliverable.title ?? deliverable.type}</p>
        {deliverable.notes && (
          <p className="text-xs text-slate mt-1">{deliverable.notes}</p>
        )}
        {deliverable.file_url && deliverable.type !== 'photo' && (
          <a
            href={deliverable.file_url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs font-semibold text-red hover:text-red-hover mt-2 inline-block"
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
      <div className="h-2 w-2 rounded-full bg-green shrink-0" />
      <div className="flex-1 flex justify-between text-xs">
        <span className="font-medium text-navy">{label}</span>
        <span className="text-slate">{timeAgo(date)}</span>
      </div>
    </div>
  )
}
