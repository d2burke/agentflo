import SwiftUI
import MapKit

struct TaskCreationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing draft to edit; nil = create new task
    var editingTask: AgentTask?

    @State private var selectedCategory: String?
    @State private var address = ""
    @State private var scheduledDate = Date()
    @State private var priceText = ""
    @State private var instructions = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var path = NavigationPath()
    @State private var didPrefill = false

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: String.self) { category in
                    TaskDetailsForm(
                        category: category,
                        address: $address,
                        scheduledDate: $scheduledDate,
                        priceText: $priceText,
                        instructions: $instructions,
                        isLoading: $isLoading,
                        errorMessage: $errorMessage,
                        onSaveDraft: { await saveDraft() },
                        onPostTask: { await postTask() }
                    )
                }
                .navigationTitle(editingTask != nil ? (selectedCategory ?? "Edit Task") : "New Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.agentSlate)
                        }
                    }
                }
        }
        .onAppear {
            guard !didPrefill, let task = editingTask else { return }
            didPrefill = true
            selectedCategory = task.category
            address = task.propertyAddress
            if let date = task.scheduledAt { scheduledDate = date }
            let dollars = task.price / 100
            priceText = dollars > 0 ? "\(dollars)" : ""
            instructions = task.instructions ?? ""
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if editingTask != nil {
            // Skip category selection — go straight to form
            TaskDetailsForm(
                category: selectedCategory ?? editingTask!.category,
                address: $address,
                scheduledDate: $scheduledDate,
                priceText: $priceText,
                instructions: $instructions,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                onSaveDraft: { await saveDraft() },
                onPostTask: { await postTask() },
                isEditing: true
            )
        } else {
            categorySelection
        }
    }

    // MARK: - Category Selection

    private var categorySelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("What do you need help with?")
                    .font(.titleLG)
                    .foregroundStyle(.agentNavy)

                ForEach(categories, id: \.name) { cat in
                    Button {
                        selectedCategory = cat.name
                        path.append(cat.name)
                    } label: {
                        HStack(spacing: Spacing.xxl) {
                            CategoryIcon(category: cat.name)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.name)
                                    .font(.bodyEmphasis)
                                    .foregroundStyle(.agentNavy)
                                Text(cat.description)
                                    .font(.caption)
                                    .foregroundStyle(.agentSlate)
                            }
                            Spacer()
                            Text(cat.priceRange)
                                .font(.captionSM)
                                .foregroundStyle(.agentSlateLight)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.agentSlateLight)
                        }
                        .padding(Spacing.cardPadding)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                        .shadow(color: Shadows.card, radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
        && !priceText.isEmpty
        && (Int(priceText) ?? 0) > 0
    }

    private var priceInCents: Int {
        (Int(priceText) ?? 0) * 100
    }

    private func saveDraft() async {
        guard let userId = appState.authService.currentUser?.id,
              let category = selectedCategory else { return }
        do {
            if let existing = editingTask {
                try await appState.taskService.updateDraft(
                    taskId: existing.id,
                    category: category,
                    address: address,
                    price: priceInCents,
                    instructions: instructions.isEmpty ? nil : instructions,
                    scheduledAt: scheduledDate
                )
            } else {
                _ = try await appState.taskService.createDraft(
                    agentId: userId,
                    category: category,
                    address: address,
                    price: priceInCents,
                    instructions: instructions.isEmpty ? nil : instructions,
                    scheduledAt: scheduledDate
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func postTask() async {
        guard let userId = appState.authService.currentUser?.id,
              let category = selectedCategory else { return }
        isLoading = true
        errorMessage = nil
        do {
            if let existing = editingTask {
                // Update the draft fields, then post it
                try await appState.taskService.updateDraft(
                    taskId: existing.id,
                    category: category,
                    address: address,
                    price: priceInCents,
                    instructions: instructions.isEmpty ? nil : instructions,
                    scheduledAt: scheduledDate
                )
                _ = try await appState.taskService.postTask(taskId: existing.id)
                appState.draftTaskFromOnboarding = nil
            } else {
                let draft = try await appState.taskService.createDraft(
                    agentId: userId,
                    category: category,
                    address: address,
                    price: priceInCents,
                    instructions: instructions.isEmpty ? nil : instructions,
                    scheduledAt: scheduledDate
                )
                _ = try await appState.taskService.postTask(taskId: draft.id)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private var categories: [(name: String, description: String, priceRange: String)] {
        [
            ("Photography", "Professional listing photos", "$100–$300"),
            ("Showing", "Buyer or inspector showing", "$50–$100"),
            ("Staging", "Furniture staging & setup", "$200–$400"),
            ("Open House", "Host an open house event", "$75–$150"),
        ]
    }
}

// MARK: - Task Details Form (pushed onto stack)

struct TaskDetailsForm: View {
    let category: String
    @Binding var address: String
    @Binding var scheduledDate: Date
    @Binding var priceText: String
    @Binding var instructions: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onSaveDraft: () async -> Void
    let onPostTask: () async -> Void
    var isEditing: Bool = false

    @State private var addressCompleter = AddressCompleter()
    @State private var showSuggestions = false
    @State private var addressIsLocked = false

    private var isFormValid: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
        && !priceText.isEmpty
        && (Int(priceText) ?? 0) > 0
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
                        .background(.white)
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
                            .background(.white)
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
            HStack(spacing: Spacing.lg) {
                PillButton("Save Draft", variant: .secondary) {
                    Task { await onSaveDraft() }
                }
                PillButton("Post Task", isLoading: isLoading, isDisabled: !isFormValid) {
                    Task { await onPostTask() }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.vertical, Spacing.xxl)
            .background(.white)
        }
        .background(.agentBackground)
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isEditing && !address.isEmpty {
                addressIsLocked = true
            }
        }
    }
}

// MARK: - Address Autocomplete using MapKit

@Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var suggestions: [String] = []
    private let completer = MKLocalSearchCompleter()
    private var debounceTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(query: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                completer.queryFragment = query
            }
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.prefix(5).map { result in
            if result.subtitle.isEmpty {
                return result.title
            }
            return "\(result.title), \(result.subtitle)"
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently fail — user can still type manually
    }
}

#Preview("New Task") {
    TaskCreationSheet()
        .environment(AppState.preview)
}
