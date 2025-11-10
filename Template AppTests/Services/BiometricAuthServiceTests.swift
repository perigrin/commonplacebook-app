// ABOUTME: Tests for biometric authentication service
// ABOUTME: Validates Face ID/Touch ID integration, app lock/unlock, and settings persistence

import XCTest
import LocalAuthentication
import CryptoKit
@testable import Template_App

@MainActor
final class BiometricAuthServiceTests: XCTestCase {
    var authService: BiometricAuthService!
    var mockSecurityManager: MockSecurityManager!

    override func setUpWithError() throws {
        mockSecurityManager = MockSecurityManager()
        authService = BiometricAuthService(securityManager: mockSecurityManager)
    }

    override func tearDownWithError() throws {
        authService = nil
        mockSecurityManager = nil
    }

    // MARK: - Biometric Availability Tests

    func testIsBiometricAvailableDetectsCapability() async throws {
        // GIVEN device with Face ID
        mockSecurityManager.mockBiometricType = .faceID

        // WHEN checking availability
        let available = await authService.isBiometricAvailable()

        // THEN should return true
        XCTAssertTrue(available, "Should detect biometric availability")
    }

    func testIsBiometricAvailableReturnsFalseWhenNone() async throws {
        // GIVEN device without biometrics
        mockSecurityManager.mockBiometricType = .none

        // WHEN checking availability
        let available = await authService.isBiometricAvailable()

        // THEN should return false
        XCTAssertFalse(available, "Should return false when biometrics unavailable")
    }

    func testBiometricTypeCorrectForDevice() async throws {
        // GIVEN device with Touch ID
        mockSecurityManager.mockBiometricType = .touchID

        // WHEN getting biometric type
        let type = await authService.biometricType

        // THEN should return touchID
        XCTAssertEqual(type, .touchID, "Should return correct biometric type")
    }

    // MARK: - Authentication Tests

    func testAuthenticateReturnsSuccess() async throws {
        // GIVEN successful authentication
        mockSecurityManager.mockAuthSuccess = true

        // WHEN authenticating
        let result = await authService.authenticate(reason: "Unlock app")

        // THEN should succeed
        XCTAssertTrue(result, "Authentication should succeed")
    }

    func testAuthenticateReturnsFailure() async throws {
        // GIVEN failed authentication
        mockSecurityManager.mockAuthSuccess = false

        // WHEN authenticating
        let result = await authService.authenticate(reason: "Unlock app")

        // THEN should fail
        XCTAssertFalse(result, "Authentication should fail")
    }

    // MARK: - Lock State Tests

    func testAppStartsUnlockedByDefault() async throws {
        // GIVEN new auth service
        // WHEN checking lock state
        let isLocked = await authService.isLocked

        // THEN should be unlocked
        XCTAssertFalse(isLocked, "App should start unlocked")
    }

    func testLockOnBackgroundSetsLockedState() async throws {
        // GIVEN unlocked app
        XCTAssertFalse(await authService.isLocked)

        // WHEN app enters background
        await authService.lockOnBackground()

        // THEN should be locked
        XCTAssertTrue(await authService.isLocked, "Should be locked after background")
    }

    func testUnlockOnForegroundRequiresAuth() async throws {
        // GIVEN locked app
        await authService.lockOnBackground()
        XCTAssertTrue(await authService.isLocked)

        // WHEN attempting to unlock with success
        mockSecurityManager.mockAuthSuccess = true
        let unlocked = await authService.unlockOnForeground()

        // THEN should unlock
        XCTAssertTrue(unlocked, "Should unlock on successful auth")
        XCTAssertFalse(await authService.isLocked, "Should no longer be locked")
    }

    func testUnlockFailsWithFailedAuth() async throws {
        // GIVEN locked app
        await authService.lockOnBackground()

        // WHEN attempting to unlock with failure
        mockSecurityManager.mockAuthSuccess = false
        let unlocked = await authService.unlockOnForeground()

        // THEN should remain locked
        XCTAssertFalse(unlocked, "Should not unlock on failed auth")
        XCTAssertTrue(await authService.isLocked, "Should remain locked")
    }

    // MARK: - Settings Toggle Tests

    func testBiometricEnabledDefaultsToFalse() async throws {
        // GIVEN new auth service
        // WHEN checking enabled state
        let enabled = await authService.isBiometricEnabled

        // THEN should be disabled by default
        XCTAssertFalse(enabled, "Biometric auth should be disabled by default")
    }

    func testEnableBiometricAuthPersistsSettings() async throws {
        // GIVEN disabled biometrics
        XCTAssertFalse(await authService.isBiometricEnabled)

        // WHEN enabling
        await authService.setBiometricEnabled(true)

        // THEN should be enabled
        XCTAssertTrue(await authService.isBiometricEnabled, "Should enable biometrics")

        // AND should persist across instances
        let newService = BiometricAuthService(securityManager: mockSecurityManager)
        XCTAssertTrue(await newService.isBiometricEnabled, "Setting should persist")
    }

    func testDisableBiometricAuthPersistsSettings() async throws {
        // GIVEN enabled biometrics
        await authService.setBiometricEnabled(true)
        XCTAssertTrue(await authService.isBiometricEnabled)

        // WHEN disabling
        await authService.setBiometricEnabled(false)

        // THEN should be disabled
        XCTAssertFalse(await authService.isBiometricEnabled, "Should disable biometrics")
    }

    func testLockOnBackgroundOnlyWhenEnabled() async throws {
        // GIVEN biometrics disabled
        await authService.setBiometricEnabled(false)

        // WHEN app enters background
        await authService.lockOnBackground()

        // THEN should NOT lock
        XCTAssertFalse(await authService.isLocked, "Should not lock when biometrics disabled")

        // WHEN enabling biometrics
        await authService.setBiometricEnabled(true)
        await authService.lockOnBackground()

        // THEN should lock
        XCTAssertTrue(await authService.isLocked, "Should lock when biometrics enabled")
    }

    // MARK: - Fallback Passcode Tests

    func testFallbackToPasscodeOnBiometricFailure() async throws {
        // GIVEN locked app with biometric failure
        await authService.setBiometricEnabled(true)
        await authService.lockOnBackground()
        mockSecurityManager.mockAuthSuccess = false

        // WHEN attempting unlock
        let unlocked = await authService.unlockOnForeground()

        // THEN should fail but offer fallback
        XCTAssertFalse(unlocked)
        XCTAssertTrue(await authService.shouldShowPasscodeFallback, "Should offer passcode fallback")
    }
}

// MARK: - Mock Security Manager

class MockSecurityManager: SecurityManaging {
    var mockBiometricType: SecurityManager.BiometricType = .faceID
    var mockAuthSuccess: Bool = true
    var authCallCount: Int = 0

    func getBiometricType() -> SecurityManager.BiometricType {
        return mockBiometricType
    }

    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        authCallCount += 1
        DispatchQueue.main.async {
            completion(self.mockAuthSuccess, nil)
        }
    }

    // Stub methods to satisfy protocol
    func storeInKeychain(_ data: Data, forKey key: String) -> Bool {
        return true
    }

    func getFromKeychain(forKey key: String) -> Data? {
        return nil
    }

    func deleteFromKeychain(forKey key: String) {
        // No-op for this mock
    }

    func encrypt(data: Data, with key: SymmetricKey) throws -> Data {
        return data
    }

    func decrypt(data: Data, with key: SymmetricKey) throws -> Data {
        return data
    }
}
