import SwiftUI
import UniformTypeIdentifiers

struct DocumentUploadView: View {
    let task: AgentTask
    let onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFile: SelectedFile?
    @State private var showFilePicker = false
    @State private var isUploading = false
    @State private var errorMessage: String?

    struct SelectedFile: Identifiable {
        let id = UUID()
        let name: String
        let data: Data
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                if let file = selectedFile {
                    // Selected file preview
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.agentRed)

                        Text(file.name)
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)

                        Text(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))
                            .font(.captionSM)
                            .foregroundStyle(.agentSlate)

                        Button("Choose Different File") {
                            showFilePicker = true
                        }
                        .font(.bodySM)
                        .foregroundStyle(.agentRed)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.xxxxl)
                    .background(.agentSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    .shadow(color: Shadows.card, radius: 4, y: 2)
                    .padding(.horizontal, Spacing.screenPadding)
                } else {
                    // Empty state
                    VStack(spacing: Spacing.xxl) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.agentSlateLight)

                        Text("Upload an inspection report")
                            .font(.bodySM)
                            .foregroundStyle(.agentSlate)

                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Select PDF", systemImage: "doc.badge.plus")
                                .font(.bodyEmphasis)
                                .foregroundStyle(.agentRed)
                                .padding(.horizontal, Spacing.xxl)
                                .padding(.vertical, Spacing.lg)
                                .background(Color.agentRedLight)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                if selectedFile != nil {
                    PillButton("Submit Report", variant: .primary, isLoading: isUploading) {
                        Task { await uploadDocument() }
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                }
            }
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.xxxxl)
            .background(.agentBackground)
            .navigationTitle("Upload Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [UTType.pdf]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        selectedFile = SelectedFile(name: url.lastPathComponent, data: data)
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .toast(errorMessage ?? "", style: .error, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ))
        }
    }

    private func uploadDocument() async {
        guard let file = selectedFile else { return }
        isUploading = true

        do {
            let path = try await appState.storageService.uploadDocument(
                taskId: task.id, data: file.data, filename: file.name
            )

            try await appState.taskService.submitDeliverables(
                taskId: task.id,
                deliverables: [[
                    "type": "document",
                    "file_url": path,
                    "title": file.name,
                    "sort_order": "1",
                ]]
            )

            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            isUploading = false
        }
    }
}
