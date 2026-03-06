import Foundation
import UserNotifications
import UIKit
import Supabase

@Observable
final class PushNotificationService {
    var permissionStatus: UNAuthorizationStatus = .notDetermined
    var showPrePrompt = false

    private let lastPromptKey = "lastPushPromptDate"
    private let promptCooldownDays = 7
    private let coordinator = PushNotificationCoordinator()

    init() {
        coordinator.service = self
        UNUserNotificationCenter.current().delegate = coordinator
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

// MARK: - Coordinator (NSObject delegate separate from @Observable)

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
