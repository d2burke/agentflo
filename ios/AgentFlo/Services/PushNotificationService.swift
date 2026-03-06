import Foundation
import UserNotifications
import UIKit
import Supabase
import FirebaseCore
import FirebaseMessaging

@Observable
final class PushNotificationService {
    var permissionStatus: UNAuthorizationStatus = .notDetermined
    var showPrePrompt = false

    private let lastPromptKey = "lastPushPromptDate"
    private let promptCooldownDays = 7
    private let coordinator = PushNotificationCoordinator()
    private let fcmDelegate = FCMTokenDelegate()

    init() {
        // Configure Firebase before accessing Messaging.
        // @State creates AppState (and this service) before didFinishLaunchingWithOptions,
        // so we must configure here. FirebaseApp.app() guard prevents double-configure crash.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        coordinator.service = self
        fcmDelegate.service = self
        UNUserNotificationCenter.current().delegate = coordinator
        Messaging.messaging().delegate = fcmDelegate
        Task { await refreshPermissionStatus() }
    }

    // MARK: - Permission Status

    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            permissionStatus = settings.authorizationStatus
        }
    }

    var isEnabled: Bool {
        permissionStatus == .authorized || permissionStatus == .provisional
    }

    // MARK: - Progressive Permission Flow

    /// Call this at contextual trigger points (after first task post, first application, etc.)
    func promptIfAppropriate() {
        // Don't prompt if already authorized or denied
        guard permissionStatus == .notDetermined else { return }

        // Check cooldown
        if let lastPrompt = UserDefaults.standard.object(forKey: lastPromptKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            if daysSince < promptCooldownDays { return }
        }

        showPrePrompt = true
    }

    /// User tapped "Enable Notifications" on our pre-prompt UI
    @discardableResult
    func requestPermission() async -> Bool {
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        await MainActor.run { showPrePrompt = false }

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshPermissionStatus()

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("[PushNotificationService] Permission request failed: \(error)")
            return false
        }
    }

    /// User tapped "Not Now" on our pre-prompt UI
    func dismissPrePrompt() {
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        showPrePrompt = false
    }

    // MARK: - Token Registration (FCM)

    /// Called by AppDelegate when APNs provides the device token.
    /// Passes it to Firebase Messaging, which maps it to an FCM registration token.
    func registerDeviceToken(_ deviceToken: Data) async {
        // Hand the raw APNs token to Firebase so it can map to an FCM token
        Messaging.messaging().apnsToken = deviceToken

        // Now fetch the FCM token and register it with our backend
        await fetchAndRegisterFCMToken()
    }

    /// Fetch the current FCM token and register it with the backend.
    /// Silently skips if no authenticated user (token will be registered on login).
    func fetchAndRegisterFCMToken() async {
        // Don't register if no authenticated user — .onChange(of: currentUser?.id)
        // in AgentFloApp will call this again after login
        guard (try? await supabase.auth.session) != nil else {
            print("[PushNotificationService] Skipping FCM token registration — no authenticated user")
            return
        }

        do {
            let fcmToken = try await Messaging.messaging().token()
            try await registerTokenWithBackend(fcmToken)
            print("[PushNotificationService] FCM token registered: \(fcmToken.prefix(20))...")
        } catch {
            print("[PushNotificationService] Failed to get/register FCM token: \(error)")
        }
    }

    /// Called when Firebase Messaging refreshes the FCM token.
    /// Silently skips if no authenticated user (token will be registered on login).
    fileprivate func handleTokenRefresh(_ newToken: String) {
        Task {
            // Don't register if no authenticated user
            guard (try? await supabase.auth.session) != nil else {
                print("[PushNotificationService] Skipping token refresh registration — no authenticated user")
                return
            }

            do {
                try await registerTokenWithBackend(newToken)
                print("[PushNotificationService] Refreshed FCM token registered: \(newToken.prefix(20))...")
            } catch {
                print("[PushNotificationService] Failed to register refreshed token: \(error)")
            }
        }
    }

    private func registerTokenWithBackend(_ token: String) async throws {
        // Refresh session to ensure a valid JWT (same fix as web/firebase.ts)
        _ = try await supabase.auth.refreshSession()
        try await supabase.functions.invoke(
            "register-push-token",
            options: .init(body: [
                "token": token,
                "platform": "ios",
            ])
        )
    }

    // MARK: - Notification Handling

    fileprivate func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String

        // Message notifications — deep link to the conversation
        if type == "new_message" {
            if let conversationIdString = userInfo["conversation_id"] as? String,
               let conversationId = UUID(uuidString: conversationIdString) {
                let senderName = userInfo["sender_name"] as? String ?? ""
                NotificationCenter.default.post(
                    name: .pushNotificationTapped,
                    object: nil,
                    userInfo: [
                        "destination": "directMessage",
                        "conversationId": conversationId,
                        "senderName": senderName,
                    ]
                )
                return
            } else if let taskIdString = userInfo["task_id"] as? String,
                      let taskId = UUID(uuidString: taskIdString) {
                let senderName = userInfo["sender_name"] as? String ?? ""
                NotificationCenter.default.post(
                    name: .pushNotificationTapped,
                    object: nil,
                    userInfo: [
                        "destination": "taskMessage",
                        "taskId": taskId,
                        "senderName": senderName,
                    ]
                )
                return
            }
        }

        // Default: task-based deep link (all other notification types)
        if let taskIdString = userInfo["task_id"] as? String,
           let taskId = UUID(uuidString: taskIdString) {
            NotificationCenter.default.post(
                name: .pushNotificationTapped,
                object: nil,
                userInfo: ["taskId": taskId]
            )
        }
    }

    // MARK: - Open System Settings

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - FCM Token Delegate (NSObject separate from @Observable)

private class FCMTokenDelegate: NSObject, MessagingDelegate {
    weak var service: PushNotificationService?

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("[FCMTokenDelegate] FCM token received: \(fcmToken.prefix(20))...")
        service?.handleTokenRefresh(fcmToken)
    }
}

// MARK: - Notification Coordinator (NSObject separate from @Observable)

private class PushNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    weak var service: PushNotificationService?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        service?.handleNotificationPayload(userInfo)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
