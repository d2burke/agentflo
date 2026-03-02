import SwiftUI

struct OnboardingWelcomeView: View {
    let role: UserRole
    let onContinue: () -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Role icon
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.agentRedLight)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: role == .agent ? "briefcase.fill" : "figure.run")
                        .font(.system(size: 28))
                        .foregroundStyle(.agentRed)
                )
                .padding(.bottom, Spacing.xxxxl)

            Text("Welcome!")
                .font(.display)
                .foregroundStyle(.agentNavy)
                .padding(.bottom, Spacing.md)

            Text("Here\u{2019}s how AgentAssist works for you")
                .font(.bodySM)
                .foregroundStyle(.agentSlate)
                .padding(.bottom, Spacing.xxxxl)

            // Value props
            VStack(spacing: Spacing.xxxxl) {
                ForEach(valueProps, id: \.title) { prop in
                    HStack(alignment: .top, spacing: Spacing.xxl) {
                        Circle()
                            .fill(Color.agentRedLight)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: prop.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.agentRed)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prop.title)
                                .font(.bodyEmphasis)
                                .foregroundStyle(.agentNavy)
                            Text(prop.description)
                                .font(.caption)
                                .foregroundStyle(.agentSlate)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)

            Spacer()

            // CTA
            PillButton(ctaTitle, variant: .primaryLarge) {
                onContinue()
            }
            .padding(.horizontal, Spacing.screenPadding)

            Button("Skip for now \u{2192}") {
                appState.selectedTab = .dashboard
                appState.needsOnboarding = false
            }
            .font(.bodySM)
            .foregroundStyle(.agentSlate)
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.white)
        .navigationBarBackButtonHidden()
    }

    private var ctaTitle: String {
        role == .agent ? "Post Your First Task" : "Find Available Tasks"
    }

    private var valueProps: [(icon: String, title: String, description: String)] {
        if role == .agent {
            return [
                ("plus", "Post Tasks in Seconds", "Photography, showings, staging \u{2014} describe what you need and set your price."),
                ("checkmark", "Vetted Runners Only", "Every task runner is a licensed real estate professional, verified on the platform."),
                ("shield.fill", "Secure Payments", "Funds are held in escrow until you approve the work. Pay with confidence."),
            ]
        } else {
            return [
                ("clock.fill", "Earn on Your Schedule", "Accept tasks that fit your availability and location."),
                ("location.fill", "Tasks Near You", "Browse opportunities in your service area."),
                ("star.fill", "Build Your Reputation", "Great reviews lead to more opportunities and higher earnings."),
            ]
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingWelcomeView(role: .agent) {}
    }
    .environment(AppState.preview)
}
