import SwiftUI
import PhotosUI

struct StagingPhotoView: View {
    let task: AgentTask
    var onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    static let predefinedRooms = [
        "Living Room", "Kitchen", "Master Bedroom", "Bathroom",
        "Dining Room", "Office", "Guest Bedroom", "Hallway", "Exterior"
    ]

    @State private var photos: [(room: String, photoType: String, image: UIImage)] = []
    @State private var selectedRoom = "Living Room"
    @State private var customRoom = ""
    @State private var captureType: String = "before"
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?

    private var currentRoom: String {
        selectedRoom == "Custom" ? customRoom : selectedRoom
    }

    private var rooms: [String] {
        Self.predefinedRooms + ["Custom"]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    roomPicker
                    typePicker
                    captureButtons
                    photoGrid
                    submitButton
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(.agentBackground)
            .navigationTitle("Staging Photos")
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
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    if let image {
                        photos.append((room: currentRoom, photoType: captureType, image: image))
                    }
                    showCamera = false
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        photos.append((room: currentRoom, photoType: captureType, image: uiImage))
                    }
                    selectedPhotoItem = nil
                }
            }
        }
    }

    // MARK: - Room Picker

    private var roomPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Room")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            Picker("Room", selection: $selectedRoom) {
                ForEach(rooms, id: \.self) { room in
                    Text(room).tag(room)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(.agentSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.input))

            if selectedRoom == "Custom" {
                TextField("Custom room name", text: $customRoom)
                    .font(.bodySM)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                    .background(.agentSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.input)
                            .stroke(Color.agentBorder, lineWidth: 1.5)
                    )
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Type Picker

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Photo Type")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            Picker("Type", selection: $captureType) {
                Text("Before").tag("before")
                Text("After").tag("after")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Capture Buttons

    private var captureButtons: some View {
        HStack(spacing: Spacing.lg) {
            PillButton("Take Photo", variant: .primary) {
                showCamera = true
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Choose Photo")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(.agentSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .stroke(Color.agentRed, lineWidth: 1.5)
                    )
            }
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if !photos.isEmpty {
                Text("Captured (\(photos.count))")
                    .font(.captionSM)
                    .foregroundStyle(.agentSlate)

                let grouped = Dictionary(grouping: photos.indices, by: { photos[$0].room })
                ForEach(grouped.keys.sorted(), id: \.self) { room in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(room)
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4),
                        ], spacing: 4) {
                            ForEach(grouped[room] ?? [], id: \.self) { index in
                                ZStack(alignment: .topLeading) {
                                    Image(uiImage: photos[index].image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minHeight: 100)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    Text(photos[index].photoType.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(photos[index].photoType == "before" ? Color.agentAmber : Color.agentGreen)
                                        .clipShape(Capsule())
                                        .padding(4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        PillButton("Upload & Submit", isLoading: isUploading) {
            Task { await uploadAndSubmit() }
        }
        .disabled(photos.isEmpty)
    }

    private func uploadAndSubmit() async {
        guard let runnerId = appState.authService.currentUser?.id else { return }
        isUploading = true
        defer { isUploading = false }

        var deliverables: [[String: String]] = []

        for (index, photo) in photos.enumerated() {
            do {
                let path = try await appState.storageService.uploadPhoto(
                    taskId: task.id, image: photo.image, index: index
                )
                deliverables.append([
                    "type": "photo",
                    "file_url": path,
                    "title": "\(photo.room) - \(photo.photoType.capitalized)",
                    "room": photo.room,
                    "photo_type": photo.photoType,
                    "sort_order": "\(index)",
                ])
            } catch {
                errorMessage = "Upload failed: \(error.localizedDescription)"
                return
            }
        }

        do {
            try await appState.taskService.submitDeliverables(taskId: task.id, deliverables: deliverables)
            dismiss()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
