// ABOUTME: Biometric authentication service for app-level lock/unlock functionality
// ABOUTME: Manages Face ID/Touch ID integration with app lifecycle and settings persistence

import Foundation
import LocalAuthentication

/// Service coordinating biometric authentication at the app level
@MainActor
class BiometricAuthService: ObservableObject {

    // MARK: - Published State

    /// Whether the app is currently locked
    @Published private(set) var isLocked: Bool = false

    /// Whether biometric authentication is enabled
    @Published private(set) var isBiometricEnabled: Bool

    /// Whether to show passcode fallback
    @Published private(set) var shouldShowPasscodeFallback: Bool = false

    // MARK: - Dependencies

    private let securityManager: SecurityManaging
    private let userDefaults: UserDefaults

    // MARK: - UserDefaults Keys

    private let biometricEnabledKey = "biometricAuthEnabled"

    // MARK: - Computed Properties

    /// The type of biometric authentication available
    var biometricType: SecurityManager.BiometricType {
        securityManager.getBiometricType()
    }

    /// Whether biometric authentication is available on this device
    func isBiometricAvailable() -> Bool {
        return biometricType != .none
    }

    // MARK: - Initialization

    init(securityManager: SecurityManaging = SecurityManager.shared, userDefaults: UserDefaults = .standard) {
        self.securityManager = securityManager
        self.userDefaults = userDefaults
        self.isBiometricEnabled = userDefaults.bool(forKey: biometricEnabledKey)
    }

    // MARK: - Settings Management

    /// Enable or disable biometric authentication
    func setBiometricEnabled(_ enabled: Bool) {
        isBiometricEnabled = enabled
        userDefaults.set(enabled, forKey: biometricEnabledKey)
    }

    // MARK: - Lock/Unlock Management

    /// Lock the app when entering background
    func lockOnBackground() {
        guard isBiometricEnabled else { return }
        isLocked = true
        shouldShowPasscodeFallback = false
    }

    /// Attempt to unlock the app when entering foreground
    /// - Returns: True if unlock was successful
    func unlockOnForeground() async -> Bool {
        guard isLocked else { return true }

        return await authenticate(reason: "Unlock \(Bundle.main.displayName)")
    }

    /// Authenticate with biometrics
    /// - Parameter reason: The reason to display to the user
    /// - Returns: True if authentication was successful
    func authenticate(reason: String) async -> Bool {
        guard isBiometricAvailable() else {
            // No biometrics available, unlock immediately
            isLocked = false
            return true
        }

        return await withCheckedContinuation { continuation in
            securityManager.authenticateWithBiometrics(reason: reason) { [weak self] success, error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume(returning: false)
                        return
                    }

                    if success {
                        self.isLocked = false
                        self.shouldShowPasscodeFallback = false
                        continuation.resume(returning: true)
                    } else {
                        // Authentication failed, offer passcode fallback
                        self.shouldShowPasscodeFallback = true
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    /// Manually lock the app (e.g., from settings)
    func lock() {
        isLocked = true
        shouldShowPasscodeFallback = false
    }

    /// Manually unlock the app (e.g., with passcode fallback)
    func unlock() {
        isLocked = false
        shouldShowPasscodeFallback = false
    }

    // MARK: - Testing/Preview Support

    #if DEBUG
    /// Set fallback state for testing/previews
    func setPasscodeFallback(_ show: Bool) {
        shouldShowPasscodeFallback = show
    }
    #endif
}

// MARK: - Bundle Extension

private extension Bundle {
    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
    }
}
