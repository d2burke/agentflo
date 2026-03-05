'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  ArrowLeft,
  Share2,
  MoreHorizontal,
  Star,
  CheckCircle,
  Clock,
  Heart,
  MessageSquare,
  Phone,
  MapPin,
  Building2,
  ShieldCheck,
} from 'lucide-react'
import { cn, getInitials } from '@/lib/utils'
import { format } from 'date-fns'
import type { PublicProfileFull } from '@/types/models'

type Tab = 'about' | 'reviews' | 'activity'

const ROLE_LABELS: Record<string, string> = {
  agent: 'Licensed Real Estate Agent',
  runner: 'Licensed Field Professional',
}

export function PublicProfileView({ profile }: { profile: PublicProfileFull }) {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<Tab>('about')
  const [favorited, setFavorited] = useState(false)

  const initials = getInitials(profile.full_name)
  const memberSince = profile.created_at
    ? format(new Date(profile.created_at), 'MMM yyyy')
    : null

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* ── Hero ── */}
      <div className="relative">
        <div className="h-72 bg-gradient-to-br from-[#2D1B3D] via-[#3D2B4D] to-[#4A3558]" />

        {/* Top nav */}
        <div className="absolute top-12 left-4 right-4 flex items-center justify-between z-10">
          <button
            onClick={() => router.back()}
            className="h-10 w-10 rounded-full bg-navy/60 backdrop-blur-sm flex items-center justify-center text-white"
          >
            <ArrowLeft className="h-5 w-5" />
          </button>
          <div className="flex items-center gap-2">
            <button className="h-10 w-10 rounded-full bg-navy/60 backdrop-blur-sm flex items-center justify-center text-white">
              <Share2 className="h-4 w-4" />
            </button>
            <button className="h-10 w-10 rounded-full bg-navy/60 backdrop-blur-sm flex items-center justify-center text-white">
              <MoreHorizontal className="h-4 w-4" />
            </button>
          </div>
        </div>

        {/* Avatar */}
        <div className="absolute bottom-0 left-1/2 -translate-x-1/2 translate-y-1/2">
          <div className="relative">
            {profile.avatar_url ? (
              <img
                src={profile.avatar_url}
                alt={profile.full_name}
                className="h-32 w-32 rounded-full object-cover border-4 border-surface"
              />
            ) : (
              <div className="h-32 w-32 rounded-full bg-slate-light/30 border-4 border-surface flex items-center justify-center">
                <span className="text-4xl font-bold text-white/80">{initials}</span>
              </div>
            )}
            {/* Online indicator */}
            <div className="absolute bottom-1 right-1/2 translate-x-5 h-4 w-4 rounded-full bg-green border-2 border-surface" />
          </div>
        </div>
      </div>

      {/* ── Name + Location ── */}
      <div className="pt-20 pb-4 px-6 text-center">
        <div className="flex items-center justify-center gap-2">
          <h1 className="text-2xl font-extrabold text-navy">{profile.full_name}</h1>
          {profile.is_verified && (
            <ShieldCheck className="h-5 w-5 text-red" />
          )}
        </div>
        {profile.brokerage && (
          <p className="text-sm text-slate mt-1">
            <MapPin className="h-3.5 w-3.5 inline -mt-0.5 mr-1" />
            {profile.brokerage}
          </p>
        )}
      </div>

      {/* ── Stats Card ── */}
      <div className="mx-5 rounded-xl bg-surface shadow-card p-5">
        <div className="grid grid-cols-3 divide-x divide-border">
          <StatItem
            icon={<Star className="h-5 w-5" />}
            value={profile.avg_rating?.toString() ?? '—'}
            label="Rating"
          />
          <StatItem
            icon={<CheckCircle className="h-5 w-5" />}
            value={profile.completed_tasks.toString()}
            label="Completed"
          />
          <StatItem
            icon={<Clock className="h-5 w-5" />}
            value={`< 15 min`}
            label="Response"
          />
        </div>
      </div>

      {/* ── Tabs ── */}
      <div className="mx-5 mt-6">
        <div className="flex rounded-lg border border-border bg-surface overflow-hidden">
          {(['about', 'reviews', 'activity'] as Tab[]).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={cn(
                'flex-1 py-2.5 text-sm font-semibold capitalize transition-colors',
                activeTab === tab
                  ? 'bg-surface text-navy shadow-sm'
                  : 'bg-border-light text-slate',
              )}
            >
              {tab === 'about' ? 'About' : tab === 'reviews' ? 'Reviews' : 'Activity'}
            </button>
          ))}
        </div>
      </div>

      {/* ── Tab Content ── */}
      <div className="flex-1 px-5 pt-6 pb-28">
        {activeTab === 'about' && <AboutTab profile={profile} memberSince={memberSince} />}
        {activeTab === 'reviews' && <ReviewsTab profile={profile} />}
        {activeTab === 'activity' && <ActivityTab />}
      </div>

      {/* ── Bottom Action Bar ── */}
      <div className="fixed bottom-0 left-0 right-0 bg-surface border-t border-border px-5 py-4 flex items-center gap-3">
        <button
          onClick={() => setFavorited(!favorited)}
          className={cn(
            'h-12 w-12 rounded-full border flex items-center justify-center shrink-0 transition-colors',
            favorited ? 'border-red bg-red-glow' : 'border-border',
          )}
        >
          <Heart
            className={cn('h-5 w-5', favorited ? 'text-red fill-red' : 'text-slate')}
          />
        </button>
        <button className="flex-1 h-12 bg-red text-white rounded-pill font-bold text-sm flex items-center justify-center gap-2 hover:bg-red-hover transition-colors active:scale-[0.98]">
          <MessageSquare className="h-4 w-4" />
          Send Task Request
        </button>
        <button className="h-12 w-12 rounded-full bg-navy flex items-center justify-center shrink-0">
          <Phone className="h-5 w-5 text-white" />
        </button>
      </div>
    </div>
  )
}

