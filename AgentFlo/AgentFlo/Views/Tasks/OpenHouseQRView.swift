import SwiftUI
import CoreImage.CIFilterBuiltins

struct OpenHouseQRView: View {
    let task: AgentTask

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var qrToken: String?
    @State private var showShareSheet = false

    private var qrURL: String? {
        guard let token = qrToken else { return nil }
        return "https://giloreldlxdpqsvmqiqh.supabase.co/functions/v1/open-house-checkin?token=\(token)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.sectionGap) {
                Spacer()

                if let qrURL, let qrImage = generateQRCode(from: qrURL) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280)
                        .padding(Spacing.xxl)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                        .shadow(color: Shadows.card, radius: 8, y: 4)
                }

                VStack(spacing: Spacing.md) {
                    Text("Scan to Check In")
                        .font(.titleMD)
                        .foregroundStyle(.agentNavy)
                    Text(task.propertyAddress)
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if qrURL != nil {
                    PillButton("Share QR Code", variant: .secondary) {
                        showShareSheet = true
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .background(.agentBackground)
            .navigationTitle("QR Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await ensureToken() }
            .sheet(isPresented: $showShareSheet) {
                if let qrURL {
                    ShareSheet(items: [qrURL])
                }
            }
        }
    }

    private func ensureToken() async {
        if let existing = task.qrCodeToken {
            qrToken = existing
            return
        }
        let newToken = UUID().uuidString
        do {
            try await appState.taskService.setQRCodeToken(taskId: task.id, token: newToken)
            qrToken = newToken
        } catch {
            print("[QR] Failed to set token: \(error)")
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 280.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
