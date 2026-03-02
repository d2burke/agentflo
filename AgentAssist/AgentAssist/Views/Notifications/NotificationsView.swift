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
                ScrollView {
                    LazyVStack(spacing: Spacing.lg) {
                        ForEach(notifications) { notification in
                            Button {
                                handleTap(notification)
                            } label: {
                                NotificationRow(notification: notification)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Row 1: Icon + title + time ago
            HStack(alignment: .center) {
                HStack(spacing: Spacing.md) {
                    notificationIcon
                        .font(.system(size: 18))
                        .foregroundStyle(notification.isRead ? .agentSlate : .agentRed)
                        .frame(width: 40, height: 40)
                        .background(notification.isRead ? Color.agentBorderLight : Color.agentRedLight)
                        .clipShape(Circle())
                    Text(notification.title)
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)
                }
                Spacer()
                if let createdAt = notification.createdAt {
                    Text(timeAgo(from: createdAt))
                        .font(.captionSM)
                        .foregroundStyle(.agentSlateLight)
                }
            }

            // Row 2: Body text
            Text(notification.body)
                .font(.bodySM)
                .foregroundStyle(.agentSlate)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(Spacing.cardPadding)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(notification.isRead ? Color.clear : Color.agentRedLight, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var notificationIcon: some View {
        switch notification.type {
        case "task_accepted":
            Image(systemName: "checkmark.circle")
        case "task_in_progress":
            Image(systemName: "arrow.triangle.2.circlepath")
        case "task_deliverables_submitted":
            Image(systemName: "doc.text.magnifyingglass")
        case "task_completed":
            Image(systemName: "checkmark.seal.fill")
        case "task_cancelled":
            Image(systemName: "xmark.circle")
        default:
            Image(systemName: "bell.fill")
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .environment(AppState.preview)
}
