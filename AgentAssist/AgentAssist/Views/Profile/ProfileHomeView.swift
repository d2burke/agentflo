import SwiftUI
import PhotosUI

struct ProfileHomeView: View {
    @Environment(AppState.self) private var appState

    @State private var avatarImage: Image?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var user: AppUser? { appState.authService.currentUser }
    private var isAgent: Bool { user?.role == .agent }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                // User header
                userHeader

                // Menu items
                VStack(spacing: 0) {
                    ProfileMenuItem(icon: "person.fill", title: "Personal Information", destination: .personalInfo)

                    if isAgent {
                        ProfileMenuItem(icon: "creditcard.fill", title: "Payment Methods", destination: .paymentMethods)
                        ProfileMenuItem(icon: "clock.arrow.circlepath", title: "Task History", destination: .taskHistory)
                    } else {
                        ProfileMenuItem(icon: "banknote.fill", title: "Payout Settings", destination: .payoutSettings)
                        ProfileMenuItem(icon: "dollarsign.circle.fill", title: "Earnings & Payouts", destination: .earnings)
                        ProfileMenuItem(icon: "map.fill", title: "Service Areas", destination: .serviceAreas)
                        ProfileMenuItem(icon: "calendar", title: "Availability", destination: .availability)
                    }

                    ProfileMenuItem(icon: "bell.fill", title: "Notification Settings", destination: .notificationSettings)
                    ProfileMenuItem(icon: "lock.fill", title: "Account & Security", destination: .accountSecurity)
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                .shadow(color: Shadows.card, radius: 4, y: 2)

                // Sign out
                PillButton("Sign Out", variant: .outlined) {
                    Task {
                        try? await appState.authService.signOut()
                    }
                }

                Text("AgentAssist v1.0")
                    .font(.captionSM)
                    .foregroundStyle(.agentSlateLight)
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("Profile")
        .toast(errorMessage ?? "", style: .error, isPresented: $showError)
        .task { await loadAvatarImage() }
    }

    private var userHeader: some View {
        VStack(spacing: Spacing.lg) {
            // Avatar with photo picker
            ZStack {
                if let avatarImage {
                    avatarImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.agentRedLight)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text(user?.fullName.prefix(1).uppercased() ?? "?")
                                .font(.titleLG)
                                .foregroundStyle(.agentRed)
                        )
                }

                if isUploadingPhoto {
                    Circle()
                        .fill(.black.opacity(0.4))
                        .frame(width: 72, height: 72)
                        .overlay(ProgressView().tint(.white))
                }
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                    Text("Edit Photo")
                        .font(.captionSM)
                }
                .foregroundStyle(.agentRed)
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task { await uploadAvatar(from: newValue) }
            }

            VStack(spacing: Spacing.xs) {
                Text(user?.fullName ?? "")
                    .font(.titleMD)
                    .foregroundStyle(.agentNavy)
                Text(isAgent ? "Real Estate Agent" : "Task Runner")
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
                // Only show vetting badge when relevant (pending/approved)
                if let status = user?.vettingStatus, status == .approved || status == .pending {
                    StatusBadge(status: status == .approved ? .completed : .inProgress)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxxl)
    }

    // MARK: - Avatar

    private func loadAvatarImage() async {
        guard let user, let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty else { return }
        do {
            let data = try await supabase.storage.from("avatars").download(path: avatarUrl)
            if let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
            }
        } catch {
            print("[Profile] Failed to load avatar: \(error)")
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
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let destination: ProfileDestination

    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.profilePath.append(destination)
        } label: {
            HStack(spacing: Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.agentSlate)
                    .frame(width: 24)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.agentNavy)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.vertical, Spacing.xl)
        }
        .buttonStyle(.plain)

        Divider()
            .padding(.leading, Spacing.cardPadding + 40)
    }
}

#Preview("Agent") {
    NavigationStack {
        ProfileHomeView()
    }
    .environment(AppState.preview)
}

#Preview("Runner") {
    NavigationStack {
        ProfileHomeView()
    }
    .environment(AppState.previewRunner)
}
