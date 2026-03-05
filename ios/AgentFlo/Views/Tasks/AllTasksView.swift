import SwiftUI

struct AllTasksView: View {
    @Environment(AppState.self) private var appState

    @State private var tasks: [AgentTask] = []
    @State private var isLoading = true
    @State private var selectedFilter: TaskStatus?

    private var isAgent: Bool {
        appState.authService.currentUser?.role == .agent
    }

    private var filteredTasks: [AgentTask] {
        guard let filter = selectedFilter else {
            return tasks.filter { $0.status != .draft }
        }
        return tasks.filter { task in
            switch filter {
            case .inProgress:
                return task.status == .inProgress || task.status == .accepted
            default:
                return task.status == filter
            }
        }
    }

    private let filters: [TaskStatus] = [.posted, .inProgress, .deliverablesSubmitted, .completed, .cancelled]

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    FilterChip(title: "All", isSelected: selectedFilter == nil) {
                        selectedFilter = nil
                    }
                    ForEach(filters, id: \.self) { status in
                        FilterChip(title: status.displayName, isSelected: selectedFilter == status) {
                            selectedFilter = status
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.vertical, Spacing.lg)
            }
            .background(.agentSurface)

            Divider()

            // Task list
            if isLoading {
                Spacer()
                LoadingView(message: "Loading tasks...")
                Spacer()
            } else if filteredTasks.isEmpty {
                Spacer()
                ContentUnavailableView(
                    selectedFilter == nil ? "No Tasks" : "No \(selectedFilter!.displayName) Tasks",
                    systemImage: "tray",
                    description: Text("Tasks matching this filter will appear here.")
                )
                Spacer()
            } else {
                ScrollView(.vertical) {
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
                    .padding(.vertical, Spacing.lg)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(.agentBackground)
        .navigationTitle("All Tasks")
        .task { await loadTasks() }
        .refreshable { await loadTasks() }
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
            print("[AllTasks] Failed to load: \(error)")
        }
        isLoading = false
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.captionSM)
                .foregroundStyle(isSelected ? .white : .agentNavy)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.agentRed : Color.agentBorderLight)
                .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AllTasksView()
    }
    .environment(AppState.preview)
}
