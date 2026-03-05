import SwiftUI
import PhotosUI

struct PhotoUploadView: View {
    let task: AgentTask
    let onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                // Photo grid
                if selectedImages.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }

                Spacer()

                // Upload button
                if !selectedImages.isEmpty {
                    if isUploading {
                        VStack(spacing: Spacing.md) {
                            ProgressView(value: uploadProgress)
                                .tint(.agentRed)
                            Text("Uploading \(Int(uploadProgress * 100))%")
                                .font(.captionSM)
                                .foregroundStyle(.agentSlate)
                        }
                        .padding(.horizontal, Spacing.screenPadding)
                    } else {
                        PillButton("Submit \(selectedImages.count) Photo\(selectedImages.count == 1 ? "" : "s")", variant: .primary) {
                            Task { await uploadPhotos() }
                        }
                        .padding(.horizontal, Spacing.screenPadding)
                    }
                }
            }
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.xxxxl)
            .background(.agentBackground)
            .navigationTitle("Upload Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 30, matching: .images) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onChange(of: selectedItems) { _, items in
                Task { await loadImages(from: items) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    if let image {
                        selectedImages.append(image)
                    }
                }
            }
            .toast(errorMessage ?? "", style: .error, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ))
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.agentSlateLight)

            Text("Add photos of the property")
                .font(.bodySM)
                .foregroundStyle(.agentSlate)

            HStack(spacing: Spacing.lg) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 30, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentRed)
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.vertical, Spacing.lg)
                        .background(Color.agentRedLight)
                        .clipShape(Capsule())
                }

                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentRed)
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.vertical, Spacing.lg)
                        .background(Color.agentRedLight)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
            ], spacing: 4) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(minHeight: 120)
                            .clipped()

                        Button {
                            selectedImages.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .padding(4)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        selectedImages = images
    }

    private func uploadPhotos() async {
        isUploading = true
        uploadProgress = 0
        let total = Double(selectedImages.count)

        do {
            var deliverableEntries: [[String: String]] = []

            for (index, image) in selectedImages.enumerated() {
                let path = try await appState.storageService.uploadPhoto(
                    taskId: task.id, image: image, index: index
                )
                deliverableEntries.append([
                    "type": "photo",
                    "file_url": path,
                    "title": "Photo \(index + 1)",
                    "sort_order": String(index + 1),
                ])
                uploadProgress = Double(index + 1) / total
            }

            try await appState.taskService.submitDeliverables(
                taskId: task.id, deliverables: deliverableEntries
            )

            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            isUploading = false
        }
    }
}
