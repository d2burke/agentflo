import SwiftUI
import PhotosUI

struct VerificationView: View {
    @Environment(AppState.self) private var appState
    @State private var vettingService = VettingService()
    @State private var showToast = false
    @State private var toastMessage = ""

    private var user: AppUser? { appState.authService.currentUser }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                // Status banner
                statusBanner

                if vettingService.isLoading {
                    ProgressView("Loading verification status...")
                        .padding(.top, Spacing.xxxxl)
                } else {
                    // Steps
                    LicenseStepView(vettingService: vettingService)
                    PhotoIdStepView(vettingService: vettingService)
                    BrokerageStepView(vettingService: vettingService)
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .toast(toastMessage, style: .success, isPresented: $showToast)
        .task {
            await vettingService.fetchMyRecords()
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        let status = user?.vettingStatus ?? .notStarted
        let approvedCount = vettingService.records.filter { $0.status == "approved" }.count

        if status == .approved {
            HStack(spacing: Spacing.lg) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Account Verified")
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)
                    Text("Your identity has been verified.")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }
                Spacer()
            }
            .padding(Spacing.cardPadding)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Verification Progress")
                        .font(.captionSM)
                        .foregroundStyle(.agentNavy)
                    Spacer()
                    Text("\(approvedCount)/3 approved")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.agentSlateLight.opacity(0.3))
                        Capsule()
                            .fill(Color.agentRed)
                            .frame(width: geo.size.width * (CGFloat(approvedCount) / 3.0))
                            .animation(.easeInOut, value: approvedCount)
                    }
                }
                .frame(height: 6)

                if status == .pending {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("Under review — you'll be notified once approved.")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(Spacing.cardPadding)
            .background(.agentSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .shadow(color: Shadows.card, radius: 4, y: 2)
        }
    }
}

// MARK: - License Step

private struct LicenseStepView: View {
    let vettingService: VettingService
    @Environment(AppState.self) private var appState

    @State private var licenseNumber = ""
    @State private var state = ""
    @State private var expiry = ""
    @State private var isSubmitting = false

    private var record: VettingRecord? { vettingService.record(ofType: "license") }
    private var isApproved: Bool { record?.status == "approved" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Real Estate License")
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)
                        Text("Enter your license details")
                            .font(.caption)
                            .foregroundStyle(.agentSlate)
                    }
                }
                Spacer()
                if let record {
                    statusTag(record.status)
                }
            }

            // Rejection feedback
            if let record, record.status == "rejected", let notes = record.reviewerNotes {
                rejectionBanner(notes)
            }

            // Form
            InputField(label: "License Number", text: $licenseNumber, placeholder: "e.g., TX-456123")
                .disabled(isApproved)

            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("State")
                        .font(.captionSM)
                        .foregroundStyle(.agentNavy)
                    Picker("State", selection: $state) {
                        Text("Select").tag("")
                        ForEach(US_STATES, id: \.self) { st in
                            Text(st).tag(st)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.agentNavy)
                    .disabled(isApproved)
                }

                InputField(label: "Expiration", text: $expiry, placeholder: "MM/YYYY")
                    .disabled(isApproved)
            }

            if !isApproved {
                let canSubmit = !licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty && !state.isEmpty
                PillButton(submitLabel, isLoading: isSubmitting, isDisabled: !canSubmit) {
                    Task { await submit() }
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
        .onAppear {
            if let data = record?.submittedData {
                licenseNumber = data["license_number"] ?? ""
                state = data["state"] ?? ""
                expiry = data["expiry"] ?? ""
            } else if let user = appState.authService.currentUser {
                licenseNumber = user.licenseNumber ?? ""
                state = user.licenseState ?? ""
            }
        }
    }

    private var submitLabel: String {
        if record?.status == "rejected" { return "Resubmit" }
        if record?.status == "pending" { return "Update" }
        return "Submit License"
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        var data: [String: String] = [
            "license_number": licenseNumber.trimmingCharacters(in: .whitespaces),
            "state": state,
        ]
        if !expiry.isEmpty { data["expiry"] = expiry }

        do {
            try await vettingService.submitRecord(type: "license", submittedData: data)
        } catch {
            print("[VerificationView] License submit failed: \(error)")
        }
    }
}

// MARK: - Photo ID Step

private struct PhotoIdStepView: View {
    let vettingService: VettingService
    @Environment(AppState.self) private var appState

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var uploadedUrl: String?
    @State private var isUploading = false
    @State private var isSubmitting = false

