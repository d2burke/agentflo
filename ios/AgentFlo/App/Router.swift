import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.authService.isLoading {
            SplashView()
        } else if appState.authService.isAuthenticated && appState.needsOnboarding {
            OnboardingFlowView(role: appState.onboardingRole)
        } else if appState.authService.isAuthenticated {
            MainTabView()
                .overlay {
                    if appState.biometricService.isLocked && appState.biometricService.isBiometricEnabled {
                        LockScreenView()
                            .transition(.opacity)
                    }
                }
        } else {
            LandingView()
        }
    }
}
