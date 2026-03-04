import SwiftUI

struct ShowingReportForm: View {
    let task: AgentTask
    var onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var buyerName = ""
    @State private var selectedInterest: BuyerInterest = .somewhatInterested
    @State private var questions: [String] = [""]
    @State private var propertyFeedback = ""
    @State private var followUpNotes = ""
    @State private var nextSteps = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    buyerNameSection
                    interestSection
                    questionsSection
                    feedbackSection
                    followUpSection
                    nextStepsSection
                    submitButton
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(.agentBackground)
            .navigationTitle("Showing Report")
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

    // MARK: - Buyer Name

    private var buyerNameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Buyer Name")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            TextField("Enter buyer's name", text: $buyerName)
                .font(.bodySM)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .background(.agentSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input)
                        .stroke(Color.agentBorder, lineWidth: 1.5)
                )
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Interest Level

    private var interestSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Interest Level")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            FlowLayout(spacing: 8) {
                ForEach(BuyerInterest.allCases, id: \.self) { level in
                    Button {
                        selectedInterest = level
                    } label: {
                        Text(level.displayName)
                            .font(.captionSM)
                            .foregroundStyle(selectedInterest == level ? .white : .agentNavy)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(selectedInterest == level ? Color.agentRed : Color.agentSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedInterest == level ? Color.clear : Color.agentBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Questions from Buyer")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            ForEach(questions.indices, id: \.self) { index in
                HStack {
                    TextField("Question \(index + 1)", text: $questions[index])
                        .font(.bodySM)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.lg)
                        .background(.agentSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.input)
                                .stroke(Color.agentBorder, lineWidth: 1.5)
                        )

                    if questions.count > 1 {
                        Button {
                            questions.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.agentSlate)
                        }
                    }
                }
            }

            Button {
                questions.append("")
            } label: {
                Label("Add Question", systemImage: "plus.circle")
                    .font(.bodySM)
                    .foregroundStyle(.agentRed)
            }
        }
    }

    // MARK: - Property Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Property Feedback")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            TextEditor(text: $propertyFeedback)
                .font(.bodySM)
                .frame(minHeight: 80)
                .padding(Spacing.md)
                .background(.agentSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input)
                        .stroke(Color.agentBorder, lineWidth: 1.5)
                )
        }
    }

    // MARK: - Follow-Up Notes

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Follow-Up Notes")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            TextEditor(text: $followUpNotes)
                .font(.bodySM)
                .frame(minHeight: 60)
                .padding(Spacing.md)
                .background(.agentSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input)
                        .stroke(Color.agentBorder, lineWidth: 1.5)
                )
        }
    }

    // MARK: - Next Steps

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Next Steps")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            TextEditor(text: $nextSteps)
                .font(.bodySM)
                .frame(minHeight: 60)
                .padding(Spacing.md)
                .background(.agentSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input)
                        .stroke(Color.agentBorder, lineWidth: 1.5)
                )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        PillButton("Submit Report", isLoading: isSubmitting) {
            Task { await submit() }
        }
        .disabled(buyerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submit() async {
        guard let runnerId = appState.authService.currentUser?.id else { return }
        let trimmedName = buyerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Buyer name is required."
            return
        }

        isSubmitting = true
        do {
            let filteredQuestions = questions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { ["question": $0] }

            try await appState.taskService.submitShowingReport(
                taskId: task.id,
                runnerId: runnerId,
                buyerName: trimmedName,
                buyerInterest: selectedInterest,
                questions: filteredQuestions.isEmpty ? nil : filteredQuestions,
                propertyFeedback: propertyFeedback.isEmpty ? nil : propertyFeedback,
                followUpNotes: followUpNotes.isEmpty ? nil : followUpNotes,
                nextSteps: nextSteps.isEmpty ? nil : nextSteps
            )
            dismiss()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
