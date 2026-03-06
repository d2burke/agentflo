'use client'

import Link from 'next/link'
import { Avatar } from '@/components/ui/avatar'
import { cn, timeAgo } from '@/lib/utils'
import { CheckCircle, Star, MapPin, Briefcase, Calendar } from 'lucide-react'
import type { PublicProfileFull, Review, PortfolioImage } from '@/types/models'

interface Props {
  profile: PublicProfileFull
  reviews: (Review & { reviewer?: { full_name: string; avatar_url?: string | null } })[]
  portfolio: PortfolioImage[]
}

export function PublicProfileContent({ profile, reviews, portfolio }: Props) {
  return (
    <div className="min-h-screen bg-white">
      {/* Header */}
      <header className="border-b border-gray-100 bg-white">
        <div className="max-w-3xl mx-auto px-4 py-4 flex items-center justify-between">
          <Link href="/" className="text-xl font-extrabold text-[#0A1628]">
            Agent<span className="text-[#E63946]">Flo</span>
          </Link>
        </div>
      </header>

      <main className="max-w-3xl mx-auto px-4 py-8 space-y-8">
        {/* Profile Card */}
        <div className="text-center space-y-4">
          <Avatar src={profile.avatar_url} name={profile.full_name} size="xl" className="mx-auto" />

          <div>
            <div className="flex items-center justify-center gap-2">
              <h1 className="text-2xl font-extrabold text-[#0A1628]">{profile.full_name}</h1>
              {profile.is_verified && (
                <CheckCircle className="h-5 w-5 text-[#E63946]" />
              )}
            </div>

            {profile.headline && (
              <p className="text-sm text-[#64748B] mt-1">{profile.headline}</p>
            )}

            <div className="flex items-center justify-center gap-4 mt-3 text-xs text-[#64748B]">
              <span className={cn(
                'inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold uppercase',
                profile.role === 'agent' ? 'bg-blue-50 text-blue-700' : 'bg-green-50 text-green-700',
              )}>
                {profile.role}
              </span>
              {profile.brokerage && (
                <span className="flex items-center gap-1">
                  <Briefcase className="h-3 w-3" /> {profile.brokerage}
                </span>
              )}
              {profile.created_at && (
                <span className="flex items-center gap-1">
                  <Calendar className="h-3 w-3" /> Joined {new Date(profile.created_at).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Stats Row */}
        <div className="grid grid-cols-3 gap-4">
          <StatCard label="Completed" value={profile.completed_tasks.toString()} />
          <StatCard
            label="Rating"
            value={profile.avg_rating ? profile.avg_rating.toFixed(1) : '—'}
            icon={profile.avg_rating ? <Star className="h-4 w-4 text-amber-400 fill-amber-400 inline" /> : undefined}
          />
          <StatCard label="Reviews" value={profile.review_count.toString()} />
        </div>

        {/* Bio */}
        {profile.bio && (
          <section>
            <h2 className="text-lg font-bold text-[#0A1628] mb-2">About</h2>
            <p className="text-sm text-[#64748B] leading-relaxed">{profile.bio}</p>
          </section>
        )}

        {/* Specialties */}
        {profile.specialties && profile.specialties.length > 0 && (
          <section>
            <h2 className="text-lg font-bold text-[#0A1628] mb-2">Specialties</h2>
            <div className="flex flex-wrap gap-2">
              {profile.specialties.map((s) => (
                <span
                  key={s}
                  className="px-3 py-1 rounded-full bg-gray-100 text-xs font-medium text-[#0A1628]"
                >
                  {s}
                </span>
              ))}
            </div>
          </section>
        )}

        {/* Portfolio */}
        {portfolio.length > 0 && (
          <section>
            <h2 className="text-lg font-bold text-[#0A1628] mb-3">Portfolio</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {portfolio.map((img) => (
                <div key={img.id} className="aspect-square rounded-lg overflow-hidden bg-gray-100">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={img.image_url}
                    alt={img.caption ?? 'Portfolio image'}
                    className="w-full h-full object-cover"
                  />
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Reviews */}
        {reviews.length > 0 && (
          <section>
            <h2 className="text-lg font-bold text-[#0A1628] mb-3">Reviews</h2>
            <div className="space-y-4">
              {reviews.map((review) => (
                <ReviewCard key={review.id} review={review} />
              ))}
            </div>
          </section>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-100 mt-12">
        <div className="max-w-3xl mx-auto px-4 py-6 text-center text-xs text-[#64748B]">
          Agent Flo — Real estate task marketplace
        </div>
      </footer>
    </div>
  )
}

function StatCard({ label, value, icon }: { label: string; value: string; icon?: React.ReactNode }) {
  return (
    <div className="text-center p-4 rounded-xl border border-gray-100">
      <div className="text-2xl font-extrabold text-[#0A1628]">
        {icon} {value}
      </div>
      <div className="text-xs text-[#64748B] mt-1">{label}</div>
    </div>
  )
}

function ReviewCard({ review }: { review: Review & { reviewer?: { full_name: string; avatar_url?: string | null } } }) {
  return (
    <div className="border border-gray-100 rounded-xl p-4">
      <div className="flex items-center gap-3 mb-2">
        {review.reviewer && (
          <Avatar src={review.reviewer.avatar_url} name={review.reviewer.full_name} size="sm" />
        )}
        <div className="flex-1">
          <p className="text-sm font-semibold text-[#0A1628]">
            {review.reviewer?.full_name ?? 'Anonymous'}
          </p>
          {review.created_at && (
            <p className="text-[10px] text-[#64748B]">{timeAgo(review.created_at)}</p>
          )}
        </div>
        <div className="flex items-center gap-0.5">
          {Array.from({ length: 5 }).map((_, i) => (
            <Star
              key={i}
              className={cn(
                'h-3.5 w-3.5',
                i < review.rating ? 'text-amber-400 fill-amber-400' : 'text-gray-200',
              )}
            />
          ))}
        </div>
      </div>
      {review.comment && (
        <p className="text-sm text-[#64748B]">{review.comment}</p>
      )}
    </div>
  )
}