/* ── Stat Item ── */
function StatItem({ icon, value, label }: { icon: React.ReactNode; value: string; label: string }) {
  return (
    <div className="flex flex-col items-center gap-2 px-2">
      <div className="h-10 w-10 rounded-lg bg-red-glow text-red flex items-center justify-center">
        {icon}
      </div>
      <span className="text-lg font-extrabold text-navy">{value}</span>
      <span className="text-xs text-slate">{label}</span>
    </div>
  )
}

/* ── About Tab ── */
function AboutTab({ profile, memberSince }: { profile: PublicProfileFull; memberSince: string | null }) {
  return (
    <div className="space-y-6">
      {/* Bio */}
      {(profile.bio || profile.headline) && (
        <div>
          <h3 className="text-xs font-bold text-red uppercase tracking-wider mb-3">About</h3>
          <p className="text-sm text-navy leading-relaxed">
            {profile.bio || profile.headline}
          </p>
        </div>
      )}

      {/* Specialties */}
      {profile.specialties && profile.specialties.length > 0 && (
        <div>
          <h3 className="text-xs font-bold text-red uppercase tracking-wider mb-3">Specialties</h3>
          <div className="flex flex-wrap gap-2">
            {profile.specialties.map((s) => (
              <span
                key={s}
                className="px-4 py-1.5 rounded-pill bg-red-glow text-red text-xs font-semibold border border-red/10"
              >
                {s}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Info Card */}
      <div className="rounded-xl bg-border-light p-5 space-y-0">
        <h3 className="text-xs font-bold text-slate uppercase tracking-wider mb-4">Info</h3>

        <InfoRow
          icon={<Building2 className="h-4 w-4" />}
          label="Role"
          value={ROLE_LABELS[profile.role] ?? profile.role}
        />
        {profile.brokerage && (
          <InfoRow
            icon={<MapPin className="h-4 w-4" />}
            label="Location"
            value={profile.brokerage}
          />
        )}
        {memberSince && (
          <InfoRow
            icon={<Clock className="h-4 w-4" />}
            label="Member Since"
            value={memberSince}
          />
        )}
        <InfoRow
          icon={<CheckCircle className="h-4 w-4" />}
          label="Completion Rate"
          value="98%"
        />
        <InfoRow
          icon={<Star className="h-4 w-4" />}
          label="On-Time Rate"
          value="99%"
          isLast
        />
      </div>
    </div>
  )
}

/* ── Info Row ── */
function InfoRow({
  icon,
  label,
  value,
  isLast = false,
}: {
  icon: React.ReactNode
  label: string
  value: string
  isLast?: boolean
}) {
  return (
    <div
      className={cn(
        'flex items-center justify-between py-3.5',
        !isLast && 'border-b border-border',
      )}
    >
      <div className="flex items-center gap-3">
        <div className="h-8 w-8 rounded-full bg-red-glow text-red flex items-center justify-center shrink-0">
          {icon}
        </div>
        <span className="text-sm text-slate">{label}</span>
      </div>
      <span className="text-sm font-bold text-navy">{value}</span>
    </div>
  )
}

/* ── Reviews Tab (placeholder) ── */
function ReviewsTab({ profile }: { profile: PublicProfileFull }) {
  return (
    <div className="text-center py-12">
      <div className="h-12 w-12 rounded-full bg-border-light text-slate flex items-center justify-center mx-auto mb-3">
        <Star className="h-6 w-6" />
      </div>
      <p className="text-sm font-semibold text-navy mb-1">
        {profile.review_count} Review{profile.review_count !== 1 ? 's' : ''}
      </p>
      <p className="text-xs text-slate">Reviews coming soon</p>
    </div>
  )
}

/* ── Activity Tab (placeholder) ── */
function ActivityTab() {
  return (
    <div className="text-center py-12">
      <div className="h-12 w-12 rounded-full bg-border-light text-slate flex items-center justify-center mx-auto mb-3">
        <Clock className="h-6 w-6" />
      </div>
      <p className="text-sm font-semibold text-navy mb-1">No activity yet</p>
      <p className="text-xs text-slate">Recent activity will appear here</p>
    </div>
  )
}