    private var record: VettingRecord? { vettingService.record(ofType: "photo_id") }
    private var isApproved: Bool { record?.status == "approved" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Photo ID")
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)
                        Text("Upload a government-issued ID")
                            .font(.caption)
                            .foregroundStyle(.agentSlate)
                    }
                }
                Spacer()
                if let record {
                    statusTag(record.status)
                }
            }

            if let record, record.status == "rejected", let notes = record.reviewerNotes {
                rejectionBanner(notes)
            }

            if isApproved {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Photo ID verified")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            } else {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    if let previewImage {
                        previewImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                            .frame(maxWidth: .infinity)
                    } else if uploadedUrl != nil || record?.submittedData?["file_url"] != nil {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.green)
                            Text("Document uploaded")
                                .font(.bodySM)
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xxxxl)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .strokeBorder(Color.agentSlateLight.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                    } else {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.agentSlate)
                            Text("Tap to upload photo ID")
                                .font(.bodySM)
                                .foregroundStyle(.agentSlate)
                            Text("JPEG or PNG, up to 10 MB")
                                .font(.caption)
                                .foregroundStyle(.agentSlateLight)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xxxxl)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .strokeBorder(Color.agentSlateLight.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newValue in
                    guard let newValue else { return }
                    Task { await handlePhotoSelection(newValue) }
                }

                if isUploading {
                    ProgressView("Uploading...")
                        .font(.caption)
                }

                PillButton(submitLabel, isLoading: isSubmitting, isDisabled: uploadedUrl == nil && record?.submittedData?["file_url"] == nil) {
                    Task { await submit() }
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
        .onAppear {
            if let url = record?.submittedData?["file_url"] {
                uploadedUrl = url
            }
        }
    }

    private var submitLabel: String {
        if record?.status == "rejected" { return "Resubmit" }
        if record?.status == "pending" { return "Update" }
        return "Submit Photo ID"
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        isUploading = true
        defer { isUploading = false }

        guard let userId = appState.authService.currentUser?.id else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.85) else { return }

            await MainActor.run {
                previewImage = Image(uiImage: uiImage)
            }

            let url = try await vettingService.uploadPhotoId(userId: userId, imageData: jpegData)
            await MainActor.run {
                uploadedUrl = url
            }
        } catch {
            print("[VerificationView] Photo upload failed: \(error)")
        }
    }

    private func submit() async {
        guard let url = uploadedUrl ?? record?.submittedData?["file_url"] else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await vettingService.submitRecord(type: "photo_id", submittedData: ["file_url": url])
        } catch {
            print("[VerificationView] Photo ID submit failed: \(error)")
        }
    }
}

// MARK: - Brokerage Step

private struct BrokerageStepView: View {
    let vettingService: VettingService
    @Environment(AppState.self) private var appState

    @State private var brokerageName = ""
    @State private var officePhone = ""
    @State private var isSubmitting = false

    private var record: VettingRecord? { vettingService.record(ofType: "brokerage") }
    private var isApproved: Bool { record?.status == "approved" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Brokerage Verification")
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)
                        Text("Provide your brokerage details")
                            .font(.caption)
                            .foregroundStyle(.agentSlate)
                    }
                }
                Spacer()
                if let record {
                    statusTag(record.status)
                }
            }

            if let record, record.status == "rejected", let notes = record.reviewerNotes {
                rejectionBanner(notes)
            }

            InputField(label: "Brokerage Name", text: $brokerageName, placeholder: "e.g., Keller Williams Realty")
                .disabled(isApproved)

            InputField(label: "Office Phone", text: $officePhone, placeholder: "(512) 555-9000", keyboardType: .phonePad)
                .disabled(isApproved)

            if !isApproved {
                PillButton(submitLabel, isLoading: isSubmitting, isDisabled: brokerageName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    Task { await submit() }
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
        .onAppear {
            if let data = record?.submittedData {
                brokerageName = data["brokerage_name"] ?? ""
                officePhone = data["office_phone"] ?? ""
            } else if let user = appState.authService.currentUser {
                brokerageName = user.brokerage ?? ""
            }
        }
    }

    private var submitLabel: String {
        if record?.status == "rejected" { return "Resubmit" }
        if record?.status == "pending" { return "Update" }
        return "Submit Brokerage"
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        var data: [String: String] = ["brokerage_name": brokerageName.trimmingCharacters(in: .whitespaces)]
        if !officePhone.isEmpty { data["office_phone"] = officePhone }

        do {
            try await vettingService.submitRecord(type: "brokerage", submittedData: data)
        } catch {
            print("[VerificationView] Brokerage submit failed: \(error)")
        }
    }
}

// MARK: - Helpers

private let US_STATES = [
    "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA",
    "KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
    "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT",
    "VA","WA","WV","WI","WY","DC",
]

private func statusTag(_ status: String) -> some View {
    Text(status.uppercased())
        .font(.system(size: 10, weight: .bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(
            status == "approved" ? Color.green :
            status == "rejected" ? Color.red :
            Color.orange
        )
        .background(
            (status == "approved" ? Color.green :
             status == "rejected" ? Color.red :
             Color.orange).opacity(0.1)
        )
        .clipShape(Capsule())
}

private func rejectionBanner(_ notes: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("Reviewer feedback:")
            .font(.captionSM)
            .foregroundStyle(.red)
        Text(notes)
            .font(.caption)
            .foregroundStyle(.red.opacity(0.8))
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.red.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
}

#Preview {
    NavigationStack {
        VerificationView()
            .environment(AppState.preview)
    }
}
