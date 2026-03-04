import Link from 'next/link'
import {
  Camera, Eye, Box, Home, ClipboardCheck, MessageSquare,
  ArrowRight, Shield, CreditCard, CheckCircle2, Star,
} from 'lucide-react'

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-background">
      {/* Navigation */}
      <nav className="sticky top-0 z-40 bg-surface/80 backdrop-blur-md border-b border-border">
        <div className="max-w-6xl mx-auto px-5 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-lg bg-red flex items-center justify-center">
              <span className="text-white font-extrabold text-sm">A</span>
            </div>
            <span className="text-lg font-extrabold text-navy">Agent Flo</span>
          </Link>

          <div className="hidden md:flex items-center gap-8">
            <a href="#features" className="text-sm font-medium text-slate hover:text-navy transition-colors">Features</a>
            <a href="#how-it-works" className="text-sm font-medium text-slate hover:text-navy transition-colors">How It Works</a>
            <a href="#pricing" className="text-sm font-medium text-slate hover:text-navy transition-colors">Pricing</a>
          </div>

          <div className="flex items-center gap-3">
            <Link
              href="/login"
              className="hidden sm:inline-flex h-9 px-4 items-center text-sm font-semibold text-slate hover:text-navy transition-colors"
            >
              Log In
            </Link>
            <Link
              href="/signup"
              className="inline-flex h-9 px-5 items-center rounded-pill bg-red text-white text-sm font-semibold hover:bg-red-hover transition-colors"
            >
              Get Started
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative overflow-hidden">
        <div className="max-w-6xl mx-auto px-5 pt-20 pb-24 md:pt-28 md:pb-32">
          <div className="max-w-2xl">
            <h1 className="text-4xl md:text-5xl lg:text-6xl font-extrabold text-navy tracking-tight leading-[1.1]">
              Delegate tasks.{' '}
              <span className="text-red">Close deals.</span>
            </h1>
            <p className="mt-6 text-lg text-slate max-w-xl leading-relaxed">
              The marketplace for real estate agents to outsource photography, showings, staging, open houses, and inspections to vetted licensed professionals.
            </p>
            <div className="mt-8 flex flex-col sm:flex-row gap-3">
              <Link
                href="/signup?role=agent"
                className="inline-flex h-12 px-8 items-center justify-center rounded-pill bg-red text-white text-base font-bold hover:bg-red-hover transition-all active:scale-[0.98]"
              >
                I&apos;m an Agent
                <ArrowRight className="ml-2 h-4 w-4" />
              </Link>
              <Link
                href="/signup?role=runner"
                className="inline-flex h-12 px-8 items-center justify-center rounded-pill border border-border text-navy text-base font-bold hover:bg-border-light transition-all active:scale-[0.98]"
              >
                I&apos;m a Runner
                <ArrowRight className="ml-2 h-4 w-4" />
              </Link>
            </div>
          </div>
        </div>
        {/* Subtle gradient decoration */}
        <div className="absolute top-0 right-0 w-1/2 h-full bg-gradient-to-l from-red-glow to-transparent opacity-40 pointer-events-none" />
      </section>

      {/* Features */}
      <section id="features" className="py-20 bg-surface">
        <div className="max-w-6xl mx-auto px-5">
          <div className="text-center mb-14">
            <h2 className="text-3xl font-extrabold text-navy">Everything you need to scale your business</h2>
            <p className="mt-3 text-slate max-w-lg mx-auto">
              Post tasks in seconds. Get matched with licensed professionals. Review deliverables and pay securely.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <FeatureCard
              icon={<Camera className="h-5 w-5" />}
              title="Professional Photography"
              description="Get stunning listing photos from licensed photographers with fast turnaround."
            />
            <FeatureCard
              icon={<Eye className="h-5 w-5" />}
              title="Property Showings"
              description="Have a licensed agent handle buyer and inspector showings when you can't be there."
            />
            <FeatureCard
              icon={<Box className="h-5 w-5" />}
              title="Staging Coordination"
              description="Before and after documentation with side-by-side comparison photos."
            />
            <FeatureCard
              icon={<Home className="h-5 w-5" />}
              title="Open House Management"
              description="QR code visitor check-in, real-time tracking, and automated visitor reports."
            />
            <FeatureCard
              icon={<ClipboardCheck className="h-5 w-5" />}
              title="Property Inspections"
              description="ASHI-compliant inspection checklists with photo evidence and detailed reports."
            />
            <FeatureCard
              icon={<MessageSquare className="h-5 w-5" />}
              title="Real-time Communication"
              description="Built-in messaging keeps agents and runners connected throughout every task."
            />
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section id="how-it-works" className="py-20">
        <div className="max-w-6xl mx-auto px-5">
          <div className="text-center mb-14">
            <h2 className="text-3xl font-extrabold text-navy">How It Works</h2>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16">
            {/* Agent Flow */}
            <div>
              <h3 className="text-lg font-bold text-navy mb-6 flex items-center gap-2">
                <span className="h-6 w-6 rounded-full bg-red text-white text-xs font-bold flex items-center justify-center">A</span>
                For Agents
              </h3>
              <div className="space-y-6">
                <Step number={1} title="Post a Task" description="Select a category, enter the property address, set your price, and add instructions." />
                <Step number={2} title="Runner Accepts" description="Licensed professionals in your area apply. Review profiles and accept the best fit." />
                <Step number={3} title="Review & Pay" description="Review deliverables, approve the work, and payment is released automatically." />
              </div>
            </div>

            {/* Runner Flow */}
            <div>
              <h3 className="text-lg font-bold text-navy mb-6 flex items-center gap-2">
                <span className="h-6 w-6 rounded-full bg-navy text-white text-xs font-bold flex items-center justify-center">R</span>
                For Runners
              </h3>
              <div className="space-y-6">
                <Step number={1} title="Browse Available Tasks" description="See tasks posted near your service areas. Apply with a message to the agent." />
                <Step number={2} title="Complete the Work" description="Check in, upload photos and documents, fill out reports — all from the app." />
                <Step number={3} title="Get Paid" description="Receive 100% of the listed task price via direct deposit after approval." />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="py-20 bg-surface">
        <div className="max-w-6xl mx-auto px-5">
          <div className="text-center mb-14">
            <h2 className="text-3xl font-extrabold text-navy">Simple, transparent pricing</h2>
            <p className="mt-3 text-slate max-w-lg mx-auto">
              No subscriptions. No hidden fees. Just a simple service fee when tasks are completed.
            </p>
          </div>

          <div className="max-w-md mx-auto bg-background border border-border rounded-card p-8 text-center">
            <div className="text-5xl font-extrabold text-navy mb-2">15%</div>
            <p className="text-base font-semibold text-slate mb-6">service fee per task</p>
            <div className="space-y-3 text-left">
              <PricingDetail label="Agents" detail="Pay the task price + 15% service fee" />
              <PricingDetail label="Runners" detail="Keep 100% of the listed task price" />
              <PricingDetail label="Payouts" detail="Direct deposit within 24 hours of approval" />
              <PricingDetail label="Secure" detail="Funds held in escrow until work is approved" />
            </div>
          </div>
        </div>
      </section>

      {/* Trust */}
      <section className="py-20">
        <div className="max-w-6xl mx-auto px-5">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <TrustCard
              icon={<Shield className="h-6 w-6" />}
              title="Licensed Professionals Only"
              description="Every runner is a licensed real estate professional, verified before they can accept tasks."
            />
            <TrustCard
              icon={<CreditCard className="h-6 w-6" />}
              title="Secure Escrow Payments"
              description="Payment is held securely until you approve the deliverables. No risk."
            />
            <TrustCard
              icon={<Star className="h-6 w-6" />}
              title="Ratings & Reviews"
              description="Both parties rate each other after every task, building trust and accountability."
            />
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 bg-navy">
        <div className="max-w-6xl mx-auto px-5 text-center">
          <h2 className="text-3xl font-extrabold text-white mb-4">
            Ready to streamline your real estate operations?
          </h2>
          <p className="text-slate-light mb-8 max-w-md mx-auto">
            Join agents and runners already using Agent Flo to get more done.
          </p>
          <Link
            href="/signup"
            className="inline-flex h-12 px-8 items-center rounded-pill bg-red text-white text-base font-bold hover:bg-red-hover transition-all active:scale-[0.98]"
          >
            Get Started Free
            <ArrowRight className="ml-2 h-4 w-4" />
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-10 border-t border-border">
        <div className="max-w-6xl mx-auto px-5 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="h-6 w-6 rounded bg-red flex items-center justify-center">
              <span className="text-white font-extrabold text-[10px]">A</span>
            </div>
            <span className="text-sm font-bold text-navy">Agent Flo</span>
          </div>
          <div className="flex items-center gap-6 text-sm text-slate">
            <a href="#" className="hover:text-navy transition-colors">Privacy</a>
            <a href="#" className="hover:text-navy transition-colors">Terms</a>
            <a href="#" className="hover:text-navy transition-colors">Contact</a>
          </div>
          <p className="text-xs text-slate-light">&copy; {new Date().getFullYear()} Agent Flo. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

