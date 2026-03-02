import SwiftUI

struct AgentDashboardView: View {
    @Environment(AppState.self) private var appState

    @State private var tasks: [AgentTask] = []
    @State private var isLoading = true
    @State private var showCreateTask = false
    @State private var hideOnboarding = false
    @State private var showFirstTaskBanner = false
    @AppStorage("hasSeenFirstTaskBanner") private var hasSeenFirstTaskBanner = false
    @AppStorage("hasDismissedDraftBanner") private var hasDismissedDraftBanner = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                // Greeting
                greetingSection

                // Draft task from onboarding — finish it (only once)
                if appState.draftTaskFromOnboarding != nil && !hasDismissedDraftBanner {
                    finishDraftBanner
                }

                // First task posted success banner (only once)
                if showFirstTaskBanner && !hasSeenFirstTaskBanner {
                    firstTaskBanner
                }

                // Onboarding card (if profile incomplete)
                if showOnboarding && !hideOnboarding {
                    onboardingCard
                }

                // Status widgets
                statusWidgets

                // Create task button
                PillButton("Create Task", variant: .primaryLarge, icon: "plus") {
                    showCreateTask = true
                }

                // Recent tasks
                recentTasksSection
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, 100) // Tab bar clearance
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.agentRed)
                }
            }
        }
        .refreshable { await loadTasks() }
        .task { await loadTasks() }
        .sheet(isPresented: $showCreateTask) {
            TaskCreationSheet()
                .presentationDragIndicator(.visible)
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

    // MARK: - Status Widgets

    private var statusWidgets: some View {
        HStack(spacing: Spacing.lg) {
            StatusWidget(
                title: "Posted",
                count: displayTasks.filter { $0.status == .posted }.count,
                color: .agentBlue,
                icon: "paperplane"
            ) {
                appState.dashboardPath.append(DashboardDestination.filteredList(.posted))
            }

            StatusWidget(
                title: "In Progress",
                count: displayTasks.filter { $0.status == .inProgress || $0.status == .accepted }.count,
                color: .agentAmber,
                icon: "arrow.triangle.2.circlepath"
            ) {
                appState.dashboardPath.append(DashboardDestination.filteredList(.inProgress))
            }

            StatusWidget(
                title: "Completed",
                count: displayTasks.filter { $0.status == .completed }.count,
                color: .agentGreen,
                icon: "checkmark.seal"
            ) {
                appState.dashboardPath.append(DashboardDestination.filteredList(.completed))
            }
        }
    }

    // MARK: - Recent Tasks

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Recent Tasks")
                    .font(.titleMD)
                    .foregroundStyle(.agentNavy)
                Spacer()
                Button("View All") {
                    appState.dashboardPath.append(DashboardDestination.allTasks)
                }
                .font(.captionSM)
                .foregroundStyle(.agentRed)
            }

            if isLoading {
                LoadingView()
                    .frame(height: 100)
            } else if displayTasks.isEmpty {
                emptyState
            } else {
                ForEach(displayTasks.prefix(4)) { task in
                    Button {
                        appState.dashboardPath.append(DashboardDestination.taskDetail(task.id))
                    } label: {
                        TaskCard(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "tray",
            title: "No tasks yet",
            message: "Tap \"Create Task\" to post your first task."
        )
    }

    // MARK: - Onboarding

    private var showOnboarding: Bool {
        guard let user = appState.authService.currentUser else { return false }
        let steps = onboardingSteps(for: user)
        return steps.contains(where: { !$0.isComplete })
    }

    private struct OnboardingStep: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let isComplete: Bool
        let destination: ProfileDestination
    }

    private func onboardingSteps(for user: AppUser) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [
            OnboardingStep(
                title: "Personal Info",
                icon: "person.fill",
                isComplete: user.phone != nil && !user.fullName.isEmpty,
                destination: .personalInfo
            ),
            OnboardingStep(
                title: "Payment Method",
                icon: "creditcard.fill",
                isComplete: user.stripeCustomerId != nil,
                destination: .paymentMethods
            ),
        ]
        if user.role == .runner {
            steps.append(contentsOf: [
                OnboardingStep(
                    title: "Service Areas",
                    icon: "mappin.circle.fill",
                    isComplete: false, // TODO: check areas
                    destination: .serviceAreas
                ),
                OnboardingStep(
                    title: "Availability",
                    icon: "clock.fill",
                    isComplete: false, // TODO: check schedule
                    destination: .availability
                ),
            ])
        }
        return steps
    }

    private var onboardingCard: some View {
        let user = appState.authService.currentUser!
        let steps = onboardingSteps(for: user)
        let completedCount = steps.filter(\.isComplete).count
        let incompleteSteps = steps.filter { !$0.isComplete }
        let progress = Double(completedCount) / Double(steps.count)

        return VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header row: title + count + dismiss
            HStack {
                Text("Complete your profile")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(completedCount) of \(steps.count)")
                    .font(.captionSM)
                    .foregroundStyle(.white.opacity(0.7))
                Button {
                    hideOnboarding = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.agentRed)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            // Pill chips for incomplete steps
            FlowLayout(spacing: Spacing.md) {
                ForEach(incompleteSteps) { step in
                    Button {
                        appState.selectedTab = .profile
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            appState.profilePath.append(step.destination)
                        }
                    } label: {
                        Text(step.title)
                            .font(.captionSM)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(Color.agentNavy)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    // MARK: - Finish Draft Banner

    private var finishDraftBanner: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: "doc.text")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.agentAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Finish your task")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Text("Your draft is saved. Post it to find a runner.")
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
                Button("Continue editing \u{2192}") {
                    if let draftId = appState.draftTaskFromOnboarding {
                        appState.dashboardPath.append(DashboardDestination.taskDetail(draftId))
                    }
                }
                .font(.captionSM)
                .foregroundStyle(.agentAmber)
            }

            Spacer()

            Button {
                appState.draftTaskFromOnboarding = nil
                hasDismissedDraftBanner = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.agentSlateLight)
            }
        }
        .padding(Spacing.cardPadding)
        .background(Color.agentAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color.agentAmber.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - First Task Banner

    private var firstTaskBanner: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your first task is live!")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Text("Nearby runners are being notified.")
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
                Button("View Task \u{2192}") {
                    if let firstPosted = tasks.first(where: { $0.status == .posted }) {
                        appState.dashboardPath.append(DashboardDestination.taskDetail(firstPosted.id))
                    }
                }
                .font(.captionSM)
                .foregroundStyle(.agentGreen)
            }

            Spacer()

            Button {
                showFirstTaskBanner = false
                hasSeenFirstTaskBanner = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.agentSlateLight)
            }
        }
        .padding(Spacing.cardPadding)
        .background(Color.agentGreenLight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color.agentGreen.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var displayTasks: [AgentTask] {
        tasks.filter { $0.status != .draft && $0.status != .cancelled }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private func loadTasks() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        do {
            let fetched = try await appState.taskService.fetchTasks(forAgent: userId)
            let oldCount = tasks.filter { $0.status == .posted }.count
            tasks = fetched
            let newCount = fetched.filter { $0.status == .posted }.count
            // Show banner if a new posted task appeared (only once ever)
            if newCount > oldCount && oldCount == 0 && !hasSeenFirstTaskBanner {
                showFirstTaskBanner = true
            }
        } catch {
            print("[AgentDashboard] Failed to load tasks: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Status Widget

struct StatusWidget: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.lg) {
                // Count inside colored circle
                Text("\(count)")
                    .font(.titleMD)
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.captionSM)
                    .foregroundStyle(.agentSlate)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .shadow(color: Shadows.card, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (horizontal wrapping)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        AgentDashboardView()
    }
    .environment(AppState.preview)
}
