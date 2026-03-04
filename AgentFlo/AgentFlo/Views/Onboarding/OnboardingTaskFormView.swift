import SwiftUI
import MapKit

struct OnboardingTaskFormView: View {
    let category: String

    @Environment(AppState.self) private var appState

    @State private var address = ""
    @State private var scheduledDate = Date()
    @State private var priceText = ""
    @State private var instructions = ""
    @State private var isLoading = false
    @State private var isSavingDraft = false
    @State private var errorMessage: String?
    @State private var addressCompleter = AddressCompleter()
    @State private var showSuggestions = false
    @State private var addressIsLocked = false

    private var isFormValid: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
        && !priceText.isEmpty
        && (Int(priceText) ?? 0) > 0
    }

    private var priceInCents: Int {
        (Int(priceText) ?? 0) * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    // Address with autocomplete
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Property Address")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlate)

                        HStack {
                            TextField("123 Main St, Austin TX 78701", text: $address)
                                .font(.bodySM)
                                .textContentType(.fullStreetAddress)
                                .textInputAutocapitalization(.words)
                                .disabled(addressIsLocked)
                                .foregroundStyle(addressIsLocked ? .agentSlate : .agentNavy)
                                .onChange(of: address) { _, newValue in
                                    guard !addressIsLocked else { return }
                                    addressCompleter.search(query: newValue)
                                    showSuggestions = !newValue.isEmpty
                                }

                            if !address.isEmpty {
                                Button {
                                    address = ""
                                    addressIsLocked = false
                                    addressCompleter.suggestions = []
                                    showSuggestions = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.agentSlateLight)
                                }
                            }
                        }
                        .padding(Spacing.lg)
                        .background(.agentSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.input)
                                .stroke(Color.agentBorder, lineWidth: 1.5)
                        )

                        if showSuggestions && !addressCompleter.suggestions.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(addressCompleter.suggestions, id: \.self) { suggestion in
                                    Button {
                                        addressIsLocked = true
                                        showSuggestions = false
                                        addressCompleter.suggestions = []
                                        address = suggestion
                                    } label: {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundStyle(.agentRed)
                                                .font(.system(size: 16))
                                            Text(suggestion)
                                                .font(.bodySM)
                                                .foregroundStyle(.agentNavy)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, Spacing.lg)
                                        .padding(.vertical, Spacing.base)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                            .background(.agentSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.input))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.input)
                                    .stroke(Color.agentBorder, lineWidth: 1)
                            )
                            .shadow(color: Shadows.card, radius: 4, y: 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Date & Time")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlate)
                        DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    InputField(label: "Your Price ($)", text: $priceText, placeholder: "150", keyboardType: .numberPad)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Special Instructions")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlate)
                        TextEditor(text: $instructions)
                            .font(.bodySM)
                            .frame(minHeight: 80)
                            .padding(Spacing.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.input)
                                    .stroke(Color.agentBorder, lineWidth: 1.5)
                            )
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.captionSM)
                            .foregroundStyle(.agentError)
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.xxl)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)

            // Bottom actions
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.lg) {
                    PillButton("Save Draft", variant: .secondary, isLoading: isSavingDraft, isDisabled: !isFormValid) {
                        Task { await saveDraft() }
                    }
                    PillButton("Post Task", isLoading: isLoading, isDisabled: !isFormValid) {
                        Task { await postTask() }
                    }
                }

                Button("Skip for now \u{2192}") {
                    appState.selectedTab = .dashboard
                    appState.needsOnboarding = false
                }
                .font(.bodySM)
                .foregroundStyle(.agentSlate)
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.vertical, Spacing.xxl)
            .background(.agentSurface)
        }
        .background(.agentBackground)
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveDraft() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        isSavingDraft = true
        errorMessage = nil
        do {
            let draft = try await appState.taskService.createDraft(
                agentId: userId,
                category: category,
                address: address,
                price: priceInCents,
                instructions: instructions.isEmpty ? nil : instructions,
                scheduledAt: scheduledDate
            )
            appState.draftTaskFromOnboarding = draft.id
            appState.selectedTab = .dashboard
            appState.needsOnboarding = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSavingDraft = false
    }

    private func postTask() async {
        guard let userId = appState.authService.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let draft = try await appState.taskService.createDraft(
                agentId: userId,
                category: category,
                address: address,
                price: priceInCents,
                instructions: instructions.isEmpty ? nil : instructions,
                scheduledAt: scheduledDate
            )
            _ = try await appState.taskService.postTask(taskId: draft.id)
            appState.selectedTab = .dashboard
            appState.needsOnboarding = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        OnboardingTaskFormView(category: "Photography")
    }
    .environment(AppState.preview)
}
