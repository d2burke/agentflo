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
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var addressCoordinate: CLLocationCoordinate2D?
    @State private var deliverables: [Deliverable] = []
    @State private var showPhotoUpload = false
    @State private var showDocumentPicker = false
    @State private var showPayoutSetupPrompt = false
    @State private var showShowingReport = false
    @State private var showStagingPhotos = false
    @State private var showingReport: ShowingReport?
    @State private var showQRCode = false
    @State private var showVisitorDashboard = false
    @State private var showReviewSheet = false
    @State private var existingReview: Review?

    private var isAgent: Bool {
        appState.authService.currentUser?.role == .agent
    }

    private var hasPayoutSetup: Bool {
        appState.authService.currentUser?.stripeConnectId != nil
    }

    var body: some View {
        mainContent
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
            .alert("Set Up Payouts", isPresented: $showPayoutSetupPrompt) {
                Button("Set Up Now") {
                    appState.deepLink(tab: .profile, destination: ProfileDestination.payoutSettings)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You need to connect a bank account before accepting tasks. Set up your payout method to get started.")
            }
            .sheet(isPresented: $showPhotoUpload) { photoUploadSheet }
            .sheet(isPresented: $showDocumentPicker) { documentPickerSheet }
            .sheet(isPresented: $showShowingReport) { showingReportSheet }
            .sheet(isPresented: $showStagingPhotos) { stagingPhotosSheet }
            .sheet(isPresented: $showQRCode) { qrCodeSheet }
            .sheet(isPresented: $showVisitorDashboard) { visitorDashboardSheet }
            .sheet(isPresented: $showReviewSheet) { reviewSheet }
    }

    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            LoadingView(message: "Loading task...")
        } else if let task {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    headerSection(task)
                    if addressCoordinate != nil { mapSection(task) }
                    detailsSection(task)
                    if let runnerProfile, isAgent, task.runnerId != nil {
                        runnerInfoSection(runnerProfile, task: task)
                    }
                    if !deliverables.isEmpty { deliverablesSection(task) }
                    messageButton(task)
                    if isAgent { agentActions(task) } else { runnerActions(task) }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        } else {
            ContentUnavailableView("Task Not Found", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - Sheet Views

    @ViewBuilder
    private var photoUploadSheet: some View {
        if let task {
            PhotoUploadView(task: task) {
                showPhotoUpload = false
                Task { await loadTask() }
            }
            .environment(appState)
        }
    }

    @ViewBuilder
    private var documentPickerSheet: some View {
        if let task {
            DocumentUploadView(task: task) {
                showDocumentPicker = false
                Task { await loadTask() }
            }
            .environment(appState)
        }
    }

    @ViewBuilder
    private var showingReportSheet: some View {
        if let task {
            ShowingReportForm(task: task) {
                showShowingReport = false
                Task { await loadTask() }
            }
            .environment(appState)
        }
    }

    @ViewBuilder
    private var stagingPhotosSheet: some View {
        if let task {
            StagingPhotoView(task: task) {
                showStagingPhotos = false
                Task { await loadTask() }
            }
            .environment(appState)
        }
    }

    @ViewBuilder
    private var qrCodeSheet: some View {
        if let task {
            OpenHouseQRView(task: task)
                .environment(appState)
        }
    }

    @ViewBuilder
    private var visitorDashboardSheet: some View {
        if let task {
            OpenHouseVisitorDashboard(taskId: task.id)
                .environment(appState)
        }
    }

    @ViewBuilder
    private var reviewSheet: some View {
        if let task {
            let otherName: String = {
                if isAgent { return runnerProfile?.fullName ?? "the runner" }
                else { return task.agentProfile?.fullName ?? "the agent" }
            }()
             ReviewSheet(task: task, revieweeName: otherName) {
                showReviewSheet = false
                Task {
                    if let userId = appState.authService.currentUser?.id {
                        existingReview = try? await appState.taskService.fetchReviewByUser(
                            taskId: taskId, reviewerId: userId
                        )
                    }
                }
            }
            .environment(appState)
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

                    if isAgent {
                        // Agent view: runner pay + service fee = total
                        HStack {
                            Text("Runner Pay")
                                .font(.bodySM)
                            Spacer()
                            Text(task.formattedPrice)
                                .font(.bodyEmphasis)
                        }
                        HStack {
                            Text("Service Fee")
                                .font(.bodySM)
                            Spacer()
                            Text("+$\(String(format: "%.0f", Double(fee) / 100.0))")
                                .font(.bodySM)
                                .foregroundStyle(.agentSlate)
                        }
                        Divider()
                        HStack {
                            Text("Your Total")
                                .font(.bodyEmphasis)
                            Spacer()
                            Text("$\(String(format: "%.0f", Double(task.price + fee) / 100.0))")
                                .font(.bodyEmphasis)
                                .foregroundStyle(.agentNavy)
                        }
                    } else {
                        // Runner view: just their payout (= full task price)
                        HStack {
                            Text("Your Payout")
                                .font(.bodyEmphasis)
                            Spacer()
                            Text("$\(String(format: "%.0f", Double(payout) / 100.0))")
                                .font(.bodyEmphasis)
                                .foregroundStyle(.agentGreen)
                        }
                    }
                }
                .padding(Spacing.cardPadding)
                .background(.agentSurface)
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

            Button {
                appState.dashboardPath.append(DashboardDestination.publicProfile(profile.id))
            } label: {
                HStack(spacing: Spacing.lg) {
                    CachedAvatarView(avatarPath: profile.avatarUrl, name: profile.fullName, size: 44)

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
            .buttonStyle(.plain)
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
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
                PillButton("Request Revision", variant: .secondary, isLoading: isActionLoading) {
                    Task { await requestRevision() }
                }
            case .completed:
                if task.completedAt != nil {
                    Label("Completed", systemImage: "checkmark.seal.fill")
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentGreen)
                        .frame(maxWidth: .infinity)
                }
                if existingReview == nil {
                    PillButton("Leave Review", variant: .secondary, icon: "star") {
                        showReviewSheet = true
                    }
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
                if !hasPayoutSetup {
                    payoutSetupBanner
                }
                PillButton("Accept Task", variant: .primary, isLoading: isActionLoading) {
                    if hasPayoutSetup {
                        Task { await applyForTask() }
                    } else {
                        showPayoutSetupPrompt = true
                    }
                }
            case .accepted:
                if task.isCheckInCheckOut {
                    checkInSection(task)
                } else {
                    startTaskSection(task)
                }
            case .inProgress:
                inProgressActions(task)
            case .deliverablesSubmitted:
                Label("Deliverables Submitted", systemImage: "checkmark.circle.fill")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentGreen)
                    .frame(maxWidth: .infinity)
            case .completed:
                Label("Completed", systemImage: "checkmark.seal.fill")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentGreen)
                    .frame(maxWidth: .infinity)
                if existingReview == nil {
                    PillButton("Leave Review", variant: .secondary, icon: "star") {
                        showReviewSheet = true
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func checkInSection(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.md) {
            Text("Check in at the property to start this task.")
                .font(.bodySM)
                .foregroundStyle(.agentSlate)
                .frame(maxWidth: .infinity, alignment: .leading)

            PillButton("Check In", variant: .primary, isLoading: isActionLoading) {
                Task { await checkIn() }
            }
        }
    }

    @ViewBuilder
    private func startTaskSection(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.md) {
            Text("Ready to begin? Tap below to start working on this task.")
                .font(.bodySM)
                .foregroundStyle(.agentSlate)
                .frame(maxWidth: .infinity, alignment: .leading)

            PillButton("Start Task", variant: .primary, isLoading: isActionLoading) {
                Task { await startTask() }
            }
        }
    }

    @ViewBuilder
    private func inProgressActions(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.lg) {
            // Show check-in timestamp
            if let checkedIn = task.checkedInAt {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.agentGreen)
                    Text("Checked in \(checkedIn.formatted(date: .omitted, time: .shortened))")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                    Spacer()
                }
            }

            if task.taskCategory == .showing {
                PillButton("Check Out & Report", variant: .primary, isLoading: isActionLoading) {
                    Task {
                        await checkOut()
                        showShowingReport = true
                    }
                }
            } else if task.taskCategory == .staging {
                PillButton("Capture Staging Photos", variant: .primary) {
                    showStagingPhotos = true
                }
                PillButton("Check Out", variant: .secondary, isLoading: isActionLoading) {
                    Task { await checkOut() }
                }
            } else if task.taskCategory == .openHouse {
                HStack(spacing: Spacing.md) {
                    PillButton("Show QR Code", variant: .primary) {
                        showQRCode = true
                    }
                    PillButton("Visitors", variant: .secondary) {
                        showVisitorDashboard = true
                    }
                }
                PillButton("Check Out", variant: .secondary, isLoading: isActionLoading) {
                    Task { await checkOut() }
                }
            } else if task.isCheckInCheckOut {
                PillButton("Check Out", variant: .primary, isLoading: isActionLoading) {
                    Task { await checkOut() }
                }
            } else if task.taskCategory == .photography {
                PillButton("Upload Photos", variant: .primary) {
                    showPhotoUpload = true
                }
            } else if task.taskCategory == .inspection {
                let hasLocalDraft = appState.inspectionService.hasLocalDraft(taskId: task.id)
                PillButton(hasLocalDraft ? "Continue Inspection" : "Start Inspection", variant: .primary) {
                    appState.dashboardPath.append(DashboardDestination.inspectionChecklist(task.id))
                }
            }

            PillButton("Cancel Task", variant: .outlined, isLoading: isCancelLoading) {
                showCancelAlert = true
            }
        }
    }

    // MARK: - Deliverables Section

    @ViewBuilder
    private func deliverablesSection(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Deliverables")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            // Showing report (if exists)
            if let report = showingReport {
                showingReportCard(report)
            }

            // Staging before/after comparison
            let stagingPhotos = deliverables.filter { $0.photoType != nil }
            if !stagingPhotos.isEmpty {
                StagingComparisonView(deliverables: stagingPhotos)
            }

            // Open house visitor summary (after checkout)
            if task.taskCategory == .openHouse && (task.status == .deliverablesSubmitted || task.status == .completed) {
                OpenHouseVisitorDashboard(taskId: task.id, isLive: false)
                    .environment(appState)
            }

            // Inspection report link
            if task.taskCategory == .inspection && (task.status == .deliverablesSubmitted || task.status == .completed) {
                Button {
                    appState.dashboardPath.append(DashboardDestination.inspectionReport(task.id))
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(.agentRed)
                        Text("View Inspection Report")
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.agentSlateLight)
                    }
                    .padding(Spacing.cardPadding)
                    .background(.agentSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    .shadow(color: Shadows.card, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }

            if task.isCheckInCheckOut {
                CheckInCheckOutCard(task: task, deliverables: deliverables)
            } else {
                let photos = deliverables.filter { $0.type == .photo && $0.photoType == nil }
                let documents = deliverables.filter { $0.type == .document || $0.type == .report }

                if !photos.isEmpty {
                    PhotoGalleryView(deliverables: photos)
                }
                if !documents.isEmpty {
                    DocumentListView(deliverables: documents)
                }
            }
        }
    }

    private func showingReportCard(_ report: ShowingReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.agentRed)
                Text("Showing Report")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                reportRow(label: "Buyer", value: report.buyerName)
                reportRow(label: "Interest", value: report.buyerInterest.displayName)

                if let feedback = report.propertyFeedback, !feedback.isEmpty {
                    reportRow(label: "Feedback", value: feedback)
                }
                if let notes = report.followUpNotes, !notes.isEmpty {
                    reportRow(label: "Follow-Up", value: notes)
                }
                if let next = report.nextSteps, !next.isEmpty {
                    reportRow(label: "Next Steps", value: next)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func reportRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            Text(value)
                .font(.bodySM)
                .foregroundStyle(.agentNavy)
        }
    }

    // MARK: - Message Button

    @ViewBuilder
    private func messageButton(_ task: AgentTask) -> some View {
        let canMessage = task.status == .accepted || task.status == .inProgress
            || task.status == .deliverablesSubmitted || task.status == .revisionRequested

        if canMessage {
            let otherName: String = {
                if isAgent {
                    return runnerProfile?.fullName ?? "Runner"
                } else {
                    return task.agentProfile?.fullName ?? "Agent"
                }
            }()

            Button {
                appState.dashboardPath.append(
                    DashboardDestination.messaging(taskId: task.id, otherUserName: otherName)
                )
            } label: {
                HStack {
                    Image(systemName: "message.fill")
                    Text("Message \(otherName)")
                }
                .font(.bodyEmphasis)
                .foregroundStyle(.agentNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(.agentSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                .shadow(color: Shadows.card, radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Payout Setup Banner

    private var payoutSetupBanner: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Set up payouts to accept tasks")
                .font(.bodySM)
                .foregroundStyle(.agentNavy)
            Spacer()
        }
        .padding(Spacing.cardPadding)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
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
                } catch {
                    showError("Failed to load runner profile")
                }
            }
            // Load deliverables if applicable
            if let status = task?.status,
               status == .deliverablesSubmitted || status == .completed || status == .revisionRequested || status == .inProgress {
                do {
                    deliverables = try await appState.taskService.fetchDeliverables(taskId: taskId)
                } catch {
                    showError("Failed to load deliverables")
                }
            }
            // Load showing report for showing tasks
            if task?.taskCategory == .showing {
                do {
                    showingReport = try await appState.taskService.fetchShowingReport(taskId: taskId)
                } catch {
                    showError("Failed to load showing report")
                }
            }
            // Geocode address for map
            if let address = task?.propertyAddress, !address.isEmpty {
                await geocodeAddress(address)
            }
            // Check for existing review on completed tasks
            if let status = task?.status, status == .completed,
               let userId = appState.authService.currentUser?.id {
                existingReview = try? await appState.taskService.fetchReviewByUser(
                    taskId: taskId, reviewerId: userId
                )
            }
        } catch {
            showError("Failed to load task")
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
            // Geocoding failure is non-critical — map simply won't show
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
            showReviewSheet = true
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

    private func checkIn() async {
        isActionLoading = true
        do {
            let coord = try await appState.locationService.getCurrentLocation()
            try await appState.taskService.checkIn(taskId: taskId, lat: coord.latitude, lng: coord.longitude)
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isActionLoading = false
    }

    private func checkOut() async {
        isActionLoading = true
        do {
            let coord = try await appState.locationService.getCurrentLocation()
            try await appState.taskService.checkOut(taskId: taskId, lat: coord.latitude, lng: coord.longitude)
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isActionLoading = false
    }

    private func requestRevision() async {
        isActionLoading = true
        do {
            try await appState.taskService.updateTaskStatus(taskId: taskId, status: "revision_requested")
            await loadTask()
        } catch {
            showError(error.localizedDescription)
        }
        isActionLoading = false
    }

    private func startTask() async {
        isActionLoading = true
        do {
            try await appState.taskService.startTask(taskId: taskId)
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
