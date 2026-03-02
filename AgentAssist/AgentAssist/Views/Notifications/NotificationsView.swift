import SwiftUI

struct NotificationsView: View {
    @Environment(AppState.self) private var appState

    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false

    var body: some View {
        Group {
            if isLoading && !hasLoadedOnce {
                LoadingView(message: "Loading notifications...")
            } else if notifications.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell.slash",
                    description: Text("You're all caught up.")
                )
            } else {
                List {
                    ForEach(notifications) { notification in
                        NotificationRow(notification: notification)
                            .onTapGesture {
                                handleTap(notification)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(.agentBackground)
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Deep link to Profile > Notification Settings
                    appState.selectedTab = .profile
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appState.profilePath.append(ProfileDestination.notificationSettings)
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.agentSlate)
                }
            }
        }
        .refreshable { await loadNotifications() }
        .task { await loadNotifications() }
        .onAppear {
            // Reload every time the tab is selected (not just first appearance)
            if hasLoadedOnce {
                Task { await loadNotifications() }
            }
        }
    }

    private func handleTap(_ notification: AppNotification) {
        // Mark as read
        if !notification.isRead {
            let now = Date()
            Task {
                try? await supabase
                    .from("notifications")
                    .update(["read_at": ISO8601DateFormatter().string(from: now)])
                    .eq("id", value: notification.id.uuidString)
                    .execute()
            }
            if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[idx].readAt = now
            }
        }

        if let taskIdStr = notification.data?["task_id"],
           let taskId = UUID(uuidString: taskIdStr) {
            appState.selectedTab = .dashboard
            appState.dashboardPath.append(DashboardDestination.taskDetail(taskId))
        }
    }

    private func loadNotifications() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        do {
            notifications = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
        } catch {
            print("[Notifications] Failed to load: \(error)")
        }
        isLoading = false
        hasLoadedOnce = true
    }
}

struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            Circle()
                .fill(notification.isRead ? Color.agentBorderLight : Color.agentRedLight)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(notification.title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
                    .lineLimit(2)
                if let createdAt = notification.createdAt {
                    Text(createdAt, style: .relative)
                        .font(.captionSM)
                        .foregroundStyle(.agentSlateLight)
                }
            }
        }
        .padding(.vertical, Spacing.md)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .environment(AppState.preview)
}
