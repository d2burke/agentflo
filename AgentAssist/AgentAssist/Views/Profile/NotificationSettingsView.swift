import SwiftUI

struct NotificationSettingsView: View {
    @State private var pushEnabled = true
    @State private var taskUpdates = true
    @State private var newApplications = true
    @State private var messages = true
    @State private var paymentAlerts = true
    @State private var marketing = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $pushEnabled) {
                    settingRow(icon: "bell.fill", title: "Push Notifications", subtitle: "Receive alerts on your device")
                }
            }

            Section("Task Activity") {
                Toggle(isOn: $taskUpdates) {
                    settingRow(icon: "arrow.triangle.2.circlepath", title: "Task Updates", subtitle: "Status changes, deliverables submitted")
                }
                Toggle(isOn: $newApplications) {
                    settingRow(icon: "person.badge.plus", title: "New Applications", subtitle: "When runners apply to your tasks")
                }
                Toggle(isOn: $messages) {
                    settingRow(icon: "message.fill", title: "Messages", subtitle: "New messages from agents or runners")
                }
            }

            Section("Payments") {
                Toggle(isOn: $paymentAlerts) {
                    settingRow(icon: "dollarsign.circle.fill", title: "Payment Alerts", subtitle: "Charges, payouts, and receipts")
                }
            }

            Section("Other") {
                Toggle(isOn: $marketing) {
                    settingRow(icon: "megaphone.fill", title: "Tips & Updates", subtitle: "Product news and helpful tips")
                }
            }
        }
        .tint(.agentRed)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingRow(icon: String, title: String, subtitle: String) -> some View {
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

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