// Sub-components

function FeatureCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <div className="border border-border rounded-card p-6 hover:shadow-card-hover transition-shadow">
      <div className="h-10 w-10 rounded-md bg-red-glow text-red flex items-center justify-center mb-4">
        {icon}
      </div>
      <h3 className="text-base font-bold text-navy mb-2">{title}</h3>
      <p className="text-sm text-slate leading-relaxed">{description}</p>
    </div>
  )
}

function Step({ number, title, description }: { number: number; title: string; description: string }) {
  return (
    <div className="flex gap-4">
      <div className="h-8 w-8 rounded-full bg-red-glow text-red text-sm font-bold flex items-center justify-center shrink-0 mt-0.5">
        {number}
      </div>
      <div>
        <h4 className="text-sm font-bold text-navy mb-1">{title}</h4>
        <p className="text-sm text-slate leading-relaxed">{description}</p>
      </div>
    </div>
  )
}

function PricingDetail({ label, detail }: { label: string; detail: string }) {
  return (
    <div className="flex items-start gap-3">
      <CheckCircle2 className="h-4 w-4 text-green shrink-0 mt-0.5" />
      <div>
        <span className="text-sm font-semibold text-navy">{label}: </span>
        <span className="text-sm text-slate">{detail}</span>
      </div>
    </div>
  )
}

function TrustCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <div className="text-center">
      <div className="h-12 w-12 rounded-full bg-green-light text-green flex items-center justify-center mx-auto mb-4">
        {icon}
      </div>
      <h3 className="text-base font-bold text-navy mb-2">{title}</h3>
      <p className="text-sm text-slate leading-relaxed">{description}</p>
    </div>
  )
}
