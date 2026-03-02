import SwiftUI
import MapKit

struct TaskDetailView: View {
    let taskId: UUID

    @Environment(AppState.self) private var appState
    @State private var task: AgentTask?
    @State private var isLoading = true
    @State private var isActionLoading = false
    @State private var isCancelLoading = false
    @State private var errorMessage: String?
    @State private var showCancelAlert = false
    @State private var runnerProfile: PublicProfile?
    @State private var runnerAvatarImage: Image?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var addressCoordinate: CLLocationCoordinate2D?

    private var isAgent: Bool {
        appState.authService.currentUser?.role == .agent
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading task...")
            } else if let task {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                        headerSection(task)

                        // Map
                        if addressCoordinate != nil {
                            mapSection(task)
                        }

                        detailsSection(task)
                        if let runnerProfile, isAgent, task.runnerId != nil {
                            runnerInfoSection(runnerProfile, task: task)
                        }
                        if isAgent {
                            agentActions(task)
                        } else {
                            runnerActions(task)
                        }
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            } else {
                ContentUnavailableView("Task Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .background(.agentBackground)
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTask() }
        .toast(errorMessage ?? "", style: .error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ))
        .alert("Cancel Task?", isPresented: $showCancelAlert) {
            Button("Keep Task", role: .cancel) {}
            Button("Cancel Task", role: .destructive) {
                Task { await cancelTask() }
            }
        } message: {
            if let task, task.status == .accepted || task.status == .inProgress {
                Text("This task has been accepted by a runner. A cancellation fee may apply.")
            } else {
                Text("Are you sure you want to cancel this task?")
            }
        }
    }

    // MARK: - Map

    private func mapSection(_ task: AgentTask) -> some View {
        Map(position: $mapPosition) {
            if let coord = addressCoordinate {
                Marker(task.propertyAddress, coordinate: coord)
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .allowsHitTesting(false)
    }

    // MARK: - Header

    private func headerSection(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                CategoryIcon(category: task.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.category)
                        .font(.titleMD)
                        .foregroundStyle(.agentNavy)
                    StatusBadge(status: task.status)
                }
                Spacer()
                Text(task.formattedPrice)
                    .font(.priceSM)
                    .foregroundStyle(.agentNavy)
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Details

    private func detailsSection(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            DetailRow(icon: "mappin", label: "Location", value: task.propertyAddress)

            if let scheduledAt = task.scheduledAt {
                DetailRow(icon: "calendar", label: "Scheduled", value: scheduledAt.formatted(date: .long, time: .shortened))
            }

            if let instructions = task.instructions, !instructions.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Instructions")
                        .font(.captionSM)
                        .foregroundStyle(.agentSlate)
                    Text(instructions)
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                }
            }

            if let fee = task.platformFee, let payout = task.runnerPayout {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Payment Breakdown")
                        .font(.captionSM)
                        .foregroundStyle(.agentSlate)
                    HStack {
                        Text("Task Price")
                            .font(.bodySM)
                        Spacer()
                        Text(task.formattedPrice)
                            .font(.bodyEmphasis)
                    }
                    HStack {
                        Text("Platform Fee")
                            .font(.bodySM)
                        Spacer()
                        Text("-$\(String(format: "%.0f", Double(fee) / 100.0))")
                            .font(.bodySM)
                            .foregroundStyle(.agentSlate)
                    }
                    Divider()
                    HStack {
                        Text("Runner Payout")
                            .font(.bodyEmphasis)
                        Spacer()
                        Text("$\(String(format: "%.0f", Double(payout) / 100.0))")
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentGreen)
                    }
                }
                .padding(Spacing.cardPadding)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            }
        }
    }

    // MARK: - Runner Info (visible to agent)

    private func runnerInfoSection(_ profile: PublicProfile, task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Assigned Runner")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            HStack(spacing: Spacing.lg) {
                AvatarView(image: runnerAvatarImage, name: profile.fullName, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.fullName)
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)
                    if let acceptedAt = task.acceptedAt {
                        Text("Accepted \(timeAgo(from: acceptedAt))")
                            .font(.caption)
                            .foregroundStyle(.agentSlate)
                    }
                }

                Spacer()

                StatusBadge(status: task.status)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Agent Actions

    @ViewBuilder
    private func agentActions(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.lg) {
            switch task.status {
            case .posted:
                PillButton("Cancel Task", variant: .outlined, isLoading: isCancelLoading) {
                    showCancelAlert = true
                }
            case .accepted, .inProgress:
                // Can still cancel but with fee warning
                PillButton("Cancel Task", variant: .outlined, isLoading: isCancelLoading) {
                    showCancelAlert = true
                }
            case .deliverablesSubmitted:
                PillButton("Approve & Release Payment", variant: .primary, isLoading: isActionLoading) {
                    Task { await approveAndPay() }
                }
                PillButton("Request Revision", variant: .secondary) {
                    // TODO: Request revision
                }
            case .completed:
                if task.completedAt != nil {
                    Label("Completed", systemImage: "checkmark.seal.fill")
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentGreen)
                        .frame(maxWidth: .infinity)
                }
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Runner Actions

    @ViewBuilder
    private func runnerActions(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.lg) {
            switch task.status {
            case .posted:
                PillButton("Accept Task", variant: .primary, isLoading: isActionLoading) {
                    Task { await applyForTask() }
                }
            case .accepted:
                PillButton("Mark In Progress", variant: .primary, isLoading: isActionLoading) {
                    Task { await updateTaskStatus(to: "in_progress") }
                }
            case .inProgress:
                PillButton("Submit Deliverables", variant: .primary, isLoading: isActionLoading) {
                    Task { await submitDeliverables() }
                }
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Error

    private func showError(_ message: String) {
        errorMessage = message
    }

    // MARK: - Data Loading

    private func loadTask() async {
        do {
            task = try await appState.taskService.fetchTask(id: taskId)
            // Load runner profile if task has a runner assigned
            if let runnerId = task?.runnerId, isAgent {
                do {
                    runnerProfile = try await appState.taskService.fetchUserPublicProfile(userId: runnerId)
                    // Load runner avatar
                    if let avatarUrl = runnerProfile?.avatarUrl, !avatarUrl.isEmpty {
                        let data = try await supabase.storage.from("avatars").download(path: avatarUrl)
                        if let uiImage = UIImage(data: data) {
                            runnerAvatarImage = Image(uiImage: uiImage)
                        }
                    }
                } catch {
                    print("[TaskDetail] Failed to load runner profile: \(error)")
                }
            }
            // Geocode address for map
            if let address = task?.propertyAddress, !address.isEmpty {
                await geocodeAddress(address)
            }
        } catch {
            print("[TaskDetail] Failed to load: \(error)")
        }
        isLoading = false
    }

    private func geocodeAddress(_ address: String) async {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let location = placemarks.first?.location?.coordinate {
                addressCoordinate = location
                mapPosition = .region(MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        } catch {
            print("[TaskDetail] Geocoding failed: \(error)")
        }
    }

    private func cancelTask() async {
        isCancelLoading = true
        do {
            try await appState.taskService.cancelTask(taskId: taskId, reason: nil)
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isCancelLoading = false
    }

    private func approveAndPay() async {
        isActionLoading = true
        do {
            try await appState.taskService.approveAndPay(taskId: taskId)
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isActionLoading = false
    }

    private func applyForTask() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        isActionLoading = true
        do {
            try await appState.taskService.applyForTask(taskId: taskId, runnerId: userId, message: nil)
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isActionLoading = false
    }

    private func updateTaskStatus(to status: String) async {
        isActionLoading = true
        do {
            try await appState.taskService.updateTaskStatus(taskId: taskId, status: status)
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isActionLoading = false
    }

    private func submitDeliverables() async {
        isActionLoading = true
        do {
            try await appState.taskService.submitDeliverables(taskId: taskId, deliverables: [])
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isActionLoading = false
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.agentSlate)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.captionSM)
                    .foregroundStyle(.agentSlate)
                Text(value)
                    .font(.bodySM)
                    .foregroundStyle(.agentNavy)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(taskId: AgentTask.preview.id)
    }
    .environment(AppState.preview)
}
