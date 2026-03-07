import SwiftUI
import MapKit
import Photos

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
    @State private var visitors: [OpenHouseVisitor] = []
    @State private var photoSaveMessage: String?

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
            .toast(photoSaveMessage ?? "", style: .success, isPresented: Binding(
                get: { photoSaveMessage != nil },
                set: { if !$0 { photoSaveMessage = nil } }
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
                VStack(spacing: 9) {
                    heroCard(task)

                    if task.taskCategory == .openHouse && task.status == .inProgress {
                        liveCounterSection
                    }

                    if let chips = statsChips(for: task), !chips.isEmpty {
                        StatChipsRow(chips: chips)
                    }

                    paymentCard(task)

                    if let runnerProfile, isAgent, task.runnerId != nil {
                        runnerCard(runnerProfile, task: task)
                    }

                    if shouldShowDeliverables(task) {
                        deliverablesCard(task)
                    }

                    actionButtons(task)
                }
                .padding(.horizontal, 13)
                .padding(.top, 3)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        } else {
            ContentUnavailableView("Task Not Found", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: icon + name + price
            HStack(alignment: .top) {
                HStack(spacing: Spacing.md) {
                    CategoryIcon(category: task.category)
                    Text(task.category)
                        .font(.taskName)
                        .tracking(-0.4)
                        .foregroundStyle(.agentNavy)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(task.formattedPrice)
                        .font(.priceHero)
                        .tracking(-0.7)
                        .foregroundStyle(.agentNavy)
                    Text("Total")
                        .font(.custom("DMSans-Medium", size: 10))
                        .foregroundStyle(.agentSlate)
                }
            }
            .padding(.bottom, 7)

            // Status badge
            StatusBadge(status: task.status, category: task.taskCategory)
                .padding(.bottom, 12)

            // Map
            if addressCoordinate != nil {
                mapSection(task)
                    .padding(.bottom, 10)
            }

            // Detail rows
            detailRows(task)
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    // MARK: - Map

    private func mapSection(_ task: AgentTask) -> some View {
        Map(position: $mapPosition) {
            if let coord = addressCoordinate {
                Annotation("", coordinate: coord) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.agentRed)
                        .background(Circle().fill(.white).frame(width: 12, height: 12))
                }
            }
        }
        .frame(height: 124)
        .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner))
        .allowsHitTesting(false)
        .opacity(isTaskDone(task) ? 0.55 : 1.0)
    }

    // MARK: - Detail Rows

    private func detailRows(_ task: AgentTask) -> some View {
        VStack(spacing: 0) {
            TaskDetailRow(icon: "mappin", label: "LOCATION", value: task.propertyAddress)

            detailSeparator

            if let scheduledAt = task.scheduledAt {
                TaskDetailRow(icon: "calendar", label: "SCHEDULED", value: scheduledAt.formatted(date: .long, time: .shortened))
                detailSeparator
            }

            if let instructions = task.instructions, !instructions.isEmpty {
                TaskDetailRow(icon: "doc.text", label: "INSTRUCTIONS", value: instructions)
                detailSeparator
            }

            if let formData = task.categoryFormData {
                if let rooms = formData["rooms"] {
                    TaskDetailRow(icon: "square.grid.2x2", label: "ROOMS", value: rooms)
                    detailSeparator
                }
                if let packageType = formData["package"] {
                    TaskDetailRow(icon: "tag", label: "PACKAGE", value: packageType)
                    detailSeparator
                }
                if let duration = formData["duration"] {
                    TaskDetailRow(icon: "clock", label: "EST. DURATION", value: duration)
                }
            }
        }
    }

    private var detailSeparator: some View {
        Rectangle()
            .fill(Color(red: 0.941, green: 0.941, blue: 0.961))
            .frame(height: 1)
            .padding(.vertical, 5)
    }

    // MARK: - Stats Chips

    private func statsChips(for task: AgentTask) -> [(value: String, label: String, accent: Bool)]? {
        let cat = task.taskCategory
        switch (cat, task.status) {
        case (.photography, .inProgress):
            let photoCount = deliverables.filter { $0.type == .photo && $0.photoType == nil }.count
            let rooms = task.categoryFormData?["rooms"] ?? "--"
            return [
                (value: "\(photoCount)", label: "Shot", accent: false),
                (value: rooms, label: "Rooms", accent: false),
            ]
        case (.photography, .deliverablesSubmitted), (.photography, .completed):
            let photoCount = deliverables.filter { $0.type == .photo && $0.photoType == nil }.count
            return [
                (value: "\(photoCount)", label: "Photos", accent: false),
                (value: "24h", label: "Delivery", accent: false),
            ]
        case (.staging, .accepted), (.staging, .inProgress):
            let rooms = task.categoryFormData?["rooms"] ?? "3"
            let style = task.categoryFormData?["style"] ?? "Modern"
            return [
                (value: rooms, label: "Rooms", accent: false),
                (value: style, label: "Style", accent: false),
            ]
        case (.staging, .deliverablesSubmitted), (.staging, .completed):
            let rooms = task.categoryFormData?["rooms"] ?? "3"
            let duration = durationString(from: task)
            return [
                (value: rooms, label: "Rooms", accent: false),
                (value: duration, label: "Duration", accent: false),
            ]
        case (.openHouse, .completed), (.openHouse, .deliverablesSubmitted):
            let visitorCount = visitors.count
            let leadCount = visitors.filter { $0.email != nil || $0.phone != nil }.count
            let duration = durationString(from: task)
            return [
                (value: "\(visitorCount)", label: "Visitors", accent: true),
                (value: "\(leadCount)", label: "Leads", accent: false),
                (value: duration, label: "Duration", accent: false),
            ]
        case (.inspection, .inProgress):
            return [
                (value: "--", label: "Areas Done", accent: false),
                (value: "--", label: "Remaining", accent: false),
            ]
        case (.inspection, .deliverablesSubmitted), (.inspection, .completed):
            return [
                (value: "--", label: "Score", accent: true),
                (value: "--", label: "Findings", accent: false),
            ]
        default:
            return nil
        }
    }

    // MARK: - Payment Card

    private func paymentCard(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAYMENT")
                .font(.payLabel)
                .tracking(0.8)
                .foregroundStyle(.agentSlate)
                .padding(.bottom, 11)

            if let fee = task.platformFee {
                if isAgent {
                    payRow(name: "Runner Pay", amount: task.formattedPrice, isBold: false)
                    payDivider
                    payRow(name: "Service Fee", amount: "+$\(String(format: "%.0f", Double(fee) / 100.0))", isBold: false, isFee: true)
                    payDivider
                    HStack {
                        Text("Your Total")
                            .font(.custom("DMSans-Bold", size: 12.5))
                            .foregroundStyle(.agentNavy)
                        Spacer()
                        Text("$\(String(format: "%.0f", Double(task.price + fee) / 100.0))")
                            .font(.payTotal)
                            .tracking(-0.5)
                            .foregroundStyle(.agentRed)
                    }
                    .padding(.top, 8)
                } else {
                    let payout = task.runnerPayout ?? task.price
                    payRow(name: "Your Payout", amount: "$\(String(format: "%.0f", Double(payout) / 100.0))", isBold: true)
                }
            } else {
                payRow(name: isAgent ? "Task Price" : "Your Payout", amount: task.formattedPrice, isBold: true)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func payRow(name: String, amount: String, isBold: Bool, isFee: Bool = false) -> some View {
        HStack {
            Text(name)
                .font(isBold ? .custom("DMSans-Bold", size: 12.5) : .custom("DMSans-Medium", size: 12))
                .foregroundStyle(isBold ? .agentNavy : Color(red: 0.227, green: 0.227, blue: 0.306))
            Spacer()
            Text(amount)
                .font(.payAmount)
                .foregroundStyle(isFee ? .agentSlate : .agentNavy)
        }
        .padding(.bottom, 8)
    }

    private var payDivider: some View {
        Rectangle()
            .fill(Color(red: 0.941, green: 0.941, blue: 0.961))
            .frame(height: 1)
            .padding(.bottom, 8)
    }

    // MARK: - Runner Card

    private func runnerCard(_ profile: PublicProfile, task: AgentTask) -> some View {
        VStack(spacing: Spacing.base) {
            Button {
                appState.dashboardPath.append(DashboardDestination.publicProfile(profile.id))
            } label: {
                HStack(spacing: 9) {
                    CachedAvatarView(avatarPath: profile.avatarUrl, name: profile.fullName, size: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.fullName)
                            .font(.runnerName)
                            .foregroundStyle(.agentNavy)
                        if let acceptedAt = task.acceptedAt {
                            Text(timeAgo(from: acceptedAt))
                                .font(.runnerTime)
                                .foregroundStyle(.agentSlate)
                        }
                    }

                    Spacer()

                    StatusBadge(status: task.status, category: task.taskCategory)
                }
            }
            .buttonStyle(.plain)

            messageButton(task)
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    // MARK: - Message Button

    @ViewBuilder
    private func messageButton(_ task: AgentTask) -> some View {
        let canMessage = task.status == .accepted || task.status == .inProgress
            || task.status == .deliverablesSubmitted || task.status == .revisionRequested

        if canMessage {
            let otherName: String = {
                if isAgent { return runnerProfile?.fullName ?? "Runner" }
                else { return task.agentProfile?.fullName ?? "Agent" }
            }()

            Button {
                appState.dashboardPath.append(
                    DashboardDestination.messaging(taskId: task.id, otherUserName: otherName)
                )
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 13))
                    Text("Message \(otherName)")
                        .font(.custom("DMSans-Bold", size: 12))
                }
                .foregroundStyle(.agentNavy)
                .frame(maxWidth: .infinity)
                .frame(height: 37)
                .background(Color(red: 0.961, green: 0.961, blue: 0.969))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Live Counter

    @ViewBuilder
    private var liveCounterSection: some View {
        LiveCounterCard(
            count: visitors.count,
            subtitle: "Currently Checked In",
            meta: visitors.isEmpty ? nil : "\(recentArrivals) arrivals in last 10 min"
        )
    }

    private var recentArrivals: Int {
        let tenMinAgo = Calendar.current.date(byAdding: .minute, value: -10, to: Date()) ?? Date()
        return visitors.filter { ($0.createdAt ?? Date.distantPast) > tenMinAgo }.count
    }

    // MARK: - Deliverables

    private func shouldShowDeliverables(_ task: AgentTask) -> Bool {
        let hasStatus = task.status == .deliverablesSubmitted || task.status == .completed
            || task.status == .revisionRequested || task.status == .inProgress
        return hasStatus && (!deliverables.isEmpty || showingReport != nil || !visitors.isEmpty)
    }

    @ViewBuilder
    private func deliverablesCard(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let report = showingReport, task.taskCategory == .showing {
                showingNotesCard(report)
            }

            let photos = deliverables.filter { $0.type == .photo && $0.photoType == nil }
            if task.taskCategory == .photography && !photos.isEmpty {
                photoGridCard(photos)
            }

            let stagingPhotos = deliverables.filter { $0.photoType != nil }
            if task.taskCategory == .staging && !stagingPhotos.isEmpty {
                stagingChecklistCard(stagingPhotos, task: task)
            }

            if task.taskCategory == .openHouse && (task.status == .deliverablesSubmitted || task.status == .completed) {
                visitorReportCard(task)
            }

            if task.taskCategory == .inspection && (task.status == .deliverablesSubmitted || task.status == .completed) {
                inspectionReportButton(task)
            }

            if task.isCheckInCheckOut && task.checkedInAt != nil {
                CheckInCheckOutCard(task: task, deliverables: deliverables)
            }

            let documents = deliverables.filter { $0.type == .document || $0.type == .report }
            if !documents.isEmpty {
                DocumentListView(deliverables: documents)
            }
        }
    }

    private func showingNotesCard(_ report: ShowingReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let feedback = report.propertyFeedback, !feedback.isEmpty {
                Text(feedback)
                    .font(.custom("DMSans-Medium", size: 12))
                    .italic()
                    .foregroundStyle(.agentNavy)
                    .lineSpacing(6)
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.961, green: 0.961, blue: 0.969))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    Image(systemName: i < ratingFromReport(report) ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.961, green: 0.620, blue: 0.043))
                }
                Spacer()
                if let createdAt = report.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.runnerTime)
                        .foregroundStyle(.agentSlate)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func ratingFromReport(_ report: ShowingReport) -> Int {
        switch report.buyerInterest {
        case .notInterested: return 1
        case .somewhatInterested: return 3
        case .veryInterested: return 4
        case .likelyOffer: return 5
        }
    }

    private func photoGridCard(_ photos: [Deliverable]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            let displayPhotos = Array(photos.prefix(6))
            let remaining = photos.count - 6

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                ForEach(Array(displayPhotos.enumerated()), id: \.element.id) { index, photo in
                    ZStack {
                        if let url = photo.fileUrl, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().aspectRatio(4/3, contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color(red: 0.941, green: 0.941, blue: 0.961))
                            }
                        } else {
                            Rectangle().fill(Color(red: 0.941, green: 0.941, blue: 0.961))
                        }

                        if index == 5 && remaining > 0 {
                            Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.75)
                            Text("+\(remaining)")
                                .font(.custom("DMSans-ExtraBold", size: 13))
                                .foregroundStyle(.white)
                        }
                    }
                    .aspectRatio(4/3, contentMode: .fit)
                    .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await savePhotosToLibrary(photos) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                    Text("Download All")
                        .font(.custom("DMSans-Bold", size: 11))
                }
                .foregroundStyle(.agentRed)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Color.agentRedLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func stagingChecklistCard(_ photos: [Deliverable], task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            let rooms = Set(photos.compactMap { $0.room })
            ForEach(Array(rooms.sorted()), id: \.self) { room in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.910, green: 0.973, blue: 0.933))
                            .frame(width: 21, height: 21)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.102, green: 0.561, blue: 0.306))
                    }
                    Text(room)
                        .font(.custom("DMSans-SemiBold", size: 12.5))
                        .foregroundStyle(.agentNavy)
                }
                .padding(.vertical, 5)
            }

            if let completedAt = task.checkedOutAt ?? task.completedAt {
                Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.runnerTime)
                    .foregroundStyle(.agentSlate)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func visitorReportCard(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            let leadVisitors = visitors.filter { $0.email != nil || $0.phone != nil }

            Text("\(visitors.count) visitors, \(leadVisitors.count) leads")
                .font(.custom("DMSans-SemiBold", size: 12))
                .foregroundStyle(.agentNavy)
                .padding(.bottom, 4)

            ForEach(Array(leadVisitors.prefix(3))) { visitor in
                VStack(alignment: .leading, spacing: 2) {
                    Text(visitor.visitorName)
                        .font(.custom("DMSans-Bold", size: 11.5))
                        .foregroundStyle(.agentNavy)
                    if let email = visitor.email {
                        Text(email)
                            .font(.runnerTime)
                            .foregroundStyle(.agentSlate)
                    }
                }
                .padding(.vertical, 5)
                if visitor.id != leadVisitors.prefix(3).last?.id {
                    Divider()
                }
            }

            if leadVisitors.count > 3 {
                Text("+\(leadVisitors.count - 3) more leads")
                    .font(.runnerTime)
                    .foregroundStyle(.agentSlate)
                    .padding(.top, 2)
            }

            Button {
                exportLeadsCSV()
            } label: {
                Text("Export Leads")
                    .font(.custom("DMSans-Bold", size: 11.5))
                    .foregroundStyle(.agentNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color(red: 0.961, green: 0.961, blue: 0.969))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.top, 5)
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func inspectionReportButton(_ task: AgentTask) -> some View {
        Button {
            appState.dashboardPath.append(DashboardDestination.inspectionReport(task.id))
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                Text("View Full Inspection Report")
                    .font(.custom("DMSans-Bold", size: 12))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.102, green: 0.102, blue: 0.180), Color(red: 0.165, green: 0.165, blue: 0.306)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.2), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(_ task: AgentTask) -> some View {
        if isAgent { agentActions(task) } else { runnerActions(task) }
    }

    @ViewBuilder
    private func agentActions(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.lg) {
            switch task.status {
            case .posted, .accepted, .inProgress:
                cancelButton
            case .deliverablesSubmitted:
                primaryActionButton("Approve & Release Payment", icon: "checkmark.seal", isLoading: isActionLoading) {
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

    @ViewBuilder
    private func runnerActions(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.lg) {
            switch task.status {
            case .posted:
                if !hasPayoutSetup { payoutSetupBanner }
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

    private func primaryActionButton(_ title: String, icon: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Image(systemName: icon).font(.system(size: 12))
                }
                Text(title).font(.custom("DMSans-Bold", size: 12))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.102, green: 0.102, blue: 0.180), Color(red: 0.165, green: 0.165, blue: 0.306)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.2), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var cancelButton: some View {
        Button {
            showCancelAlert = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                Text("Cancel Task").font(.custom("DMSans-Bold", size: 12))
            }
            .foregroundStyle(.agentRed)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(Color(red: 0.910, green: 0.910, blue: 0.933), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Runner In-Progress

    @ViewBuilder
    private func checkInSection(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.md) {
            Text("Check in at the property to start this task.")
                .font(.bodySM).foregroundStyle(.agentSlate)
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
                .font(.bodySM).foregroundStyle(.agentSlate)
                .frame(maxWidth: .infinity, alignment: .leading)
            PillButton("Start Task", variant: .primary, isLoading: isActionLoading) {
                Task { await startTask() }
            }
        }
    }

    @ViewBuilder
    private func inProgressActions(_ task: AgentTask) -> some View {
        VStack(spacing: Spacing.lg) {
            if let checkedIn = task.checkedInAt {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "location.fill").foregroundStyle(.agentGreen)
                    Text("Checked in \(checkedIn.formatted(date: .omitted, time: .shortened))")
                        .font(.bodySM).foregroundStyle(.agentSlate)
                    Spacer()
                }
            }

            if task.taskCategory == .showing {
                PillButton("Check Out & Report", variant: .primary, isLoading: isActionLoading) {
                    Task { await checkOut(); showShowingReport = true }
                }
            } else if task.taskCategory == .staging {
                PillButton("Capture Staging Photos", variant: .primary) { showStagingPhotos = true }
                PillButton("Check Out", variant: .secondary, isLoading: isActionLoading) {
                    Task { await checkOut() }
                }
            } else if task.taskCategory == .openHouse {
                HStack(spacing: Spacing.md) {
                    PillButton("Show QR Code", variant: .primary) { showQRCode = true }
                    PillButton("Visitors", variant: .secondary) { showVisitorDashboard = true }
                }
                PillButton("Check Out", variant: .secondary, isLoading: isActionLoading) {
                    Task { await checkOut() }
                }
            } else if task.isCheckInCheckOut {
                PillButton("Check Out", variant: .primary, isLoading: isActionLoading) {
                    Task { await checkOut() }
                }
            } else if task.taskCategory == .photography {
                PillButton("Upload Photos", variant: .primary) { showPhotoUpload = true }
            } else if task.taskCategory == .inspection {
                let hasLocalDraft = appState.inspectionService.hasLocalDraft(taskId: task.id)
                PillButton(hasLocalDraft ? "Continue Inspection" : "Start Inspection", variant: .primary) {
                    appState.dashboardPath.append(DashboardDestination.inspectionChecklist(task.id))
                }
            }

            cancelButton
        }
    }

    // MARK: - Payout Setup Banner

    private var payoutSetupBanner: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Set up payouts to accept tasks").font(.bodySM).foregroundStyle(.agentNavy)
            Spacer()
        }
        .padding(Spacing.cardPadding)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    // MARK: - Sheet Views

    @ViewBuilder private var photoUploadSheet: some View {
        if let task { PhotoUploadView(task: task) { showPhotoUpload = false; Task { await loadTask() } }.environment(appState) }
    }
    @ViewBuilder private var documentPickerSheet: some View {
        if let task { DocumentUploadView(task: task) { showDocumentPicker = false; Task { await loadTask() } }.environment(appState) }
    }
    @ViewBuilder private var showingReportSheet: some View {
        if let task { ShowingReportForm(task: task) { showShowingReport = false; Task { await loadTask() } }.environment(appState) }
    }
    @ViewBuilder private var stagingPhotosSheet: some View {
        if let task { StagingPhotoView(task: task) { showStagingPhotos = false; Task { await loadTask() } }.environment(appState) }
    }
    @ViewBuilder private var qrCodeSheet: some View {
        if let task { OpenHouseQRView(task: task).environment(appState) }
    }
    @ViewBuilder private var visitorDashboardSheet: some View {
        if let task { OpenHouseVisitorDashboard(taskId: task.id).environment(appState) }
    }
    @ViewBuilder private var reviewSheet: some View {
        if let task {
            let otherName: String = {
                if isAgent { return runnerProfile?.fullName ?? "the runner" }
                else { return task.agentProfile?.fullName ?? "the agent" }
            }()
            ReviewSheet(task: task, revieweeName: otherName) {
                showReviewSheet = false
                Task {
                    if let userId = appState.authService.currentUser?.id {
                        existingReview = try? await appState.taskService.fetchReviewByUser(taskId: taskId, reviewerId: userId)
                    }
                }
            }.environment(appState)
        }
    }

    // MARK: - Helpers

    private func isTaskDone(_ task: AgentTask) -> Bool {
        task.status == .completed || task.status == .deliverablesSubmitted || task.status == .cancelled
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func durationString(from task: AgentTask) -> String {
        guard let start = task.checkedInAt, let end = task.checkedOutAt ?? task.completedAt else { return "--" }
        let hours = end.timeIntervalSince(start) / 3600
        if hours < 1 { return "\(Int(hours * 60)) min" }
        return String(format: "%.1f hrs", hours)
    }

    // MARK: - Export Leads

    private func exportLeadsCSV() {
        var csv = "Name,Email,Phone,Interest Level\n"
        for v in visitors {
            let name = v.visitorName.replacingOccurrences(of: ",", with: " ")
            csv += "\(name),\(v.email ?? ""),\(v.phone ?? ""),\(v.interestDisplayName)\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("open-house-leads.csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            errorMessage = "Failed to export leads"
        }
    }

    // MARK: - Photo Save

    private func savePhotosToLibrary(_ photos: [Deliverable]) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            errorMessage = "Photo library access denied"
            return
        }

        var savedCount = 0
        for photo in photos {
            guard let urlString = photo.fileUrl, let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { continue }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                savedCount += 1
            } catch { continue }
        }
        photoSaveMessage = "Saved \(savedCount) photos to camera roll"
    }

    // MARK: - Error

    private func showError(_ message: String) { errorMessage = message }

    // MARK: - Data Loading

    private func loadTask() async {
        do {
            task = try await appState.taskService.fetchTask(id: taskId)
            if let runnerId = task?.runnerId, isAgent {
                do { runnerProfile = try await appState.taskService.fetchUserPublicProfile(userId: runnerId) }
                catch { showError("Failed to load runner profile") }
            }
            if let status = task?.status,
               status == .deliverablesSubmitted || status == .completed || status == .revisionRequested || status == .inProgress {
                do { deliverables = try await appState.taskService.fetchDeliverables(taskId: taskId) }
                catch { showError("Failed to load deliverables") }
            }
            if task?.taskCategory == .showing {
                do { showingReport = try await appState.taskService.fetchShowingReport(taskId: taskId) }
                catch { showError("Failed to load showing report") }
            }
            if task?.taskCategory == .openHouse {
                do { visitors = try await appState.taskService.fetchVisitors(taskId: taskId) }
                catch { /* non-critical */ }
            }
            if let address = task?.propertyAddress, !address.isEmpty { await geocodeAddress(address) }
            if let status = task?.status, status == .completed,
               let userId = appState.authService.currentUser?.id {
                existingReview = try? await appState.taskService.fetchReviewByUser(taskId: taskId, reviewerId: userId)
            }
        } catch { showError("Failed to load task") }
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
        } catch { /* non-critical */ }
    }

    private func cancelTask() async {
        isCancelLoading = true
        do { try await appState.taskService.cancelTask(taskId: taskId, reason: nil); await loadTask() }
        catch { showError(error.localizedDescription) }
        isCancelLoading = false
    }

    private func approveAndPay() async {
        isActionLoading = true
        do { try await appState.taskService.approveAndPay(taskId: taskId); await loadTask(); showReviewSheet = true }
        catch { showError(error.localizedDescription) }
        isActionLoading = false
    }

    private func applyForTask() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        isActionLoading = true
        do { try await appState.taskService.applyForTask(taskId: taskId, runnerId: userId, message: nil); await loadTask() }
        catch { showError(error.localizedDescription) }
        isActionLoading = false
    }

    private func checkIn() async {
        isActionLoading = true
        do {
            let coord = try await appState.locationService.getCurrentLocation()
            try await appState.taskService.checkIn(taskId: taskId, lat: coord.latitude, lng: coord.longitude)
            await loadTask()
        } catch { showError(error.localizedDescription) }
        isActionLoading = false
    }

    private func checkOut() async {
        isActionLoading = true
        do {
            let coord = try await appState.locationService.getCurrentLocation()
            try await appState.taskService.checkOut(taskId: taskId, lat: coord.latitude, lng: coord.longitude)
            await loadTask()
        } catch { showError(error.localizedDescription) }
        isActionLoading = false
    }

    private func requestRevision() async {
        isActionLoading = true
        do { try await appState.taskService.updateTaskStatus(taskId: taskId, status: "revision_requested"); await loadTask() }
        catch { showError(error.localizedDescription) }
        isActionLoading = false
    }

    private func startTask() async {
        isActionLoading = true
        do { try await appState.taskService.startTask(taskId: taskId); await loadTask() }
        catch { showError(error.localizedDescription) }
        isActionLoading = false
    }
}

// MARK: - Task Detail Row

struct TaskDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.agentSlate)
                .frame(width: 26, height: 26)
                .background(Color(red: 0.961, green: 0.961, blue: 0.969))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.detailLabel)
                    .tracking(0.7)
                    .foregroundStyle(.agentSlate)
                    .textCase(.uppercase)
                Text(value)
                    .font(.detailValue)
                    .foregroundStyle(.agentNavy)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(taskId: AgentTask.preview.id)
    }
    .environment(AppState.preview)
}
