import SwiftUI

struct PushPermissionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Icon
            ZStack {
                Circle()
                    .fill(.agentRed.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.agentRed)
            }
            .padding(.top, Spacing.xl)

            // Headline
            Text("Never miss a task update")
                .font(.titleLG)
                .foregroundStyle(.agentNavy)
                .multilineTextAlignment(.center)

            // Value props
            VStack(alignment: .leading, spacing: Spacing.lg) {
                valueProp(
                    icon: "bolt.fill",
                    title: "Instant alerts",
                    description: "Know the moment a runner applies or delivers"
                )
                valueProp(
                    icon: "message.fill",
                    title: "Stay connected",
                    description: "Get notified when you receive new messages"
                )
                valueProp(
                    icon: "dollarsign.circle.fill",
                    title: "Payment updates",
                    description: "Track payouts and payment confirmations"
                )
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // CTA
            Button {
                Task {
                    await appState.pushService.requestPermission()
                }
            } label: {
                Text("Enable Notifications")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.agentRed)
                    .clipShape(Capsule())
            }

            Button("Not Now") {
                appState.pushService.dismissPrePrompt()
            }
            .font(.bodySM)
            .foregroundStyle(.agentSlate)
        }
        .padding(Spacing.xl)
    }

    private func valueProp(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.agentRed)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
            }
        }
    }
}

#Preview {
    PushPermissionView()
        .environment(AppState())
}
