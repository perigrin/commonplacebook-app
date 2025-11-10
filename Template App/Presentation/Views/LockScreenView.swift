// ABOUTME: Lock screen overlay displayed when app is locked with biometric authentication
// ABOUTME: Shows Face ID/Touch ID prompt and handles unlock attempts

import SwiftUI

/// Lock screen overlay for biometric authentication
struct LockScreenView: View {
    @ObservedObject var authService: BiometricAuthService

    var body: some View {
        ZStack {
            // Blur background
            Color.black
                .opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Lock icon
                Image(systemName: lockIcon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                // App name
                Text(appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                // Instructions
                Text(unlockInstructions)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Unlock button
                Button {
                    Task {
                        _ = await authService.authenticate(reason: "Unlock \(appName)")
                    }
                } label: {
                    HStack {
                        Image(systemName: biometricIcon)
                        Text(unlockButtonText)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                // Passcode fallback (if shown)
                if authService.shouldShowPasscodeFallback {
                    Button("Enter Passcode") {
                        Task {
                            // Use device passcode authentication as fallback
                            await authService.authenticateWithDevicePasscode()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }

                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            // Automatically trigger authentication on appear
            Task {
                _ = await authService.unlockOnForeground()
            }
        }
    }

    // MARK: - Computed Properties

    private var appName: String {
        Bundle.main.displayName
    }

    private var lockIcon: String {
        switch authService.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.fill"
        }
    }

    private var biometricIcon: String {
        switch authService.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.open.fill"
        }
    }

    private var unlockButtonText: String {
        switch authService.biometricType {
        case .faceID:
            return "Unlock with Face ID"
        case .touchID:
            return "Unlock with Touch ID"
        case .none:
            return "Unlock"
        }
    }

    private var unlockInstructions: String {
        switch authService.biometricType {
        case .faceID:
            return "Use Face ID to unlock and access your notes"
        case .touchID:
            return "Use Touch ID to unlock and access your notes"
        case .none:
            return "App is locked"
        }
    }
}

// MARK: - Bundle Extension

private extension Bundle {
    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
    }
}

// MARK: - Previews

struct LockScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Face ID preview
            LockScreenView(authService: mockAuthService(.faceID))
                .previewDisplayName("Face ID")

            // Touch ID preview
            LockScreenView(authService: mockAuthService(.touchID))
                .previewDisplayName("Touch ID")

            // With fallback
            LockScreenView(authService: mockAuthServiceWithFallback())
                .previewDisplayName("With Passcode Fallback")
        }
    }

    static func mockAuthService(_ type: SecurityManager.BiometricType) -> BiometricAuthService {
        let mock = MockSecurityManagerForPreview(biometricType: type)
        let service = BiometricAuthService(securityManager: mock)
        return service
    }

    static func mockAuthServiceWithFallback() -> BiometricAuthService {
        let mock = MockSecurityManagerForPreview(biometricType: .faceID)
        let service = BiometricAuthService(securityManager: mock)
        Task { @MainActor in
            await service.lockOnBackground()
            // Simulate failed auth to show fallback
            #if DEBUG
            service.setPasscodeFallback(true)
            #endif
        }
        return service
    }
}

// MARK: - Preview Mock

private class MockSecurityManagerForPreview: SecurityManaging {
    let biometricType: SecurityManager.BiometricType

    init(biometricType: SecurityManager.BiometricType) {
        self.biometricType = biometricType
    }

    func getBiometricType() -> SecurityManager.BiometricType {
        return biometricType
    }

    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
    }

    func storeInKeychain(_ data: Data, forKey key: String) -> Bool { true }
    func getFromKeychain(forKey key: String) -> Data? { nil }
    func deleteFromKeychain(forKey key: String) { }
    func encrypt(data: Data, with key: SymmetricKey) throws -> Data { data }
    func decrypt(data: Data, with key: SymmetricKey) throws -> Data { data }
}
