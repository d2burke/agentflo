import Foundation
import LocalAuthentication

@Observable
final class BiometricAuthService {
    var isLocked = false
    var isBiometricAvailable = false

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: biometricEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: biometricEnabledKey) }
    }

    private var backgroundedAt: Date?
    private let lockTimeout: TimeInterval = 300 // 5 minutes
    private let biometricEnabledKey = "biometricAuthEnabled"

    init() {
        checkBiometricAvailability()
    }

    // MARK: - Availability

    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        // Use deviceOwnerAuthentication (biometrics + passcode fallback) so the
        // feature is available even when biometrics aren't enrolled (e.g. simulator).
        isBiometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Whether the device supports Face ID, Touch ID, or Optic ID hardware.
    var hasBiometricHardware: Bool {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType != .none
    }

    var biometricType: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        @unknown default: return "Biometrics"
        }
    }

    var biometricIconName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    // MARK: - Authentication

    @MainActor
    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        do {
            // Use deviceOwnerAuthentication to allow biometrics OR device passcode
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock AgentFlo"
            )
            if success {
                isLocked = false
            }
            return success
        } catch {
            print("[BiometricAuth] Authentication failed: \(error)")
            return false
        }
    }

    // MARK: - Background / Foreground Tracking

    func onBackground() {
        if isBiometricEnabled {
            backgroundedAt = Date()
        }
    }

    @MainActor
    func onForeground() {
        guard isBiometricEnabled else { return }
        guard let backgroundedAt else { return }

        let elapsed = Date().timeIntervalSince(backgroundedAt)
        if elapsed >= lockTimeout {
            isLocked = true
        }
        self.backgroundedAt = nil
    }
}
