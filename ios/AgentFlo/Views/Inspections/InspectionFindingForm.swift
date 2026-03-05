import SwiftUI
import PhotosUI

struct InspectionFindingForm: View {
    let system: ASHISystem
    let subItem: String
    let taskId: UUID
    let runnerId: UUID
    var existingFinding: InspectionFinding?
    let onSave: (InspectionFinding) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var status: FindingStatus = .good
    @State private var severity: FindingSeverity = .minor
    @State private var descriptionText = ""
    @State private var recommendation = ""
    @State private var notInspectedReason = ""
    @State private var photoUrls: [String] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                if status == .deficiency {
                    severitySection
                    descriptionSection
                    recommendationSection
                }
                if status == .notInspected {
                    reasonSection
                }
                photosSection
            }
            .navigationTitle(subItem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("Status") {
            Picker("Status", selection: $status) {
                ForEach(FindingStatus.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var severitySection: some View {
        Section("Severity") {
            Picker("Severity", selection: $severity) {
                ForEach(FindingSeverity.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var descriptionSection: some View {
        Section("Description") {
            TextEditor(text: $descriptionText)
                .frame(minHeight: 80)
        }
    }

    private var recommendationSection: some View {
        Section("Recommendation") {
            TextEditor(text: $recommendation)
                .frame(minHeight: 60)
        }
    }

    private var reasonSection: some View {
        Section("Reason Not Inspected") {
            TextField("Reason", text: $notInspectedReason)
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                Label("Add Photos", systemImage: "camera")
            }
            if !photoUrls.isEmpty {
                Text("\(photoUrls.count) photo(s) attached")
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
            }
        }
    }

    // MARK: - Actions

    private func loadExisting() {
        guard let finding = existingFinding else { return }
        status = finding.status
        severity = finding.severity ?? .minor
        descriptionText = finding.description ?? ""
        recommendation = finding.recommendation ?? ""
        notInspectedReason = finding.notInspectedReason ?? ""
        photoUrls = finding.photoUrls
    }

    private func save() {
        isSaving = true
        let finding = InspectionFinding(
            id: existingFinding?.id ?? UUID(),
            taskId: taskId,
            runnerId: runnerId,
            systemCategory: system,
            subItem: subItem,
            status: status,
            severity: status == .deficiency ? severity : (status == .good ? .good : nil),
            description: descriptionText.isEmpty ? nil : descriptionText,
            recommendation: recommendation.isEmpty ? nil : recommendation,
            notInspectedReason: notInspectedReason.isEmpty ? nil : notInspectedReason,
            photoUrls: photoUrls,
            sortOrder: existingFinding?.sortOrder ?? 0
        )
        onSave(finding)
        dismiss()
    }
}
