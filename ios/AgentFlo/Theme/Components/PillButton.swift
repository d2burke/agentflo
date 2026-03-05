import SwiftUI

enum PillButtonVariant {
    case primary
    case primaryLarge
    case secondary
    case outlined
    case ghost
}

struct PillButton: View {
    let title: String
    let variant: PillButtonVariant
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        variant: PillButtonVariant = .primary,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                action()
            }
        }) {
            HStack(spacing: Spacing.md) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                        .scaleEffect(0.8)
                }
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.body)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .stroke(borderColor, lineWidth: hasBorder ? 2 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .sensoryFeedback(.impact(weight: .medium), trigger: isLoading)
    }

    private var verticalPadding: CGFloat {
        switch variant {
        default: 22
        }
    }

    private var horizontalPadding: CGFloat {
        variant == .primaryLarge ? 28 : 20
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary, .primaryLarge: .agentRed
        case .secondary: .agentSurface
        case .outlined: .agentSurface
        case .ghost: .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .primaryLarge: .white
        case .secondary: .agentNavy
        case .outlined: .agentNavy
        case .ghost: .agentRed
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: .agentRed
        case .outlined: .agentBorder
        default: .clear
        }
    }

    private var hasBorder: Bool {
        variant == .secondary || variant == .outlined
    }
}

#Preview {
    VStack(spacing: 16) {
        PillButton("Post Task", variant: .primary) {}
        PillButton("Post Task", variant: .primaryLarge) {}
        PillButton("Save Draft", variant: .secondary) {}
        PillButton("Cancel", variant: .outlined) {}
        PillButton("Skip", variant: .ghost) {}
        PillButton("Loading...", isLoading: true) {}
        PillButton("Disabled", isDisabled: true) {}
    }
    .padding()
}
