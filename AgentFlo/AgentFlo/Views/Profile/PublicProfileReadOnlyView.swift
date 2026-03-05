import SwiftUI

struct PublicProfileReadOnlyView: View {
    let userId: UUID

    @Environment(AppState.self) private var appState
    @State private var profile: PublicProfileFull?
    @State private var reviews: [Review] = []
    @State private var isLoading = true
    @State private var selectedTab = 0

    private var isSelf: Bool {
        appState.authService.currentUser?.id == userId
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading profile...")
            } else if let profile {
                ScrollView {
                    VStack(spacing: Spacing.sectionGap) {
                        headerSection(profile)
                        if let specialties = profile.specialties, !specialties.isEmpty {
                            serviceTags(specialties)
                        }
                        statsRow(profile)
                        ctaButtons(profile)
                        tabContent(profile)
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            } else {
                ContentUnavailableView("Profile Not Found", systemImage: "person.slash")
            }
        }
        .background(.agentBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
    }

    // MARK: - Header

    private func headerSection(_ profile: PublicProfileFull) -> some View {
        VStack(spacing: Spacing.lg) {
            CachedAvatarView(avatarPath: profile.avatarUrl, name: profile.fullName, size: 76)

            VStack(spacing: 4) {
                HStack(spacing: Spacing.sm) {
                    Text(profile.fullName)
                        .font(.titleMD)
                        .foregroundStyle(.agentNavy)
                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.agentBlue)
                            .font(.system(size: 16))
                    }
                }

                if let brokerage = profile.brokerage, !brokerage.isEmpty {
                    Text(brokerage)
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                }

                if let headline = profile.headline, !headline.isEmpty {
                    Text(headline)
                        .font(.bodySM)
                        .foregroundStyle(.agentSlateLight)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
    }

    // MARK: - Service Tags

    private func serviceTags(_ specialties: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(specialties, id: \.self) { specialty in
                let displayName = TaskCategory(rawValue: specialty)?.displayName ?? specialty.capitalized
                Text(displayName)
                    .font(.captionSM)
                    .foregroundStyle(.agentNavy)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.agentSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.agentBorder, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Stats

    private func statsRow(_ profile: PublicProfileFull) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(profile.completedTasks)", label: "Tasks")
            Divider().frame(height: 32)
            statItem(
                value: profile.avgRating.map { String(format: "%.1f", $0) } ?? "—",
                label: "Rating"
            )
            Divider().frame(height: 32)
            statItem(value: "\(profile.reviewCount)", label: "Reviews")
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.titleMD)
                .foregroundStyle(.agentNavy)
            Text(label)
                .font(.caption)
                .foregroundStyle(.agentSlate)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - CTA Buttons

    @ViewBuilder
    private func ctaButtons(_ profile: PublicProfileFull) -> some View {
        if isSelf {
            PillButton("Edit Profile", variant: .secondary) {
                appState.selectedTab = .profile
                appState.profilePath.append(ProfileDestination.publicProfile)
            }
        } else {
            VStack(spacing: Spacing.md) {
                PillButton("Message", variant: .primary) {
                    Task { await startDirectMessage(with: profile) }
                }
            }
        }
    }

    // MARK: - Tabs

    private func tabContent(_ profile: PublicProfileFull) -> some View {
        VStack(spacing: Spacing.lg) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Reviews").tag(0)
                Text("About").tag(1)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                reviewsTab
            } else {
                aboutTab(profile)
            }
        }
    }

    private var reviewsTab: some View {
        let textReviews = reviews.filter { $0.comment != nil && !$0.comment!.isEmpty }
        return VStack(spacing: Spacing.lg) {
            if textReviews.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "star")
                        .font(.system(size: 32))
                        .foregroundStyle(.agentSlateLight)
                    Text("No reviews yet")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlateLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxxl)
            } else {
                ForEach(textReviews) { review in
                    reviewCard(review)
                }
            }
        }
    }

    private func reviewCard(_ review: Review) -> some View {
        let parsed = parseReviewComment(review.comment)

        return VStack(alignment: .leading, spacing: Spacing.md) {
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

            // Went well tags
            if !parsed.wentWell.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(parsed.wentWell, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .foregroundStyle(.agentGreen)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 4)
                            .background(Color.agentGreenLight)
                            .clipShape(Capsule())
                    }
                }
            }

            // Could improve tags
            if !parsed.couldImprove.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(parsed.couldImprove, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .foregroundStyle(.agentAmber)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 4)
                            .background(Color.agentAmberLight)
                            .clipShape(Capsule())
                    }
                }
            }

            // Other text
            if let other = parsed.other, !other.isEmpty {
                Text(other)
                    .font(.bodySM)
                    .foregroundStyle(.agentNavy)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private struct ParsedReview {
        var wentWell: [String] = []
        var couldImprove: [String] = []
        var other: String?
    }

    private func parseReviewComment(_ comment: String?) -> ParsedReview {
        guard let comment, !comment.isEmpty else { return ParsedReview() }

        // Try JSON parse first
        if let data = comment.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var parsed = ParsedReview()
            parsed.wentWell = (json["went_well"] as? [String]) ?? []
            parsed.couldImprove = (json["could_improve"] as? [String]) ?? []
            parsed.other = json["other"] as? String
            return parsed
        }

        // Fallback: plain text
        return ParsedReview(other: comment)
    }

    private func aboutTab(_ profile: PublicProfileFull) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            if let brokerage = profile.brokerage, !brokerage.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Brokerage")
                        .font(.captionSM)
                        .foregroundStyle(.agentSlate)
                    Text(brokerage)
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Member since")
                    .font(.captionSM)
                    .foregroundStyle(.agentSlate)
                Text("Agent Flo member")
                    .font(.bodySM)
                    .foregroundStyle(.agentNavy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data

    private func loadProfile() async {
        do {
            profile = try await appState.taskService.fetchPublicProfileFull(userId: userId)
            // Load reviews for this user
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
