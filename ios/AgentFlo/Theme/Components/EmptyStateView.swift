import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.agentSlateLight)

            VStack(spacing: Spacing.md) {
                Text(title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.agentSlateLight)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let buttonAction {
                PillButton(buttonTitle, action: buttonAction)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxxl)
        .padding(.horizontal, Spacing.screenPadding)
    }
}

#Preview {
    VStack {
        EmptyStateView(
            icon: "tray",
            title: "No tasks yet",
            message: "Tap \"Create Task\" to post your first task."
        )
        EmptyStateView(
            icon: "creditcard.fill",
            title: "No Payment Methods",
            message: "Add a card to pay for tasks.",
            buttonTitle: "Add Payment Method",
            buttonAction: {}
        )
    }
}
