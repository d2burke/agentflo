import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import type { PublicProfileFull, Review, PortfolioImage } from '@/types/models'
import type { Metadata } from 'next'
import { PublicProfileContent } from './profile-content'

interface Props {
  params: Promise<{ slug: string }>
}

async function getProfileData(slug: string) {
  const supabase = await createClient()

  const { data: profile } = await supabase
    .from('public_profiles')
    .select()
    .eq('profile_slug', slug)
    .single()

  if (!profile || !profile.is_public_profile_enabled) return null

  const [{ data: reviews }, { data: portfolio }] = await Promise.all([
    supabase
      .from('reviews')
      .select('*, reviewer:users!reviewer_id(full_name, avatar_url)')
      .eq('reviewee_id', profile.id)
      .order('created_at', { ascending: false })
      .limit(20),
    supabase
      .from('portfolio_images')
      .select()
      .eq('runner_id', profile.id)
      .order('sort_order'),
  ])

  return {
    profile: profile as PublicProfileFull,
    reviews: (reviews ?? []).map((r: any) => {
      if (Array.isArray(r.reviewer)) r.reviewer = r.reviewer[0] ?? null
      return r as Review & { reviewer?: { full_name: string; avatar_url?: string | null } }
    }),
    portfolio: (portfolio ?? []) as PortfolioImage[],
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const data = await getProfileData(slug)

  if (!data) {
    return { title: 'Profile Not Found | Agent Flo' }
  }

  const { profile } = data
  const title = `${profile.full_name} | Agent Flo`
  const description = profile.headline
    ?? `${profile.role === 'agent' ? 'Real estate agent' : 'Runner'} on Agent Flo${profile.brokerage ? ` at ${profile.brokerage}` : ''}`

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      type: 'profile',
      ...(profile.avatar_url && { images: [{ url: profile.avatar_url }] }),
    },
  }
}

export default async function PublicProfilePage({ params }: Props) {
  const { slug } = await params
  const data = await getProfileData(slug)

  if (!data) notFound()

  return <PublicProfileContent {...data} />
}
