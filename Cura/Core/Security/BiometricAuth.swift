import Foundation
import LocalAuthentication

// MARK: - BiometricAuth

/// Wraps LAContext.evaluatePolicy for Face ID / Touch ID authentication.
/// Returns true on success, false on any failure or cancellation.
struct BiometricAuth {

    /// Requests biometric authentication (Face ID or Touch ID).
    /// - Parameter reason: The localised reason string shown in the system prompt.
    /// - Returns: `true` if authentication succeeded, `false` otherwise.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var policyError: NSError?

        // Check whether biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            return false
        }

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch {
            // Authentication failed or was cancelled — return false without crashing
            return false
        }
    }

    /// Checks whether any biometric authentication is enrolled on the device.
    static var isAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Returns a human-readable label for the available biometry type.
    static var biometryLabel: String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return "Passcode"
        }
        switch context.biometryType {
        case .faceID:      return "Face ID"
        case .touchID:     return "Touch ID"
        case .opticID:     return "Optic ID"
        case .none:        return "Passcode"
        @unknown default:  return "Biometrics"
        }
    }
}
