import SwiftUI

struct InputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false
    var errorMessage: String? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    var submitLabel: SubmitLabel = .return
    var onSubmit: (() -> Void)? = nil

    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            HStack {
                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                        .textContentType(textContentType)
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                } else {
                    TextField(placeholder, text: $text, onEditingChanged: { editing in
                        onEditingChanged?(editing)
                    })
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
                }

                if !text.isEmpty && !isSecure {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.agentSlateLight)
                    }
                }

                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.agentSlateLight)
                    }
                }
            }
            .font(.bodySM)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .background(.agentSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.input)
                    .stroke(borderColor, lineWidth: 1.5)
            )

            if let error = errorMessage {
                Text(error)
                    .font(.captionSM)
                    .foregroundStyle(.agentError)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return .agentError }
        if isFocused { return .agentRed }
        return .agentBorder
    }
}

#Preview {
    VStack(spacing: 16) {
        InputField(label: "Email", text: .constant(""), placeholder: "you@example.com", keyboardType: .emailAddress)
        InputField(label: "Password", text: .constant(""), placeholder: "Enter password", isSecure: true)
        InputField(label: "Error", text: .constant("bad"), errorMessage: "Invalid input")
    }
    .padding()
}
