import SwiftUI

struct OnboardingCategoryView: View {
    let onSelect: (String) -> Void

    @Environment(AppState.self) private var appState

    private var categories: [(name: String, description: String, priceRange: String)] {
        [
            ("Photography", "Professional listing photos", "$100\u{2013}$300"),
            ("Showing", "Buyer or inspector showing", "$50\u{2013}$100"),
            ("Staging", "Furniture staging & setup", "$200\u{2013}$400"),
            ("Open House", "Host an open house event", "$75\u{2013}$150"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    Text("What do you need help with?")
                        .font(.titleLG)
                        .foregroundStyle(.agentNavy)

                    ForEach(categories, id: \.name) { cat in
                        Button {
                            onSelect(cat.name)
                        } label: {
                            HStack(spacing: Spacing.xxl) {
                                CategoryIcon(category: cat.name)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name)
                                        .font(.bodyEmphasis)
                                        .foregroundStyle(.agentNavy)
                                    Text(cat.description)
                                        .font(.caption)
                                        .foregroundStyle(.agentSlate)
                                }
                                Spacer()
                                Text(cat.priceRange)
                                    .font(.captionSM)
                                    .foregroundStyle(.agentSlateLight)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.agentSlateLight)
                            }
                            .padding(Spacing.cardPadding)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                            .shadow(color: Shadows.card, radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.xxl)
            }
            .scrollIndicators(.hidden)

            // Skip
            Button("Skip for now \u{2192}") {
                appState.selectedTab = .dashboard
                appState.needsOnboarding = false
            }
            .font(.bodySM)
            .foregroundStyle(.agentSlate)
            .padding(.vertical, Spacing.xxxxl)
        }
        .background(.agentBackground)
        .navigationTitle("New Task")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OnboardingCategoryView { _ in }
    }
    .environment(AppState.preview)
}
