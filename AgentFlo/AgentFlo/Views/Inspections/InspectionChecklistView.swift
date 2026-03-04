import SwiftUI

struct InspectionChecklistView: View {
    let taskId: UUID

    @Environment(AppState.self) private var appState
    @State private var findings: [InspectionFinding] = []
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var isSavingToCloud = false
    @State private var selectedSystem: ASHISystem?
    @State private var selectedSubItem: String?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var hasUnsyncedChanges = false

    private var summary: InspectionSummary {
        appState.inspectionService.checkCompleteness(findings: findings)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                if hasUnsyncedChanges {
                    unsyncedBanner
                }
                progressCard
                saveDraftButton
                systemList
                submitButton
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("Inspection Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadFindings() }
        .toast(errorMessage ?? "", style: .error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ))
        .toast(successMessage ?? "", style: .success, isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        ))
        .sheet(item: $selectedSystem) { system in
            systemDetailSheet(system)
        }
    }

    // MARK: - Unsynced Banner

    private var unsyncedBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "icloud.and.arrow.up")
                .foregroundStyle(.agentAmber)
            Text("Unsaved changes — tap Save Draft to sync to cloud")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.agentAmberLight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    // MARK: - Progress

    private var progressCard: some View {
        VStack(spacing: Spacing.md) {
            ProgressView(value: Double(summary.completedSystems.count), total: Double(ASHISystem.allCases.count))
                .tint(.agentGreen)

            HStack {
                Text("\(summary.completedSystems.count)/\(ASHISystem.allCases.count) systems")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)
                Spacer()
                Text("\(summary.totalPhotos) photos")
                    .font(.bodySM)
                    .foregroundStyle(summary.meetsMinimumPhotos ? .agentGreen : .agentSlate)
            }

            if summary.deficiencyCount > 0 {
                HStack(spacing: Spacing.md) {
                    if summary.criticalCount > 0 {
                        severityChip("\(summary.criticalCount) Critical", color: .red)
                    }
                    if summary.majorCount > 0 {
                        severityChip("\(summary.majorCount) Major", color: .orange)
                    }
                    if summary.minorCount > 0 {
                        severityChip("\(summary.minorCount) Minor", color: .yellow)
                    }
                    Spacer()
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func severityChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Save Draft

    @ViewBuilder
    private var saveDraftButton: some View {
        if !findings.isEmpty {
            PillButton("Save Draft to Cloud", variant: .secondary, isLoading: isSavingToCloud) {
                Task { await saveDraftToCloud() }
            }
        }
    }

    // MARK: - System List

    private var systemList: some View {
        VStack(spacing: Spacing.md) {
            ForEach(ASHISystem.allCases, id: \.self) { system in
                InspectionSystemCard(
                    system: system,
                    findings: findings.filter { $0.systemCategory == system }
                ) {
                    selectedSystem = system
                }
            }
        }
    }

    // MARK: - System Detail Sheet

    @ViewBuilder
    private func systemDetailSheet(_ system: ASHISystem) -> some View {
        NavigationStack {
            List {
                ForEach(system.subItems, id: \.self) { subItem in
                    let finding = findings.first { $0.systemCategory == system && $0.subItem == subItem }
                    Button {
                        selectedSubItem = subItem
                    } label: {
                        HStack {
                            Text(subItem)
                                .foregroundStyle(.agentNavy)
                            Spacer()
                            if let finding {
                                statusIcon(finding.status)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.agentSlateLight)
                            }
                        }
                    }
                }
            }
            .navigationTitle(system.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { selectedSystem = nil }
                }
            }
            .sheet(item: Binding(
                get: { selectedSubItem.map { SubItemWrapper(value: $0) } },
                set: { selectedSubItem = $0?.value }
            )) { wrapper in
                if let runnerId = appState.authService.currentUser?.id {
                    InspectionFindingForm(
                        system: system,
                        subItem: wrapper.value,
                        taskId: taskId,
                        runnerId: runnerId,
                        existingFinding: findings.first { $0.systemCategory == system && $0.subItem == wrapper.value }
                    ) { finding in
                        updateFindingLocally(finding)
                    }
                    .environment(appState)
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: FindingStatus) -> some View {
        switch status {
        case .good:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .deficiency:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .notInspected:
            Image(systemName: "eye.slash").foregroundStyle(.gray)
        case .na:
            Image(systemName: "minus.circle").foregroundStyle(.gray)
        }
    }

    // MARK: - Submit

    @ViewBuilder
    private var submitButton: some View {
        if summary.isComplete {
            VStack(spacing: Spacing.sm) {
                PillButton("Submit Inspection", variant: .primary, isLoading: isSubmitting) {
                    Task { await submitInspection() }
                }
                if !summary.meetsMinimumPhotos {
                    Text("Note: \(summary.totalPhotos)/25 photos attached")
                        .font(.caption)
                        .foregroundStyle(.agentAmber)
                }
            }
        } else {
            VStack(spacing: Spacing.sm) {
                PillButton("Submit Inspection", variant: .primary) {}
                    .disabled(true)
                    .opacity(0.5)
                Text("Complete all \(ASHISystem.allCases.count) systems to submit (\(summary.completedSystems.count) done)")
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
            }
        }
    }

    // MARK: - Data

    private func loadFindings() {
        // Local-first: load from UserDefaults, fall back to cloud
        let localFindings = appState.inspectionService.loadLocalDraft(taskId: taskId)
        if !localFindings.isEmpty {
            findings = localFindings
            hasUnsyncedChanges = true
            isLoading = false
        } else {
            Task {
                do {
                    findings = try await appState.inspectionService.fetchFindings(taskId: taskId)
                    if !findings.isEmpty {
                        // Cache cloud findings locally
                        appState.inspectionService.saveLocalDraft(taskId: taskId, findings: findings)
                        hasUnsyncedChanges = false
                    }
                } catch {
                    print("[Inspection] Failed to load from cloud: \(error)")
                }
                isLoading = false
            }
        }
    }

    private func updateFindingLocally(_ finding: InspectionFinding) {
        if let idx = findings.firstIndex(where: { $0.id == finding.id }) {
            findings[idx] = finding
        } else {
            findings.append(finding)
        }
        // Auto-save to UserDefaults
        appState.inspectionService.saveLocalDraft(taskId: taskId, findings: findings)
        hasUnsyncedChanges = true
    }

    private func saveDraftToCloud() async {
        isSavingToCloud = true
        do {
            try await appState.inspectionService.saveDraftToCloud(taskId: taskId, findings: findings)
            hasUnsyncedChanges = false
            successMessage = "Draft saved to cloud"
        } catch {
            errorMessage = "Failed to save draft: \(error.localizedDescription)"
        }
        isSavingToCloud = false
    }

    private func submitInspection() async {
        isSubmitting = true
        do {
            // Sync to cloud first, then submit
            try await appState.inspectionService.saveDraftToCloud(taskId: taskId, findings: findings)
            try await appState.inspectionService.submitInspection(taskId: taskId)
            appState.inspectionService.clearLocalDraft(taskId: taskId)
        } catch {
            errorMessage = "Submission failed: \(error.localizedDescription)"
        }
        isSubmitting = false
    }
}

// Helper for sheet binding
private struct SubItemWrapper: Identifiable {
    let value: String
    var id: String { value }
}

extension ASHISystem: Identifiable {
    public var id: String { rawValue }
}
