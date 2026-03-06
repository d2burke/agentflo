import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var prefsService = NotificationPreferencesService()

    var body: some View {
        List {
            // System push notification status
            Section {
                pushStatusRow
            }

            if let prefs = prefsService.preferences {
                Section("Task Activity") {
                    prefToggle(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Task Updates",
                        subtitle: "Status changes, deliverables submitted",
                        value: prefs.taskUpdates
                    ) { prefsService.preferences?.taskUpdates = $0 }

                    prefToggle(
                        icon: "person.badge.plus",
                        title: "New Available Tasks",
                        subtitle: "Tasks posted in your service areas",
                        value: prefs.newAvailableTasks
                    ) { prefsService.preferences?.newAvailableTasks = $0 }
                }

                Section("Communication") {
                    prefToggle(
                        icon: "message.fill",
                        title: "Messages",
                        subtitle: "New messages from agents or runners",
                        value: prefs.messages
                    ) { prefsService.preferences?.messages = $0 }
                }

                Section("Payments") {
                    prefToggle(
                        icon: "dollarsign.circle.fill",
                        title: "Payment Confirmations",
                        subtitle: "Charges, payouts, and receipts",
                        value: prefs.paymentConfirmations
                    ) { prefsService.preferences?.paymentConfirmations = $0 }

                    prefToggle(
                        icon: "chart.bar.fill",
                        title: "Weekly Earnings",
                        subtitle: "Weekly earnings summary",
                        value: prefs.weeklyEarnings
                    ) { prefsService.preferences?.weeklyEarnings = $0 }
                }

                Section("Other") {
                    prefToggle(
                        icon: "megaphone.fill",
                        title: "Product Updates",
                        subtitle: "New features and improvements",
                        value: prefs.productUpdates
                    ) { prefsService.preferences?.productUpdates = $0 }
                }
            }
        }
        .tint(.agentRed)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if prefsService.isLoading {
                ProgressView()
            }
        }
        .task {
            if let userId = appState.authService.currentUser?.id {
                await prefsService.fetch(userId: userId)
            }
        }
    }

    // MARK: - Push Status

    @ViewBuilder
    private var pushStatusRow: some View {
        let pushService = appState.pushService

        HStack(spacing: Spacing.lg) {
            Image(systemName: "bell.fill")
                .font(.system(size: 18))
                .foregroundStyle(pushService.isEnabled ? .agentRed : .agentSlate)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Push Notifications")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)

                if pushService.isEnabled {
                    Text("Enabled")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if pushService.permissionStatus == .denied {
                    Text("Disabled — tap to open Settings")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                } else {
                    Text("Not enabled")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }
            }

            Spacer()

            if pushService.isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if pushService.permissionStatus == .denied {
                Button("Settings") {
                    pushService.openSettings()
                }
                .font(.caption)
                .foregroundStyle(.agentRed)
            } else {
                Button("Enable") {
                    Task { await pushService.requestPermission() }
                }
                .font(.bodyEmphasis)
                .foregroundStyle(.agentRed)
            }
        }
    }

    // MARK: - Preference Toggle

    private func prefToggle(
        icon: String,
        title: String,
        subtitle: String,
        value: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        Toggle(isOn: Binding(
            get: { value },
            set: { newValue in
                onToggle(newValue)
                prefsService.save()
            }
        )) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.agentSlate)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environment(AppState())
    }
}
