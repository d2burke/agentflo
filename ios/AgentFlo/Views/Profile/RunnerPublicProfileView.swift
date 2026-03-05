import SwiftUI
import PhotosUI

struct RunnerPublicProfileView: View {
    @Environment(AppState.self) private var appState

    @State private var isEnabled = false
    @State private var headline = ""
    @State private var selectedSpecialties: Set<TaskCategory> = []
    @State private var profileSlug = ""
    @State private var portfolioImages: [PortfolioImage] = []
    @State private var loadedImages: [UUID: Image] = [:]
    @State private var isSaving = false
    @State private var isLoadingPortfolio = true
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isUploadingPhotos = false
    @State private var showShareSheet = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var user: AppUser? { appState.authService.currentUser }
    private let maxPortfolioImages = 12
    private static let slugRegex = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                completenessCard
                enableToggle
                headlineSection
                specialtiesSection
                slugSection
                portfolioSection
                actionButtons
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("Public Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toast(showSuccess ? "Profile saved!" : (errorMessage ?? ""), style: showSuccess ? .success : .error, isPresented: showSuccess ? $showSuccess : $showError)
        .sheet(isPresented: $showShareSheet) {
            if let slug = user?.profileSlug, !slug.isEmpty {
                ShareSheet(items: ["Check out my profile on Agent Flo: https://agentflo.app/runner/\(slug)"])
            }
        }
        .onAppear { loadFromUser() }
        .task { await loadPortfolio() }
    }

    // MARK: - Completeness

    private var completenessScore: Double {
        var score = 0.0
        let total = 5.0
        if !headline.isEmpty { score += 1 }
        if !selectedSpecialties.isEmpty { score += 1 }
        if !profileSlug.isEmpty { score += 1 }
        if !portfolioImages.isEmpty { score += 1 }
        if user?.avatarUrl != nil { score += 1 }
        return score / total
    }

