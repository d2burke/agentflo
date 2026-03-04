import SwiftUI

struct PayoutSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var didOpenStripe = false

    private var user: AppUser? { appState.authService.currentUser }
    private var isConnected: Bool { user?.stripeConnectId != nil }

    var body: some View {
        VStack(spacing: Spacing.sectionGap) {
            Spacer()

            if isConnected {
                connectedState
            } else {
                disconnectedState
            }

            Spacer()
            Spacer()
        }
        .background(.agentBackground)
        .navigationTitle("Payout Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toast(errorMessage ?? "", style: .error, isPresented: $showError)
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh profile when user returns from Stripe onboarding in Safari
            if newPhase == .active && didOpenStripe {
                didOpenStripe = false
                Task {
                    if let userId = user?.id {
                        await appState.authService.fetchUserProfile(userId: userId, forceRefresh: true)
                    }
                }
            }
        }
    }

    private var disconnectedState: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 48))
                .foregroundStyle(.agentSlateLight)

            VStack(spacing: Spacing.md) {
                Text("Set Up Payouts")
                    .font(.titleMD)
                    .foregroundStyle(.agentNavy)

                Text("Connect your bank account through Stripe to receive payouts for completed tasks.")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)
                    .multilineTextAlignment(.center)
            }

            PillButton("Connect Bank Account", isLoading: isLoading) {
                Task { await connectBankAccount() }
            }

            HStack(spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
                Text("Secured by Stripe")
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
            }
        }
        .padding(.horizontal, Spacing.screenPadding)
    }

    private var connectedState: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.agentGreen)

            VStack(spacing: Spacing.md) {
                Text("Payouts Connected")
                    .font(.titleMD)
                    .foregroundStyle(.agentNavy)

                Text("Your bank account is connected and ready to receive payouts.")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)
                    .multilineTextAlignment(.center)
            }

            PillButton("Manage in Stripe Dashboard", variant: .outlined, isLoading: isLoading) {
                Task { await connectBankAccount() }
            }

            HStack(spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
                Text("Secured by Stripe")
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
            }
        }
        .padding(.horizontal, Spacing.screenPadding)
    }

    private func connectBankAccount() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await appState.taskService.createConnectLink()

            // Save connect ID to local profile
            if let userId = user?.id {
                await appState.authService.fetchUserProfile(userId: userId, forceRefresh: true)
            }

            // Open Stripe Connect onboarding in Safari
            if let url = URL(string: response.url) {
                didOpenStripe = true
                openURL(url)
            }
        } catch {
            errorMessage = "Failed to set up payouts: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PayoutSettingsView()
    }
    .environment(AppState.previewRunner)
}
