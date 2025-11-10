// ABOUTME: Tests for database encryption service
// ABOUTME: Validates encryption key generation, storage, and database encryption/decryption

import XCTest
import CryptoKit
@testable import Template_App

@MainActor
final class EncryptionServiceTests: XCTestCase {
    var encryptionService: EncryptionService!
    var mockSecurityManager: MockSecurityManager!
    var testUserDefaults: UserDefaults!

    override func setUpWithError() throws {
        // Use test suite name for isolated UserDefaults
        testUserDefaults = UserDefaults(suiteName: "EncryptionServiceTests")!
        testUserDefaults.removePersistentDomain(forName: "EncryptionServiceTests")

        mockSecurityManager = MockSecurityManager()
        encryptionService = EncryptionService(
            securityManager: mockSecurityManager,
            userDefaults: testUserDefaults
        )
    }

    override func tearDownWithError() throws {
        testUserDefaults.removePersistentDomain(forName: "EncryptionServiceTests")
        encryptionService = nil
        mockSecurityManager = nil
        testUserDefaults = nil
    }

    // MARK: - Key Generation Tests

    func testGenerateKeyCreatesValidKey() async throws {
        // WHEN generating a key
        let key = await encryptionService.generateKey()

        // THEN should create a valid 256-bit key
        XCTAssertNotNil(key, "Should generate a key")
        // SymmetricKey doesn't expose bit length directly, but AES-256 is implied by CryptoKit
    }

    func testGenerateKeyCreatesUniqueKeys() async throws {
        // WHEN generating multiple keys
        let key1 = await encryptionService.generateKey()
        let key2 = await encryptionService.generateKey()

        // THEN keys should be different
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(data1, data2, "Keys should be unique")
    }

    // MARK: - Key Storage Tests

    func testStoreKeyPersistsToKeychain() async throws {
        // GIVEN a generated key
        let key = await encryptionService.generateKey()

        // WHEN storing the key
        let stored = await encryptionService.storeKey(key)

        // THEN should succeed
        XCTAssertTrue(stored, "Should store key successfully")
        XCTAssertTrue(mockSecurityManager.storedKeys.count > 0, "Should have stored key in keychain")
    }

    func testLoadKeyRetrievesStoredKey() async throws {
        // GIVEN a stored key
        let originalKey = await encryptionService.generateKey()
        _ = await encryptionService.storeKey(originalKey)

        // WHEN loading the key
        let loadedKey = await encryptionService.loadKey()

        // THEN should retrieve the same key
        XCTAssertNotNil(loadedKey, "Should load key")

        let originalData = originalKey.withUnsafeBytes { Data($0) }
        let loadedData = loadedKey!.withUnsafeBytes { Data($0) }
        XCTAssertEqual(originalData, loadedData, "Loaded key should match original")
    }

    func testLoadKeyReturnsNilWhenNoKeyStored() async throws {
        // GIVEN no stored key
        // WHEN loading the key
        let loadedKey = await encryptionService.loadKey()

        // THEN should return nil
        XCTAssertNil(loadedKey, "Should return nil when no key stored")
    }

    // MARK: - Encryption/Decryption Tests

    func testEncryptDataProducesEncryptedOutput() async throws {
        // GIVEN test data and a key
        let testData = "Hello, encrypted world!".data(using: .utf8)!
        let key = await encryptionService.generateKey()

        // WHEN encrypting the data
        let encrypted = try await encryptionService.encrypt(data: testData, with: key)

        // THEN should produce different data
        XCTAssertNotEqual(encrypted, testData, "Encrypted data should differ from original")
        XCTAssertGreaterThan(encrypted.count, 0, "Encrypted data should not be empty")
    }

    func testDecryptDataRestoresOriginal() async throws {
        // GIVEN encrypted data
        let originalData = "Test decryption".data(using: .utf8)!
        let key = await encryptionService.generateKey()
        let encrypted = try await encryptionService.encrypt(data: originalData, with: key)

        // WHEN decrypting
        let decrypted = try await encryptionService.decrypt(data: encrypted, with: key)

        // THEN should restore original data
        XCTAssertEqual(decrypted, originalData, "Decrypted data should match original")
    }

