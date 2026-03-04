import SwiftUI

enum RunnerTab: String, CaseIterable {
    case myTasks = "My Tasks"
    case available = "Available"
}

struct RunnerDashboardView: View {
    @Environment(AppState.self) private var appState

    @State private var availableTasks: [AgentTask] = []
    @State private var myTasks: [AgentTask] = []
    @State private var isLoading = true
    @State private var selectedTab: RunnerTab = .available

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                // Greeting
                greetingSection

                // Earnings card
                earningsCard

                // Tab picker
                Picker("Tasks", selection: $selectedTab) {
                    ForEach(RunnerTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                // Tab content
                if selectedTab == .myTasks {
                    myTasksContent
                } else {
                    availableTasksContent
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadTasks() }
        .task {
            await loadTasks()
            // Default to My Tasks if user has active tasks
            if !myTasks.filter({ $0.status != .cancelled && $0.status != .completed }).isEmpty {
                selectedTab = .myTasks
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(greeting)
                .font(.bodySM)
                .foregroundStyle(.agentSlate)
            Text(appState.authService.currentUser?.fullName.components(separatedBy: " ").first ?? "")
                .font(.display)
                .foregroundStyle(.agentNavy)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Earnings Card

    private var earningsCard: some View {
        Button {
            appState.dashboardPath.append(DashboardDestination.allTasks)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("This Week")
                    .font(.captionSM)
                    .foregroundStyle(.white.opacity(0.7))

                Text(totalEarnings)
                    .font(.priceMD)
                    .foregroundStyle(.white)

                HStack {
                    Label("\(completedCount) tasks", systemImage: "checkmark.circle")
                    Spacer()
                    Label("View All", systemImage: "arrow.right")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(Spacing.cardPadding)
            .background(LinearGradient.navyGradient)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Available Tasks

    private var availableTasksContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("\(availableTasks.count) available")
                    .font(.captionSM)
                    .foregroundStyle(.agentSlate)
                Spacer()
            }

            if isLoading {
                LoadingView()
                    .frame(height: 100)
            } else if availableTasks.isEmpty {
                EmptyStateView(
                    icon: "mappin.slash",
                    title: "No tasks available",
                    message: "Check back soon or expand your service area."
                )
            } else {
                ForEach(availableTasks) { task in
                    Button {
                        appState.dashboardPath.append(DashboardDestination.taskDetail(task.id))
                    } label: {
                        TaskCard(task: task) { agentId in
                            appState.dashboardPath.append(DashboardDestination.publicProfile(agentId))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - My Tasks

    private var myTasksContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            let activeTasks = myTasks.filter { $0.status != .cancelled }

            if activeTasks.isEmpty && !isLoading {
                EmptyStateView(
                    icon: "square.stack",
                    title: "No active tasks",
                    message: "Tasks you accept will appear here."
                )
            } else {
                ForEach(activeTasks) { task in
                    Button {
                        appState.dashboardPath.append(DashboardDestination.taskDetail(task.id))
                    } label: {
                        TaskCard(task: task) { agentId in
                            appState.dashboardPath.append(DashboardDestination.publicProfile(agentId))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning," }
        if hour < 17 { return "Good afternoon," }
        return "Good evening,"
    }

    private var totalEarnings: String {
        let total = myTasks
            .filter { $0.status == .completed }
            .compactMap { $0.runnerPayout }
            .reduce(0, +)
        return "$\(String(format: "%.0f", Double(total) / 100.0))"
    }

    private var completedCount: Int {
        myTasks.filter { $0.status == .completed }.count
    }

    private func loadTasks() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        do {
            async let available = appState.taskService.fetchAvailableTasks()
            async let mine = appState.taskService.fetchTasks(forRunner: userId)
            availableTasks = try await available
            myTasks = try await mine
        } catch {
            print("[RunnerDashboard] Failed to load tasks: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        RunnerDashboardView()
    }
    .environment(AppState.previewRunner)
}
