import Foundation
import LocalAuthentication

enum BiometricType {
    case faceID
    case touchID
    case none
}

enum BiometricService {
    private static var hasFaceIDUsageDescription: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") != nil
    }

    static func biometricType() -> BiometricType {
        guard hasFaceIDUsageDescription else { return .none }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .faceID // treat opticID same as faceID for UI purposes
        @unknown default:
            return .none
        }
    }

    static func canUseBiometrics() -> Bool {
        guard hasFaceIDUsageDescription else { return false }
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    static func authenticate(reason: String) async -> Bool {
        guard hasFaceIDUsageDescription else { return false }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
