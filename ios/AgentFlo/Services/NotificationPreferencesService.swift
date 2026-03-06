import Foundation
import Supabase

struct NotificationPreferences: Codable {
    var userId: UUID
    var taskUpdates: Bool
    var messages: Bool
    var paymentConfirmations: Bool
    var newAvailableTasks: Bool
    var weeklyEarnings: Bool
    var productUpdates: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case taskUpdates = "task_updates"
        case messages
        case paymentConfirmations = "payment_confirmations"
        case newAvailableTasks = "new_available_tasks"
        case weeklyEarnings = "weekly_earnings"
        case productUpdates = "product_updates"
    }

    static func defaults(userId: UUID) -> NotificationPreferences {
        NotificationPreferences(
            userId: userId,
            taskUpdates: true,
            messages: true,
            paymentConfirmations: true,
            newAvailableTasks: true,
            weeklyEarnings: true,
            productUpdates: false
        )
    }
}

@Observable
final class NotificationPreferencesService {
    var preferences: NotificationPreferences?
    var isLoading = false
    var error: String?

    private var saveTask: Task<Void, Never>?

    func fetch(userId: UUID) async {
        isLoading = true
        error = nil

        do {
            let response: NotificationPreferences = try await supabase
                .from("notification_preferences")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value

            await MainActor.run {
                self.preferences = response
                self.isLoading = false
            }
        } catch {
            // No row yet — use defaults
            await MainActor.run {
                self.preferences = .defaults(userId: userId)
                self.isLoading = false
            }
        }
    }

    func save() {
        guard let preferences else { return }

        // Debounce: cancel previous save, wait 500ms
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            do {
                try await supabase
                    .from("notification_preferences")
                    .upsert(preferences)
                    .execute()
            } catch {
                print("[NotificationPreferencesService] Save failed: \(error)")
                await MainActor.run {
                    self.error = "Failed to save preferences"
                }
            }
        }
    }
}
