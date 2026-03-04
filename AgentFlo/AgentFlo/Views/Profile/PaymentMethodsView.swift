import SwiftUI
import StripePaymentSheet

struct PaymentMethodsView: View {
    @Environment(AppState.self) private var appState

    @State private var isLoading = false
    @State private var paymentSheet: PaymentSheet?
    @State private var hasPaymentMethod = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    private var user: AppUser? { appState.authService.currentUser }

    var body: some View {
        VStack {
            if hasPaymentMethod {
                paymentMethodCard
            } else {
                Spacer()
                EmptyStateView(
                    icon: "creditcard.fill",
                    title: "No Payment Methods",
                    message: "Add a card to pay for tasks. Your card will be charged when you approve deliverables.",
                    buttonTitle: "Add Payment Method",
                    buttonAction: {
                        Task { await setupPaymentSheet() }
                    }
                )
                securedByStripe
                Spacer()
            }
        }
        .background(.agentBackground)
        .navigationTitle("Payment Methods")
        .navigationBarTitleDisplayMode(.inline)
        .toast(showSuccess ? "Payment method added!" : (errorMessage ?? ""), style: showSuccess ? .success : .error, isPresented: showSuccess ? $showSuccess : $showError)
        .onAppear {
            hasPaymentMethod = user?.stripeCustomerId != nil
        }
    }

    private var paymentMethodCard: some View {
        VStack(spacing: Spacing.xxl) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.agentNavy)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment method on file")
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)
                    Text("Default payment method")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.agentGreen)
            }
            .padding(Spacing.cardPadding)
            .background(.agentSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .shadow(color: Shadows.card, radius: 4, y: 2)
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.xxl)

            PillButton("Update Payment Method", variant: .secondary, isLoading: isLoading) {
                Task { await setupPaymentSheet() }
            }
            .padding(.horizontal, Spacing.screenPadding)

            securedByStripe

            Spacer()
        }
    }

    private var securedByStripe: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.agentSlateLight)
            Text("Secured by Stripe")
                .font(.caption)
                .foregroundStyle(.agentSlateLight)
        }
        .padding(.top, Spacing.md)
    }

    private func setupPaymentSheet() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await appState.taskService.createSetupIntent()

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Agent Flo"
            configuration.customer = .init(
                id: response.customer,
                ephemeralKeySecret: response.ephemeralKey
            )

            STPAPIClient.shared.publishableKey = response.publishableKey

            let sheet = PaymentSheet(
                setupIntentClientSecret: response.setupIntent,
                configuration: configuration
            )
            paymentSheet = sheet

            await presentPaymentSheet()
        } catch {
            errorMessage = "Failed to set up payment: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    @MainActor
    private func presentPaymentSheet() async {
        guard let sheet = paymentSheet,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        sheet.present(from: topVC) { result in
            switch result {
            case .completed:
                hasPaymentMethod = true
                showSuccess = true
                if let userId = user?.id {
                    Task { await appState.authService.fetchUserProfile(userId: userId, forceRefresh: true) }
                }
            case .canceled:
                break
            case .failed(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaymentMethodsView()
    }
    .environment(AppState.preview)
}
