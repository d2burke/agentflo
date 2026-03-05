import SwiftUI

struct ReviewSheet: View {
    let task: AgentTask
    let revieweeName: String
    var onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var wentWell: Set<String> = []
    @State private var couldImprove: Set<String> = []
    @State private var otherText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let positiveTags = [
        "On time", "Great communication", "Quality work",
        "Professional", "Above & beyond", "Followed instructions"
    ]

    private let improvementTags = [
        "Punctuality", "Communication", "Work quality",
        "Professionalism", "Following instructions"
    ]

    private var isHighRating: Bool { rating >= 4 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    headerSection
                    starRatingSection

                    if rating > 0 {
                        primaryTagsSection
                        improvementTagsSection
                        otherSection
                        submitButton
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(.agentBackground)
            .navigationTitle("Leave a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .toast(errorMessage ?? "", style: .error, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Text("How was \(revieweeName)?")
                .font(.titleMD)
                .foregroundStyle(.agentNavy)
                .frame(maxWidth: .infinity)

            Text(task.category)
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
        }
        .padding(.top, Spacing.xxl)
    }

    // MARK: - Star Rating

    private var starRatingSection: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        rating = star
                    }
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundStyle(star <= rating ? .agentAmber : .agentSlateLight)
                        .scaleEffect(star <= rating ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Primary Tags (went well / could do better)

    private var primaryTagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(isHighRating ? "What went well?" : "What could they have done better?")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            FlowLayout(spacing: 8) {
                ForEach(positiveTags, id: \.self) { tag in
                    tagChip(tag, isSelected: wentWell.contains(tag)) {
                        if wentWell.contains(tag) {
                            wentWell.remove(tag)
                        } else {
                            wentWell.insert(tag)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Improvement Tags

    private var improvementTagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("What could have been improved?")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            FlowLayout(spacing: 8) {
                ForEach(improvementTags, id: \.self) { tag in
                    tagChip(tag, isSelected: couldImprove.contains(tag)) {
                        if couldImprove.contains(tag) {
                            couldImprove.remove(tag)
                        } else {
                            couldImprove.insert(tag)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Other

    private var otherSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Anything else? (optional)")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            TextField("Share more details...", text: $otherText, axis: .vertical)
                .font(.bodySM)
                .lineLimit(3...6)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .background(.agentSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input)
                        .stroke(Color.agentBorder, lineWidth: 1.5)
                )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        PillButton("Submit Review", isLoading: isSubmitting) {
            Task { await submit() }
        }
        .disabled(rating == 0)
    }

    // MARK: - Tag Chip

    private func tagChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.captionSM)
                .foregroundStyle(isSelected ? .white : .agentSlate)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(isSelected ? Color.agentNavySolid : Color.agentSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.agentBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Submit Logic

    private func submit() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        let isAgent = appState.authService.currentUser?.role == .agent
        guard let revieweeId = isAgent ? task.runnerId : task.agentId as UUID? else { return }

        isSubmitting = true
        do {
            try await appState.taskService.submitReview(
                taskId: task.id,
                reviewerId: userId,
                revieweeId: revieweeId,
                rating: rating,
                comment: buildComment()
            )
            dismiss()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func buildComment() -> String? {
        var parts: [String: Any] = [:]

        if !wentWell.isEmpty {
            parts["went_well"] = Array(wentWell).sorted()
        }
        if !couldImprove.isEmpty {
            parts["could_improve"] = Array(couldImprove).sorted()
        }
        let trimmed = otherText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts["other"] = trimmed
        }

        guard !parts.isEmpty else { return nil }

        if let data = try? JSONSerialization.data(withJSONObject: parts),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        // Fallback: just return the other text if JSON fails
        return trimmed.isEmpty ? nil : trimmed
    }
}
