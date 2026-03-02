import SwiftUI

enum BannerStyle {
    case error
    case success
    case info

    var icon: String {
        switch self {
        case .error: "exclamationmark.triangle.fill"
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .error: .agentError
        case .success: .agentGreen
        case .info: .agentBlue
        }
    }

    var backgroundColor: Color {
        switch self {
        case .error: .agentErrorLight
        case .success: .agentGreenLight
        case .info: .agentBlueLight
        }
    }

    var borderColor: Color {
        switch self {
        case .error: .agentError.opacity(0.3)
        case .success: .agentGreen.opacity(0.3)
        case .info: .agentBlue.opacity(0.3)
        }
    }
}

struct NotificationBanner: View {
    let message: String
    var style: BannerStyle = .error
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            Image(systemName: style.icon)
                .font(.system(size: 18))
                .foregroundStyle(style.iconColor)

            Text(message)
                .font(.bodySM)
                .foregroundStyle(.agentNavy)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.agentSlate)
                }
            }
        }
        .padding(Spacing.xxl)
        .background(style.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(style.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }
}

/// A toast-style banner that slides in from the top with auto-dismiss
struct ToastBanner: View {
    let message: String
    var style: BannerStyle = .error
    @Binding var isPresented: Bool
    var autoDismissAfter: TimeInterval = 4.0

    var body: some View {
        if isPresented {
            NotificationBanner(message: message, style: style) {
                withAnimation(.spring(duration: 0.3)) {
                    isPresented = false
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                if autoDismissAfter > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter) {
                        withAnimation(.spring(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

/// View modifier for showing toast banners
struct ToastModifier: ViewModifier {
    let message: String
    let style: BannerStyle
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                ToastBanner(message: message, style: style, isPresented: $isPresented)
            }
            .animation(.spring(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(_ message: String, style: BannerStyle = .error, isPresented: Binding<Bool>) -> some View {
        modifier(ToastModifier(message: message, style: style, isPresented: isPresented))
    }
}

#Preview {
    VStack(spacing: 16) {
        NotificationBanner(message: "Invalid email or password. Please try again.", style: .error) {}
        NotificationBanner(message: "Account created successfully!", style: .success) {}
        NotificationBanner(message: "Check your email to confirm your account.", style: .info) {}
        NotificationBanner(message: "Something went wrong. This is a longer error message to test wrapping behavior across multiple lines.")
    }
    .padding()
}