    private var completenessCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Profile Completeness")
                    .font(.captionSM)
                    .foregroundStyle(.agentSlate)
                Spacer()
                Text("\(Int(completenessScore * 100))%")
                    .font(.bodyEmphasis)
                    .foregroundStyle(completenessScore >= 1.0 ? .agentGreen : .agentAmber)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.agentBorderLight)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(completenessScore >= 1.0 ? Color.agentGreen : Color.agentAmber)
                        .frame(width: geo.size.width * completenessScore, height: 8)
                }
            }
            .frame(height: 8)

            if completenessScore < 1.0 {
                Text(missingItems)
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private var missingItems: String {
        var missing: [String] = []
        if headline.isEmpty { missing.append("headline") }
        if selectedSpecialties.isEmpty { missing.append("specialties") }
        if profileSlug.isEmpty { missing.append("profile link") }
        if portfolioImages.isEmpty { missing.append("portfolio photos") }
        if user?.avatarUrl == nil { missing.append("profile photo") }
        return "Add: " + missing.joined(separator: ", ")
    }

    // MARK: - Enable Toggle

    private var enableToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Public Profile")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Text("Allow agents to view your profile")
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .tint(.agentRed)
                .labelsHidden()
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    // MARK: - Headline

    private var headlineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Headline")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)
            TextField("e.g. Professional real estate photographer", text: $headline)
                .font(.bodySM)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .background(.agentSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input)
                        .stroke(Color.agentBorder, lineWidth: 1.5)
                )
            HStack {
                Spacer()
                Text("\(headline.count)/120")
                    .font(.caption)
                    .foregroundStyle(headline.count > 120 ? .agentError : .agentSlateLight)
            }
        }
    }

    // MARK: - Specialties

    private var specialtiesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Specialties")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            FlowLayout(spacing: 8) {
                ForEach(TaskCategory.allCases, id: \.self) { category in
                    Button {
                        if selectedSpecialties.contains(category) {
                            selectedSpecialties.remove(category)
                        } else {
                            selectedSpecialties.insert(category)
                        }
                    } label: {
                        Text(category.displayName)
                            .font(.captionSM)
                            .foregroundStyle(selectedSpecialties.contains(category) ? .white : .agentNavy)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedSpecialties.contains(category) ? Color.agentRed : Color.agentSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedSpecialties.contains(category) ? Color.clear : Color.agentBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Profile Slug

    private var slugSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Profile Link")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            HStack(spacing: 0) {
                Text("agentflo.app/runner/")
                    .font(.captionSM)
                    .foregroundStyle(.agentSlateLight)
                TextField("your-name", text: $profileSlug)
                    .font(.bodySM)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: profileSlug) { _, newValue in
                        profileSlug = newValue.lowercased().replacingOccurrences(of: " ", with: "-")
                    }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .background(.agentSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.input)
                    .stroke(slugIsValid ? Color.agentBorder : Color.agentError, lineWidth: 1.5)
            )

            if !profileSlug.isEmpty && !slugIsValid {
                Text("3-40 characters, lowercase letters, numbers, and hyphens only")
                    .font(.caption)
                    .foregroundStyle(.agentError)
            }
        }
    }

    private var slugIsValid: Bool {
        profileSlug.isEmpty || profileSlug.wholeMatch(of: Self.slugRegex) != nil
    }

    // MARK: - Portfolio

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Portfolio")
                    .font(.captionSM)
                    .foregroundStyle(.agentSlate)
                Spacer()
                Text("\(portfolioImages.count)/\(maxPortfolioImages)")
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
            ], spacing: 4) {
                ForEach(portfolioImages) { item in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let image = loadedImages[item.id] {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle()
                                    .fill(Color.agentBackground)
                                    .overlay { ProgressView() }
                            }
                        }
                        .frame(minHeight: 110)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button {
                            Task { await deleteImage(item) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .padding(4)
                        }
                    }
                }

                if portfolioImages.count < maxPortfolioImages {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: maxPortfolioImages - portfolioImages.count,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.agentRed)
                            Text("Add Photos")
                                .font(.captionSM)
                                .foregroundStyle(.agentSlate)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 110)
                        .background(Color.agentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle(.agentBorder)
                        )
                    }
                    .onChange(of: selectedPhotoItems) { _, items in
                        guard !items.isEmpty else { return }
                        Task { await uploadPhotos(items) }
                        selectedPhotoItems = []
                    }
                }
            }

            if isUploadingPhotos {
                HStack(spacing: Spacing.md) {
                    ProgressView()
                    Text("Uploading photos...")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: Spacing.lg) {
            PillButton("Save Profile", isLoading: isSaving) {
                Task { await saveProfile() }
            }

            if isEnabled && !profileSlug.isEmpty && slugIsValid {
                PillButton("Share Profile", variant: .outlined) {
                    showShareSheet = true
                }
            }
        }
    }

    // MARK: - Data

    private func loadFromUser() {
        guard let user else { return }
        isEnabled = user.isPublicProfileEnabled ?? false
        headline = user.headline ?? ""
        profileSlug = user.profileSlug ?? ""
        if let specs = user.specialties {
            selectedSpecialties = Set(specs.compactMap { TaskCategory(rawValue: $0) })
        }
    }

    private func loadPortfolio() async {
        guard let userId = user?.id else { return }
        do {
            portfolioImages = try await appState.taskService.fetchPortfolioImages(runnerId: userId)
            for item in portfolioImages {
                await loadPortfolioThumbnail(item)
            }
        } catch {
            errorMessage = "Failed to load portfolio"
            showError = true
        }
        isLoadingPortfolio = false
    }

    private func loadPortfolioThumbnail(_ item: PortfolioImage) async {
        do {
            let url = try await supabase.storage
                .from("portfolio")
                .createSignedURL(path: item.imageUrl, expiresIn: 3600)
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                loadedImages[item.id] = Image(uiImage: uiImage)
            }
        } catch {
            print("[PublicProfile] Failed to load thumbnail \(item.imageUrl): \(error)")
        }
    }

    private func uploadPhotos(_ items: [PhotosPickerItem]) async {
        guard let userId = user?.id else { return }
        isUploadingPhotos = true
        defer { isUploadingPhotos = false }

        for (index, item) in items.enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { continue }

                guard data.count <= 10_485_760 else {
                    errorMessage = "Each photo must be under 10 MB."
                    showError = true
                    continue
                }

                let sortOrder = portfolioImages.count + index
                let path = try await appState.storageService.uploadPortfolioImage(
                    runnerId: userId, image: uiImage, index: sortOrder
                )
                let portfolioImage = try await appState.taskService.insertPortfolioImage(
                    runnerId: userId, imageUrl: path, caption: nil, sortOrder: sortOrder
                )
                portfolioImages.append(portfolioImage)
                loadedImages[portfolioImage.id] = Image(uiImage: uiImage)
            } catch {
                errorMessage = "Upload failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func deleteImage(_ item: PortfolioImage) async {
        do {
            try await appState.storageService.deletePortfolioImage(path: item.imageUrl)
            try await appState.taskService.deletePortfolioImage(id: item.id)
            portfolioImages.removeAll { $0.id == item.id }
            loadedImages.removeValue(forKey: item.id)
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func saveProfile() async {
        guard let userId = user?.id else { return }

        guard headline.count <= 120 else {
            errorMessage = "Headline must be 120 characters or fewer."
            showError = true
            return
        }

        if !profileSlug.isEmpty && !slugIsValid {
            errorMessage = "Invalid profile link format."
            showError = true
            return
        }

        isSaving = true
        showError = false
        showSuccess = false

        do {
            try await appState.taskService.updatePublicProfileSettings(
                userId: userId,
                headline: headline.isEmpty ? nil : headline,
                specialties: selectedSpecialties.map(\.rawValue),
                profileSlug: profileSlug.isEmpty ? nil : profileSlug,
                isEnabled: isEnabled
            )
            await appState.authService.fetchUserProfile(userId: userId, forceRefresh: true)
            showSuccess = true
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            showError = true
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        RunnerPublicProfileView()
    }
    .environment(AppState.previewRunner)
}
