import SwiftUI

struct TaskHistoryView: View {
    @Environment(AppState.self) private var appState

    @State private var tasks: [AgentTask] = []
    @State private var isLoading = true
    @State private var selectedFilter: HistoryFilter = .all

    private var user: AppUser? { appState.authService.currentUser }

    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    private var filteredTasks: [AgentTask] {
        switch selectedFilter {
        case .all:
            return tasks.filter { $0.status == .completed || $0.status == .cancelled }
        case .completed:
            return tasks.filter { $0.status == .completed }
        case .cancelled:
            return tasks.filter { $0.status == .cancelled }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.vertical, Spacing.lg)

            if isLoading {
                Spacer()
                LoadingView(message: "Loading history...")
                Spacer()
            } else if filteredTasks.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.lg) {
                        ForEach(filteredTasks) { task in
                            Button {
                                appState.dashboardPath.append(DashboardDestination.taskDetail(task.id))
                                appState.selectedTab = .dashboard
                            } label: {
                                TaskCard(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(.agentBackground)
        .navigationTitle("Task History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTasks() }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No tasks yet",
            message: "Completed and cancelled tasks will appear here."
        )
    }

    private func loadTasks() async {
        guard let user else { return }
        do {
            tasks = try await appState.taskService.fetchTasks(forAgent: user.id)
        } catch {
            print("[TaskHistory] Failed to load: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        TaskHistoryView()
    }
    .environment(AppState.preview)
}
