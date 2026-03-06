import Foundation
import UserNotifications
import UIKit
import Supabase

@Observable
final class PushNotificationService: NSObject, UNUserNotificationCenterDelegate {
    var permissionStatus: UNAuthorizationStatus = .notDetermined
    var showPrePrompt = false

    private let lastPromptKey = "lastPushPromptDate"
    private let promptCooldownDays = 7

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
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
    func requestPermission() async -> Bool {
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        showPrePrompt = false

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

    // MARK: - Token Registration

    func registerDeviceToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        do {
            try await supabase.functions.invoke(
                "register-push-token",
                options: .init(body: [
                    "token": token,
                    "platform": "ios",
                ])
            )
            print("[PushNotificationService] Token registered successfully")
        } catch {
            print("[PushNotificationService] Failed to register token: \(error)")
        }
    }

    // MARK: - Notification Handling

    /// Called when notification tapped (app was in background/closed)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler()
    }

    /// Called when notification arrives while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        // Deep link based on notification data
        guard let taskIdString = userInfo["task_id"] as? String,
              let taskId = UUID(uuidString: taskIdString) else { return }

        // Post notification for AppState to handle deep linking
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }

    // MARK: - Open System Settings

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
