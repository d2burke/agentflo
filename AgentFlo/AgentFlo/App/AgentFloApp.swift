import SwiftUI

@main
struct AgentFloApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task {
                    await appState.authService.listenForAuthChanges()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "agentflo" else { return }

        switch url.host {
        case "stripe-connect":
            // User returned from Stripe Connect onboarding
            // Refresh the user profile to pick up the new stripe_connect_id
            if let userId = appState.authService.currentUser?.id {
                Task { await appState.authService.fetchUserProfile(userId: userId) }
            }
            // Navigate to profile > payout settings
            appState.selectedTab = .profile
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appState.profilePath = NavigationPath()
                appState.profilePath.append(ProfileDestination.payoutSettings)
            }
        default:
            break
        }
    }
}
