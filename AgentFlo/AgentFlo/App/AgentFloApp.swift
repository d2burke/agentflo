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
        if url.scheme == "agentflo" {
            handleCustomSchemeLink(url)
        } else if url.scheme == "https",
                  let host = url.host,
                  (host == "agentflo.app" || host == "www.agentflo.app") {
            handleUniversalLink(url)
        }
    }

    private func handleCustomSchemeLink(_ url: URL) {
        switch url.host {
        case "stripe-connect":
            if let userId = appState.authService.currentUser?.id {
                Task { await appState.authService.fetchUserProfile(userId: userId) }
            }
            appState.selectedTab = .profile
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appState.profilePath = NavigationPath()
                appState.profilePath.append(ProfileDestination.payoutSettings)
            }
        default:
            break
        }
    }

    private func handleUniversalLink(_ url: URL) {
        let path = url.pathComponents.filter { $0 != "/" }
        guard let first = path.first else { return }

        switch first {
        case "tasks":
            if let id = path.dropFirst().first.flatMap({ UUID(uuidString: $0) }) {
                appState.popToRoot(tab: .dashboard)
                appState.deepLink(tab: .dashboard, destination: DashboardDestination.taskDetail(id))
            }
        case "messages":
            if let id = path.dropFirst().first.flatMap({ UUID(uuidString: $0) }) {
                appState.popToRoot(tab: .dashboard)
                appState.deepLink(tab: .dashboard, destination: DashboardDestination.directMessaging(conversationId: id, otherUserName: ""))
            }
        case "profile":
            appState.selectedTab = .profile
        case "notifications":
            appState.selectedTab = .notifications
        case "stripe-connect":
            if let userId = appState.authService.currentUser?.id {
                Task { await appState.authService.fetchUserProfile(userId: userId) }
            }
            appState.popToRoot(tab: .profile)
            appState.deepLink(tab: .profile, destination: ProfileDestination.payoutSettings)
        default:
            break
        }
    }
}
