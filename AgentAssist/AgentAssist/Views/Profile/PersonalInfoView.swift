import SwiftUI
import PhotosUI

struct PersonalInfoView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var brokerage = ""
    @State private var licenseNumber = ""
    @State private var licenseState = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var isUploadingPhoto = false
    @State private var brokerageCompleter = BrokerageCompleter()
    @State private var showBrokerageSuggestions = false
    @State private var brokerageIsLocked = false

    private var user: AppUser? { appState.authService.currentUser }
    private var isAgent: Bool { user?.role == .agent }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                // Avatar
                VStack(spacing: Spacing.lg) {
                    ZStack {
                        if let avatarImage {
                            avatarImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.agentRedLight)
                                .frame(width: 88, height: 88)
                                .overlay(
                                    Text(fullName.prefix(1).uppercased())
                                        .font(.display)
                                        .foregroundStyle(.agentRed)
                                )
                        }

                        if isUploadingPhoto {
                            Circle()
                                .fill(.black.opacity(0.4))
                                .frame(width: 88, height: 88)
                                .overlay(ProgressView().tint(.white))
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text("Change Photo")
                            .font(.bodySM)
                            .foregroundStyle(.agentRed)
                    }
                    .onChange(of: selectedPhotoItem) { _, newValue in
                        guard let newValue else { return }
                        Task { await uploadAvatar(from: newValue) }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.lg)

                // Fields
                VStack(spacing: Spacing.xxl) {
                    InputField(label: "Full Name", text: $fullName, placeholder: "Your full name", textContentType: .name, autocapitalization: .words)
                    InputField(label: "Email", text: $email, placeholder: "you@example.com", keyboardType: .emailAddress, textContentType: .emailAddress, autocapitalization: .never)
                    InputField(label: "Phone", text: $phone, placeholder: "(512) 555-1234", keyboardType: .phonePad, textContentType: .telephoneNumber)

                    if isAgent {
                        // Brokerage with autocomplete
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Brokerage")
                                .font(.captionSM)
                                .foregroundStyle(.agentSlate)

                            HStack {
                                TextField("Your brokerage name", text: $brokerage)
                                    .font(.bodySM)
                                    .textInputAutocapitalization(.words)
                                    .disabled(brokerageIsLocked)
                                    .foregroundStyle(brokerageIsLocked ? .agentSlate : .agentNavy)
                                    .onChange(of: brokerage) { _, newValue in
                                        guard !brokerageIsLocked else { return }
                                        brokerageCompleter.search(query: newValue)
                                        showBrokerageSuggestions = !newValue.isEmpty
                                    }

                                if !brokerage.isEmpty {
                                    Button {
                                        brokerage = ""
                                        brokerageIsLocked = false
                                        brokerageCompleter.suggestions = []
                                        showBrokerageSuggestions = false
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.agentSlateLight)
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.lg)
                            .background(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.input)
                                    .stroke(Color.agentBorder, lineWidth: 1.5)
                            )

                            if showBrokerageSuggestions && !brokerageCompleter.suggestions.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(brokerageCompleter.suggestions, id: \.self) { suggestion in
                                        Button {
                                            brokerageIsLocked = true
                                            showBrokerageSuggestions = false
                                            brokerageCompleter.suggestions = []
                                            brokerage = suggestion
                                        } label: {
                                            HStack(spacing: Spacing.md) {
                                                Image(systemName: "building.2.fill")
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

                        InputField(label: "License Number", text: $licenseNumber, placeholder: "e.g. 12345678")
                        InputField(label: "License State", text: $licenseState, placeholder: "TX", autocapitalization: .characters)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Bio")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlate)
                        TextEditor(text: $bio)
                            .font(.bodySM)
                            .frame(minHeight: 100)
                            .padding(Spacing.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.input)
                                    .stroke(Color.agentBorder, lineWidth: 1.5)
                            )
                        Text("\(bio.count)/500")
                            .font(.caption)
                            .foregroundStyle(.agentSlateLight)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)

                PillButton("Save Changes", isLoading: isSaving) {
                    Task { await saveProfile() }
                }
                .padding(.horizontal, Spacing.screenPadding)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("Personal Information")
        .navigationBarTitleDisplayMode(.inline)
        .toast(showSuccess ? "Profile updated!" : (errorMessage ?? ""), style: showSuccess ? .success : .error, isPresented: showSuccess ? $showSuccess : $showError)
        .onAppear { loadUserData() }
        .task { await loadAvatarImage() }
    }

    private func loadUserData() {
        guard let user else { return }
        fullName = user.fullName
        email = user.email
        phone = user.phone ?? ""
        brokerage = user.brokerage ?? ""
        brokerageIsLocked = !(user.brokerage ?? "").isEmpty
        licenseNumber = user.licenseNumber ?? ""
        licenseState = user.licenseState ?? ""
        bio = user.bio ?? ""
    }

    private func loadAvatarImage() async {
        guard let user, let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty else { return }
        do {
            let data = try await supabase.storage.from("avatars").download(path: avatarUrl)
            if let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
            }
        } catch {
            print("[PersonalInfo] Failed to load avatar: \(error)")
        }
    }

    private func uploadAvatar(from item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        guard let userId = user?.id else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }

            guard data.count <= 5_242_880 else {
                errorMessage = "Photo must be under 5 MB."
                showError = true
                return
            }

            guard let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
                errorMessage = "Couldn't process the selected image."
                showError = true
                return
            }

            let path = "\(userId.uuidString.lowercased())/avatar.jpg"

            try await supabase.storage.from("avatars")
                .upload(path, data: jpegData, options: .init(contentType: "image/jpeg", upsert: true))

            try await supabase.from("users")
                .update(["avatar_url": path])
                .eq("id", value: userId.uuidString)
                .execute()

            await appState.authService.fetchUserProfile(userId: userId)
            avatarImage = Image(uiImage: uiImage)
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func saveProfile() async {
        isSaving = true
        showError = false
        showSuccess = false
        do {
            var fields: [String: String] = [
                "full_name": fullName,
                "phone": phone,
                "bio": String(bio.prefix(500)),
            ]
            if isAgent {
                if !brokerage.isEmpty { fields["brokerage"] = brokerage }
                if !licenseNumber.isEmpty { fields["license_number"] = licenseNumber }
                let trimmedState = licenseState.trimmingCharacters(in: .whitespaces).uppercased()
                if trimmedState.count == 2 { fields["license_state"] = trimmedState }
            }

            try await supabase.from("users")
                .update(fields)
                .eq("id", value: user!.id.uuidString)
                .execute()

            await appState.authService.fetchUserProfile(userId: user!.id)
            showSuccess = true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showError = true
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        PersonalInfoView()
    }
    .environment(AppState.preview)
}
