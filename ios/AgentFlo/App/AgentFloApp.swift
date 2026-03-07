import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    weak var appState: AppState?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard let appState else { return }
        Task { await appState.pushService.registerDeviceToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] Failed to register for remote notifications: \(error)")
    }
}

@main
struct AgentFloApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task {
                    appDelegate.appState = appState

                    // Refresh push status and re-register if already authorized
                    await appState.pushService.refreshPermissionStatus()
                    if appState.pushService.isEnabled {
                        UIApplication.shared.registerForRemoteNotifications()
                    }

                    // Listen for auth changes (runs forever as AsyncSequence)
                    await appState.authService.listenForAuthChanges()
                }
                .onChange(of: appState.authService.currentUser?.id) { oldId, newId in
                    // User changed (login or logout) — re-register push token for new user
                    if let _ = newId, newId != oldId, appState.pushService.isEnabled {
                        Task { await appState.pushService.fetchAndRegisterFCMToken() }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Clear app icon badge when app comes to foreground
                        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
                        // Check biometric lock timeout
                        appState.biometricService.onForeground()
                    } else if newPhase == .background {
                        // Record background time for biometric lock
                        appState.biometricService.onBackground()
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
                    let info = notification.userInfo
                    let destination = info?["destination"] as? String

                    if destination == "directMessage",
                       let conversationId = info?["conversationId"] as? UUID {
                        let senderName = info?["senderName"] as? String ?? ""
                        appState.popToRoot(tab: .messages)
                        appState.deepLink(
                            tab: .messages,
                            destination: MessagesDestination.conversation(conversationId: conversationId, otherUserName: senderName)
                        )
                    } else if destination == "taskMessage",
                              let taskId = info?["taskId"] as? UUID {
                        let senderName = info?["senderName"] as? String ?? ""
                        appState.popToRoot(tab: .messages)
                        appState.deepLink(
                            tab: .messages,
                            destination: MessagesDestination.taskConversation(taskId: taskId, otherUserName: senderName)
                        )
                    } else if let taskId = info?["taskId"] as? UUID {
                        appState.popToRoot(tab: .dashboard)
                        appState.deepLink(tab: .dashboard, destination: DashboardDestination.taskDetail(taskId))
                    }
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
                appState.popToRoot(tab: .messages)
                appState.deepLink(tab: .messages, destination: MessagesDestination.conversation(conversationId: id, otherUserName: ""))
            } else {
                appState.selectedTab = .messages
            }
        case "agent":
            // Universal link: /agent/{slug} → public profile
            if let slug = path.dropFirst().first {
                appState.popToRoot(tab: .dashboard)
                // Slug is the user's profile slug; resolve to UUID in the destination view
                appState.deepLink(tab: .dashboard, destination: DashboardDestination.publicProfileBySlug(slug))
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