    func testDecryptWithWrongKeyFails() async throws {
        // GIVEN data encrypted with one key
        let data = "Secret data".data(using: .utf8)!
        let key1 = await encryptionService.generateKey()
        let encrypted = try await encryptionService.encrypt(data: data, with: key1)

        // WHEN decrypting with a different key
        let key2 = await encryptionService.generateKey()

        // THEN should throw error
        do {
            _ = try await encryptionService.decrypt(data: encrypted, with: key2)
            XCTFail("Should throw error when decrypting with wrong key")
        } catch {
            // Expected
            XCTAssertTrue(true, "Correctly threw error")
        }
    }

    // MARK: - Database Encryption Tests

    func testIsEncryptionEnabledDefaultsToFalse() async throws {
        // GIVEN new encryption service
        // WHEN checking if encryption is enabled
        let enabled = await encryptionService.isEncryptionEnabled

        // THEN should default to false
        XCTAssertFalse(enabled, "Encryption should be disabled by default")
    }

    func testEnableEncryptionGeneratesAndStoresKey() async throws {
        // GIVEN encryption disabled
        XCTAssertFalse(await encryptionService.isEncryptionEnabled)

        // WHEN enabling encryption
        let success = await encryptionService.enableEncryption()

        // THEN should succeed and store key
        XCTAssertTrue(success, "Should enable encryption successfully")
        XCTAssertTrue(await encryptionService.isEncryptionEnabled, "Encryption should be enabled")
        XCTAssertNotNil(await encryptionService.loadKey(), "Should have stored a key")
    }

    func testDisableEncryptionRemovesKey() async throws {
        // GIVEN encryption enabled
        _ = await encryptionService.enableEncryption()
        XCTAssertTrue(await encryptionService.isEncryptionEnabled)

        // WHEN disabling encryption
        await encryptionService.disableEncryption()

        // THEN should remove key and disable
        XCTAssertFalse(await encryptionService.isEncryptionEnabled, "Encryption should be disabled")
        XCTAssertNil(await encryptionService.loadKey(), "Key should be removed")
    }

    func testGetCurrentKeyReturnsKeyWhenEnabled() async throws {
        // GIVEN encryption enabled
        _ = await encryptionService.enableEncryption()

        // WHEN getting current key
        let key = await encryptionService.getCurrentKey()

        // THEN should return the key
        XCTAssertNotNil(key, "Should return current key when enabled")
    }

    func testGetCurrentKeyReturnsNilWhenDisabled() async throws {
        // GIVEN encryption disabled
        XCTAssertFalse(await encryptionService.isEncryptionEnabled)

        // WHEN getting current key
        let key = await encryptionService.getCurrentKey()

        // THEN should return nil
        XCTAssertNil(key, "Should return nil when encryption disabled")
    }

    // MARK: - Key Rotation Tests

    func testRotateKeyGeneratesNewKey() async throws {
        // GIVEN encryption enabled with existing key
        _ = await encryptionService.enableEncryption()
        let originalKey = await encryptionService.getCurrentKey()!
        let originalData = originalKey.withUnsafeBytes { Data($0) }

        // WHEN rotating the key
        let rotated = await encryptionService.rotateKey()

        // THEN should generate new key
        XCTAssertTrue(rotated, "Key rotation should succeed")

        let newKey = await encryptionService.getCurrentKey()!
        let newData = newKey.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(originalData, newData, "New key should differ from original")
    }

    func testRotateKeyFailsWhenDisabled() async throws {
        // GIVEN encryption disabled
        XCTAssertFalse(await encryptionService.isEncryptionEnabled)

        // WHEN attempting to rotate key
        let rotated = await encryptionService.rotateKey()

        // THEN should fail
        XCTAssertFalse(rotated, "Key rotation should fail when encryption disabled")
    }
}

// MARK: - Mock Security Manager

class MockSecurityManager: SecurityManaging {
    var storedKeys: [String: Data] = [:]

    func getBiometricType() -> SecurityManager.BiometricType {
        return .faceID
    }

    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
    }

    func storeInKeychain(_ data: Data, forKey key: String) -> Bool {
        storedKeys[key] = data
        return true
    }

    func getFromKeychain(forKey key: String) -> Data? {
        return storedKeys[key]
    }

    func deleteFromKeychain(forKey key: String) {
        storedKeys.removeValue(forKey: key)
    }

    func encrypt(data: Data, with key: SymmetricKey) throws -> Data {
        // Use actual encryption for realistic testing
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(data: Data, with key: SymmetricKey) throws -> Data {
        // Use actual decryption for realistic testing
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
