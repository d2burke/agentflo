import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab("Dashboard", systemImage: "house.fill", value: .dashboard) {
                NavigationStack(path: $state.dashboardPath) {
                    dashboardContent
                        .navigationDestination(for: DashboardDestination.self) { destination in
                            switch destination {
                            case .taskDetail(let id):
                                TaskDetailView(taskId: id)
                            case .filteredList(let status):
                                FilteredTaskListView(filterStatus: status)
                            case .allTasks:
                                AllTasksView()
                            }
                        }
                }
            }

            Tab("Notifications", systemImage: "bell.fill", value: .notifications) {
                NavigationStack(path: $state.notificationsPath) {
                    NotificationsView()
                        .navigationDestination(for: NotificationDestination.self) { destination in
                            switch destination {
                            case .settings:
                                NotificationSettingsView()
                            }
                        }
                }
            }

            Tab("Profile", systemImage: "person.fill", value: .profile) {
                NavigationStack(path: $state.profilePath) {
                    ProfileHomeView()
                        .navigationDestination(for: ProfileDestination.self) { destination in
                            profileDestinationView(for: destination)
                        }
                }
            }
        }
        .tint(.agentRed)
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if appState.authService.currentUser?.role == .runner {
            RunnerDashboardView()
        } else {
            AgentDashboardView()
        }
    }

    @ViewBuilder
    private func profileDestinationView(for destination: ProfileDestination) -> some View {
        switch destination {
        case .personalInfo:
            PersonalInfoView()
        case .paymentMethods:
            PaymentMethodsView()
        case .payoutSettings:
            PayoutSettingsView()
        case .notificationSettings:
            NotificationSettingsView()
        case .taskHistory:
            TaskHistoryView()
        case .earnings:
            EarningsView()
        case .serviceAreas:
            ServiceAreasView()
        case .availability:
            AvailabilityView()
        case .accountSecurity:
            AccountSecurityView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState.preview)
}
