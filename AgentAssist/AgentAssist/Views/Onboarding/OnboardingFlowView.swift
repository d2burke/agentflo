import SwiftUI

enum OnboardingStep: Hashable {
    case selectCategory
    case taskDetails(String)
}

struct OnboardingFlowView: View {
    let role: UserRole

    @Environment(AppState.self) private var appState
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcomeView(role: role) {
                if role == .agent {
                    path.append(.selectCategory)
                } else {
                    appState.selectedTab = .dashboard
                    appState.needsOnboarding = false
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .selectCategory:
                    OnboardingCategoryView { category in
                        path.append(.taskDetails(category))
                    }
                case .taskDetails(let category):
                    OnboardingTaskFormView(category: category)
                }
            }
        }
    }
}

#Preview("Agent") {
    OnboardingFlowView(role: .agent)
        .environment(AppState.preview)
}

#Preview("Runner") {
    OnboardingFlowView(role: .runner)
        .environment(AppState.previewRunner)
}
