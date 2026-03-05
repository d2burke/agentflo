import SwiftUI

struct FilteredTaskListView: View {
    let filterStatus: TaskStatus

    @Environment(AppState.self) private var appState
    @State private var tasks: [AgentTask] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading tasks...")
            } else if tasks.isEmpty {
                ContentUnavailableView(
                    "No \(filterStatus.displayName) Tasks",
                    systemImage: filterStatus.iconName,
                    description: Text("Tasks with this status will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.lg) {
                        ForEach(filteredTasks) { task in
                            Button {
                                appState.dashboardPath.append(DashboardDestination.taskDetail(task.id))
                            } label: {
                                TaskCard(task: task)
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
        .navigationTitle(filterStatus.displayName)
        .task { await loadTasks() }
    }

    private var filteredTasks: [AgentTask] {
        tasks.filter { task in
            switch filterStatus {
            case .inProgress:
                return task.status == .inProgress || task.status == .accepted
            default:
                return task.status == filterStatus
            }
        }
    }

    private func loadTasks() async {
        guard let user = appState.authService.currentUser else { return }
        do {
            if user.role == .agent {
                tasks = try await appState.taskService.fetchTasks(forAgent: user.id)
            } else {
                tasks = try await appState.taskService.fetchTasks(forRunner: user.id)
            }
        } catch {
            print("[FilteredTaskList] Failed to load: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FilteredTaskListView(filterStatus: .posted)
    }
    .environment(AppState.preview)
}
