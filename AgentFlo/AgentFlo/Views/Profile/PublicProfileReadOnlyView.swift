import SwiftUI

struct PublicProfileReadOnlyView: View {
    let userId: UUID

    @Environment(AppState.self) private var appState
    @State private var profile: PublicProfileFull?
    @State private var reviews: [Review] = []
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var isFavorited = false

    private var isSelf: Bool {
        appState.authService.currentUser?.id == userId
    }

    private static let roleLabels: [UserRole: String] = [
        .agent: "Licensed Real Estate Agent",
        .runner: "Licensed Field Professional",
    ]

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading profile...")
            } else if let profile {
                profileContent(profile)
            } else {
                ContentUnavailableView("Profile Not Found", systemImage: "person.slash")
            }
        }
        .background(.agentBackground)
        .navigationBarHidden(true)
        .task { await loadProfile() }
    }

    // MARK: - Main Content

    private func profileContent(_ profile: PublicProfileFull) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection(profile)
                    nameSection(profile)
                    statsCard(profile)
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.top, Spacing.sectionGap)
                    tabPicker
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.top, Spacing.sectionGap)
                    tabContent(profile)
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.top, Spacing.sectionGap)
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            bottomBar(profile)
        }
    }

    // MARK: - Hero

    private func heroSection(_ profile: PublicProfileFull) -> some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.11, blue: 0.24),
                    Color(red: 0.24, green: 0.17, blue: 0.30),
                    Color(red: 0.29, green: 0.21, blue: 0.35),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 260)

            // Nav buttons overlay
            VStack {
                HStack {
                    navButton(systemName: "chevron.left") {
                        appState.dashboardPath.removeLast()
                    }
                    Spacer()
                    HStack(spacing: Spacing.md) {
                        navButton(systemName: "square.and.arrow.up") {}
                        navButton(systemName: "ellipsis") {}
                    }
                }
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.top, 56)
                Spacer()
            }
            .frame(height: 260)

            // Avatar overlapping the gradient
            ZStack(alignment: .bottom) {
                CachedAvatarView(avatarPath: profile.avatarUrl, name: profile.fullName, size: 120)
                    .overlay(
                        Circle()
                            .stroke(Color.agentSurface, lineWidth: 4)
                    )

                // Online indicator
                Circle()
                    .fill(Color.agentGreen)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.agentSurface, lineWidth: 2))
                    .offset(x: 20, y: -2)
            }
            .offset(y: 60)
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.agentNavy.opacity(0.6))
                .clipShape(Circle())
        }
    }

    // MARK: - Name + Location

    private func nameSection(_ profile: PublicProfileFull) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: Spacing.sm) {
                Text(profile.fullName)
                    .font(.titleLG)
                    .foregroundStyle(.agentNavy)
                if profile.isVerified {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.agentRed)
                        .font(.system(size: 18))
                }
            }

            if let brokerage = profile.brokerage, !brokerage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 13))
                    Text(brokerage)
                        .font(.bodySM)
                }
                .foregroundStyle(.agentSlate)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Stats Card

    private func statsCard(_ profile: PublicProfileFull) -> some View {
        HStack(spacing: 0) {
            statItem(
                icon: "star.fill",
                value: profile.avgRating.map { String(format: "%.1f", $0) } ?? "—",
                label: "Rating"
            )
            statDivider
            statItem(
                icon: "checkmark.circle.fill",
                value: "\(profile.completedTasks)",
                label: "Completed"
            )
            statDivider
            statItem(
                icon: "clock.fill",
                value: "< 15 min",
                label: "Response"
            )
        }
        .padding(.vertical, Spacing.xxxl)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.agentBorder)
            .frame(width: 1, height: 40)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.agentRed)
                .frame(width: 40, height: 40)
                .background(Color.agentRedLight.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            Text(value)
                .font(.titleMD)
                .foregroundStyle(.agentNavy)

            Text(label)
                .font(.micro)
                .foregroundStyle(.agentSlate)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tabs

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(["About", "Reviews", "Activity"].enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                } label: {
                    Text(title)
                        .font(.captionSM)
                        .foregroundStyle(selectedTab == index ? .agentNavy : .agentSlate)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.base)
                        .background(selectedTab == index ? Color.agentSurface : Color.agentBorderLight)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .stroke(Color.agentBorder, lineWidth: 1)
        )
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(_ profile: PublicProfileFull) -> some View {
        switch selectedTab {
        case 0: aboutTab(profile)
        case 1: reviewsTab
        default: activityTab
        }
    }

    // MARK: - About Tab

    private func aboutTab(_ profile: PublicProfileFull) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            // Bio
            if let bio = profile.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    sectionLabel("ABOUT")
                    Text(bio)
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                        .lineSpacing(4)
                }
            } else if let headline = profile.headline, !headline.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    sectionLabel("ABOUT")
                    Text(headline)
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                        .lineSpacing(4)
                }
            }

            // Specialties
            if let specialties = profile.specialties, !specialties.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    sectionLabel("SPECIALTIES")
                    FlowLayout(spacing: 8) {
                        ForEach(specialties, id: \.self) { specialty in
                            let displayName = TaskCategory(rawValue: specialty)?.displayName ?? specialty.capitalized
                            Text(displayName)
                                .font(.micro)
                                .foregroundStyle(.agentRed)
                                .padding(.horizontal, Spacing.xxl)
                                .padding(.vertical, Spacing.sm)
                                .background(Color.agentRedLight.opacity(0.5))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.agentRed.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            // Info Card
            infoCard(profile)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.micro)
            .foregroundStyle(.agentRed)
            .tracking(1)
    }

    // MARK: - Info Card

    private func infoCard(_ profile: PublicProfileFull) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INFO")
                .font(.micro)
                .foregroundStyle(.agentSlate)
                .tracking(1)
                .padding(.bottom, Spacing.xxl)

            infoRow(
                icon: "building.2.fill",
                label: "Role",
                value: Self.roleLabels[profile.role] ?? profile.role.rawValue.capitalized
            )

            if let brokerage = profile.brokerage, !brokerage.isEmpty {
                infoRow(icon: "mappin.circle.fill", label: "Location", value: brokerage)
            }

            if let createdAt = profile.createdAt {
                infoRow(icon: "clock.fill", label: "Member Since", value: memberSinceString(createdAt))
            }

            infoRow(icon: "checkmark.circle.fill", label: "Completion Rate", value: "98%")
            infoRow(icon: "star.fill", label: "On-Time Rate", value: "99%", isLast: true)
        }
        .padding(Spacing.screenPadding)
        .background(Color.agentBorderLight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private func memberSinceString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func infoRow(icon: String, label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: Spacing.lg) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.agentRed)
                        .frame(width: 32, height: 32)
                        .background(Color.agentRedLight.opacity(0.5))
                        .clipShape(Circle())

                    Text(label)
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                }
                Spacer()
                Text(value)
                    .font(.captionSM)
                    .foregroundStyle(.agentNavy)
            }
            .padding(.vertical, Spacing.xl)

            if !isLast {
                Divider()
                    .foregroundStyle(.agentBorder)
            }
        }
    }

    // MARK: - Reviews Tab

    private var reviewsTab: some View {
        VStack(spacing: Spacing.lg) {
            if reviews.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "star")
                        .font(.system(size: 32))
                        .foregroundStyle(.agentSlateLight)
                        .frame(width: 48, height: 48)
                        .background(Color.agentBorderLight)
                        .clipShape(Circle())
                    Text("\(profile?.reviewCount ?? 0) Review\(profile?.reviewCount == 1 ? "" : "s")")
                        .font(.captionSM)
                        .foregroundStyle(.agentNavy)
                    Text("Reviews coming soon")
                        .font(.micro)
                        .foregroundStyle(.agentSlate)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxxl * 2)
            } else {
                ForEach(reviews) { review in
                    reviewCard(review)
                }
            }
        }
    }

    private func reviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(star <= review.rating ? .agentAmber : .agentSlateLight)
                    }
                }
                Spacer()
                if let date = review.createdAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.agentSlateLight)
                }
            }

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.bodySM)
                    .foregroundStyle(.agentNavy)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    // MARK: - Activity Tab

    private var activityTab: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundStyle(.agentSlateLight)
                .frame(width: 48, height: 48)
                .background(Color.agentBorderLight)
                .clipShape(Circle())
            Text("No activity yet")
                .font(.captionSM)
                .foregroundStyle(.agentNavy)
            Text("Recent activity will appear here")
                .font(.micro)
                .foregroundStyle(.agentSlate)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxxl * 2)
    }

    // MARK: - Bottom Bar

    private func bottomBar(_ profile: PublicProfileFull) -> some View {
        HStack(spacing: Spacing.lg) {
            // Favorite button
            Button {
                isFavorited.toggle()
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(isFavorited ? .agentRed : .agentSlate)
                    .frame(width: 48, height: 48)
                    .background(.agentSurface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isFavorited ? Color.agentRed.opacity(0.3) : Color.agentBorder, lineWidth: 1)
                    )
            }

            // Send Task Request / Edit Profile
            if isSelf {
                PillButton("Edit Profile", variant: .primary) {
                    appState.selectedTab = .profile
                    appState.profilePath.append(ProfileDestination.publicProfile)
                }
            } else {
                Button {
                    Task { await startDirectMessage(with: profile) }
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 14))
                        Text("Send Task Request")
                            .font(.captionSM)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.agentRed)
                    .clipShape(Capsule())
                }
            }

            // Phone button
            Button {} label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.agentNavy)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.vertical, Spacing.cardPadding)
        .background(
            Color.agentSurface
                .shadow(color: Shadows.card, radius: 8, y: -2)
        )
    }

    // MARK: - Data

    private func loadProfile() async {
        do {
            profile = try await appState.taskService.fetchPublicProfileFull(userId: userId)
            do {
                reviews = try await fetchReviews(for: userId)
            } catch {
                print("[PublicProfile] Failed to load reviews: \(error)")
            }
        } catch {
            print("[PublicProfile] Failed to load profile: \(error)")
        }
        isLoading = false
    }

    private func fetchReviews(for userId: UUID) async throws -> [Review] {
        try await supabase
            .from("reviews")
            .select()
            .eq("reviewee_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value
    }

    private func startDirectMessage(with profile: PublicProfileFull) async {
        guard let currentUserId = appState.authService.currentUser?.id else { return }
        do {
            let conversation = try await appState.messageService.findOrCreateConversation(
                userId1: currentUserId, userId2: profile.id
            )
            appState.dashboardPath.append(
                DashboardDestination.directMessaging(
                    conversationId: conversation.id,
                    otherUserName: profile.fullName
                )
            )
        } catch {
            print("[PublicProfile] Failed to create conversation: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PublicProfileReadOnlyView(userId: UUID())
    }
    .environment(AppState.preview)
}
