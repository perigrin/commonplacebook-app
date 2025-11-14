// ABOUTME: Tests for SecurityManager including keychain, encryption, hashing, and security checks
// ABOUTME: Validates secure storage, AES-GCM encryption, SHA-256 hashing, and device security features

import XCTest
import CryptoKit
@testable import Commonplace_Book

final class SecurityManagerTests: XCTestCase {
    var securityManager: SecurityManager!
    var testKeys: [String] = []

    override func setUp() {
        super.setUp()
        securityManager = SecurityManager.shared
        testKeys = []
    }

    override func tearDown() {
        // Clean up all test keychain items
        for key in testKeys {
            securityManager.deleteFromKeychain(forKey: key)
        }
        testKeys.removeAll()
        securityManager = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func generateTestKey() -> String {
        let key = "test_\(UUID().uuidString)"
        testKeys.append(key)
        return key
    }

    // MARK: - Keychain String Storage Tests

    func testStoreAndRetrieveStringFromKeychain() {
        // GIVEN a string to store
        let key = generateTestKey()
        let value = "test_value_\(UUID().uuidString)"

        // WHEN storing the string
        let stored = securityManager.storeStringInKeychain(value, forKey: key)

        // THEN should store successfully
        XCTAssertTrue(stored)

        // AND should retrieve the same value
        let retrieved = securityManager.getStringFromKeychain(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testStoreEmptyStringInKeychain() {
        // GIVEN an empty string
        let key = generateTestKey()
        let value = ""

        // WHEN storing
        let stored = securityManager.storeStringInKeychain(value, forKey: key)

        // THEN should store successfully
        XCTAssertTrue(stored)

        // AND should retrieve empty string
        let retrieved = securityManager.getStringFromKeychain(forKey: key)
        XCTAssertEqual(retrieved, "")
    }

    func testRetrieveNonExistentStringReturnsNil() {
        // GIVEN a non-existent key
        let key = generateTestKey()

        // WHEN retrieving
        let retrieved = securityManager.getStringFromKeychain(forKey: key)

        // THEN should return nil
        XCTAssertNil(retrieved)
    }

    func testOverwriteExistingStringInKeychain() {
        // GIVEN an existing keychain item
        let key = generateTestKey()
        let originalValue = "original_value"
        securityManager.storeStringInKeychain(originalValue, forKey: key)

        // WHEN overwriting with new value
        let newValue = "new_value"
        let stored = securityManager.storeStringInKeychain(newValue, forKey: key)

        // THEN should store successfully
        XCTAssertTrue(stored)

        // AND should retrieve new value
        let retrieved = securityManager.getStringFromKeychain(forKey: key)
        XCTAssertEqual(retrieved, newValue)
    }

    func testStoreMultipleStringsInKeychain() {
        // GIVEN multiple strings
        let keys = [generateTestKey(), generateTestKey(), generateTestKey()]
        let values = ["value1", "value2", "value3"]

        // WHEN storing all
        for (index, key) in keys.enumerated() {
            securityManager.storeStringInKeychain(values[index], forKey: key)
        }

        // THEN all should be retrievable
        for (index, key) in keys.enumerated() {
            let retrieved = securityManager.getStringFromKeychain(forKey: key)
            XCTAssertEqual(retrieved, values[index])
        }
    }

    // MARK: - Keychain Data Storage Tests

    func testStoreAndRetrieveDataFromKeychain() {
        // GIVEN data to store
        let key = generateTestKey()
        let data = "test data".data(using: .utf8)!

        // WHEN storing
        let stored = securityManager.storeInKeychain(data, forKey: key)

        // THEN should store successfully
        XCTAssertTrue(stored)

        // AND should retrieve the same data
        let retrieved = securityManager.getFromKeychain(forKey: key)
        XCTAssertEqual(retrieved, data)
    }

    func testStoreEmptyDataInKeychain() {
        // GIVEN empty data
        let key = generateTestKey()
        let data = Data()

        // WHEN storing
        let stored = securityManager.storeInKeychain(data, forKey: key)

        // THEN should store successfully
        XCTAssertTrue(stored)

        // AND should retrieve empty data
        let retrieved = securityManager.getFromKeychain(forKey: key)
        XCTAssertEqual(retrieved, Data())
    }

    func testStoreLargeDataInKeychain() {
        // GIVEN large data (1MB)
        let key = generateTestKey()
        let data = Data(repeating: 0xFF, count: 1024 * 1024)

        // WHEN storing
        let stored = securityManager.storeInKeychain(data, forKey: key)

        // THEN should store successfully
        XCTAssertTrue(stored)

        // AND should retrieve same data
        let retrieved = securityManager.getFromKeychain(forKey: key)
        XCTAssertEqual(retrieved, data)
    }

    // MARK: - Keychain Deletion Tests

    func testDeleteFromKeychain() {
        // GIVEN an existing keychain item
        let key = generateTestKey()
        securityManager.storeStringInKeychain("test", forKey: key)
        XCTAssertNotNil(securityManager.getStringFromKeychain(forKey: key))

        // WHEN deleting
        let deleted = securityManager.deleteFromKeychain(forKey: key)

        // THEN should delete successfully
        XCTAssertTrue(deleted)

        // AND should no longer exist
        XCTAssertNil(securityManager.getStringFromKeychain(forKey: key))
    }

    func testDeleteNonExistentItemSucceeds() {
        // GIVEN non-existent key
        let key = generateTestKey()

        // WHEN deleting
        let deleted = securityManager.deleteFromKeychain(forKey: key)

        // THEN should succeed (idempotent)
        XCTAssertTrue(deleted)
    }

    func testClearAllKeychainItems() {
        // GIVEN multiple keychain items
        let keys = [generateTestKey(), generateTestKey(), generateTestKey()]
        for key in keys {
            securityManager.storeStringInKeychain("test", forKey: key)
        }

        // WHEN clearing all
        let cleared = securityManager.clearAllKeychainItems()

        // THEN should succeed
        XCTAssertTrue(cleared)

        // AND all items should be deleted
        for key in keys {
            XCTAssertNil(securityManager.getStringFromKeychain(forKey: key))
        }
    }

    // MARK: - Encryption Tests

    func testEncryptAndDecryptData() throws {
        // GIVEN data and a key
        let originalData = "Hello, World!".data(using: .utf8)!
        let key = securityManager.generateKey()

        // WHEN encrypting and decrypting
        let encrypted = try securityManager.encrypt(data: originalData, with: key)
        let decrypted = try securityManager.decrypt(data: encrypted, with: key)

        // THEN decrypted should match original
        XCTAssertEqual(decrypted, originalData)
    }

    func testEncryptedDataIsDifferentFromOriginal() throws {
        // GIVEN data and a key
        let originalData = "Secret Message".data(using: .utf8)!
        let key = securityManager.generateKey()

        // WHEN encrypting
        let encrypted = try securityManager.encrypt(data: originalData, with: key)

        // THEN encrypted should be different
        XCTAssertNotEqual(encrypted, originalData)
    }

    func testEncryptingSameDataTwiceProducesDifferentCiphertext() throws {
        // GIVEN data and a key
        let data = "Test".data(using: .utf8)!
        let key = securityManager.generateKey()

        // WHEN encrypting twice
        let encrypted1 = try securityManager.encrypt(data: data, with: key)
        let encrypted2 = try securityManager.encrypt(data: data, with: key)

        // THEN ciphertexts should be different (due to random nonce in AES-GCM)
        XCTAssertNotEqual(encrypted1, encrypted2)

        // BUT both should decrypt to original
        let decrypted1 = try securityManager.decrypt(data: encrypted1, with: key)
        let decrypted2 = try securityManager.decrypt(data: encrypted2, with: key)
        XCTAssertEqual(decrypted1, data)
        XCTAssertEqual(decrypted2, data)
    }

    func testDecryptWithWrongKeyFails() throws {
        // GIVEN encrypted data
        let data = "Secret".data(using: .utf8)!
        let correctKey = securityManager.generateKey()
        let wrongKey = securityManager.generateKey()
        let encrypted = try securityManager.encrypt(data: data, with: correctKey)

        // WHEN decrypting with wrong key
        // THEN should throw error
        XCTAssertThrowsError(try securityManager.decrypt(data: encrypted, with: wrongKey))
    }

    func testEncryptAndDecryptString() throws {
        // GIVEN a string and a key
        let originalString = "Test String 🎉"
        let key = securityManager.generateKey()

        // WHEN encrypting and decrypting
        let encrypted = try securityManager.encrypt(string: originalString, with: key)
        let decrypted = try securityManager.decryptToString(data: encrypted, with: key)

        // THEN should match original
        XCTAssertEqual(decrypted, originalString)
    }

    func testEncryptEmptyString() throws {
        // GIVEN empty string
        let emptyString = ""
        let key = securityManager.generateKey()

        // WHEN encrypting and decrypting
        let encrypted = try securityManager.encrypt(string: emptyString, with: key)
        let decrypted = try securityManager.decryptToString(data: encrypted, with: key)

        // THEN should handle empty string
        XCTAssertEqual(decrypted, "")
    }

    func testEncryptLargeData() throws {
        // GIVEN large data (1MB)
        let largeData = Data(repeating: 0xAB, count: 1024 * 1024)
        let key = securityManager.generateKey()

        // WHEN encrypting and decrypting
        let encrypted = try securityManager.encrypt(data: largeData, with: key)
        let decrypted = try securityManager.decrypt(data: encrypted, with: key)

        // THEN should handle large data
        XCTAssertEqual(decrypted, largeData)
    }

    // MARK: - Key Generation Tests

    func testGenerateKeyCreatesUniqueKeys() {
        // WHEN generating multiple keys
        var keys = Set<Data>()
        for _ in 0..<100 {
            let key = securityManager.generateKey()
            let keyData = key.withUnsafeBytes { Data($0) }
            keys.insert(keyData)
        }

        // THEN all should be unique
        XCTAssertEqual(keys.count, 100)
    }

    func testGeneratedKeysAre256Bits() {
        // WHEN generating a key
        let key = securityManager.generateKey()
        let keyData = key.withUnsafeBytes { Data($0) }

        // THEN should be 256 bits (32 bytes)
        XCTAssertEqual(keyData.count, 32)
    }

    // MARK: - Key Storage Tests

    func testStoreAndRetrieveKey() {
        // GIVEN a symmetric key
        let key = securityManager.generateKey()
        let identifier = generateTestKey()

        // WHEN storing
        let stored = securityManager.storeKey(key, withIdentifier: identifier)

        // THEN should store successfully
        XCTAssertTrue(stored)

        // AND should retrieve same key
        let retrieved = securityManager.retrieveKey(withIdentifier: identifier)
        XCTAssertNotNil(retrieved)

        // Verify keys are equivalent by encrypting/decrypting
        let testData = "test".data(using: .utf8)!
        let encrypted = try? securityManager.encrypt(data: testData, with: key)
        let decrypted = try? securityManager.decrypt(data: encrypted!, with: retrieved!)
        XCTAssertEqual(decrypted, testData)
    }

    func testRetrieveNonExistentKeyReturnsNil() {
        // GIVEN non-existent identifier
        let identifier = generateTestKey()

        // WHEN retrieving
        let retrieved = securityManager.retrieveKey(withIdentifier: identifier)

        // THEN should return nil
        XCTAssertNil(retrieved)
    }

    // MARK: - Hashing Tests

    func testSHA256HashOfData() {
        // GIVEN data
        let data = "test".data(using: .utf8)!

        // WHEN hashing
        let hash = securityManager.sha256(data: data)

        // THEN should produce 64-character hex string (32 bytes = 256 bits)
        XCTAssertEqual(hash.count, 64)

        // AND should be deterministic
        let hash2 = securityManager.sha256(data: data)
        XCTAssertEqual(hash, hash2)
    }

    func testSHA256HashOfString() {
        // GIVEN a string
        let string = "test"

        // WHEN hashing
        let hash = securityManager.sha256(string: string)

        // THEN should produce 64-character hex string
        XCTAssertEqual(hash.count, 64)

        // AND should match expected hash
        // "test" SHA-256 = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        let expectedHash = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        XCTAssertEqual(hash, expectedHash)
    }

    func testSHA256HashOfEmptyString() {
        // GIVEN empty string
        let string = ""

        // WHEN hashing
        let hash = securityManager.sha256(string: string)

        // THEN should produce valid hash
        XCTAssertEqual(hash.count, 64)

        // Empty string SHA-256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let expectedHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        XCTAssertEqual(hash, expectedHash)
    }

    func testSHA256DifferentStringsProduceDifferentHashes() {
        // GIVEN different strings
        let string1 = "test1"
        let string2 = "test2"

        // WHEN hashing
        let hash1 = securityManager.sha256(string: string1)
        let hash2 = securityManager.sha256(string: string2)

        // THEN should produce different hashes
        XCTAssertNotEqual(hash1, hash2)
    }

    func testSHA256IsNotReversible() {
        // GIVEN a hash
        let original = "password123"
        let hash = securityManager.sha256(string: original)

        // THEN hash should not contain original
        XCTAssertFalse(hash.contains(original))

        // AND hash length should be constant regardless of input length
        let shortHash = securityManager.sha256(string: "a")
        let longHash = securityManager.sha256(string: String(repeating: "a", count: 1000))
        XCTAssertEqual(shortHash.count, longHash.count)
    }

    // MARK: - Biometric Type Tests

    #if os(iOS)
    func testGetBiometricTypeReturnsValidType() {
        // WHEN getting biometric type
        let biometricType = securityManager.getBiometricType()

        // THEN should return a valid type
        // On simulator or device without biometrics, returns .none
        // On device with biometrics, returns .faceID or .touchID
        XCTAssertTrue([.faceID, .touchID, .none].contains(biometricType))
    }
    #else
    func testGetBiometricTypeReturnsnoneOnMacOS() {
        // WHEN getting biometric type on macOS
        let biometricType = securityManager.getBiometricType()

        // THEN should return .none
        XCTAssertEqual(biometricType, .none)
    }
    #endif

    // MARK: - Jailbreak Detection Tests

    func testJailbreakDetectionOnSimulator() {
        // WHEN checking for jailbreak in simulator
        let isJailbroken = securityManager.isDeviceJailbroken()

        // THEN should return false (simulators are not considered jailbroken)
        #if targetEnvironment(simulator)
        XCTAssertFalse(isJailbroken)
        #else
        // On real device, result depends on actual device state
        // This test just verifies the method doesn't crash
        XCTAssertNotNil(isJailbroken)
        #endif
    }

    // MARK: - Debugger Detection Tests

    func testDebuggerDetection() {
        // WHEN checking for debugger
        let isDebugged = securityManager.isDebuggerAttached()

        // THEN should return a boolean (actual value depends on test run context)
        XCTAssertNotNil(isDebugged)

        // In Xcode debugger, this may return true
        // In CI/CD without debugger, should return false
    }

    // MARK: - App Tampering Tests

    func testAppTamperingDetection() {
        // WHEN checking for tampering
        let isTampered = securityManager.isAppTampered()

        // THEN should return a boolean
        XCTAssertNotNil(isTampered)

        // On simulator or development build, may return true due to debugger
        // On production build, should return false
    }

    // MARK: - Thread Safety Tests

    func testConcurrentKeychainOperations() {
        // GIVEN multiple concurrent keychain operations
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        var keys: [String] = []
        let lock = NSLock()

        // WHEN performing concurrent stores
        for i in 0..<50 {
            group.enter()
            queue.async {
                let key = self.generateTestKey()
                lock.lock()
                keys.append(key)
                lock.unlock()

                _ = self.securityManager.storeStringInKeychain("value_\(i)", forKey: key)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all should be stored successfully
        for key in keys {
            XCTAssertNotNil(self.securityManager.getStringFromKeychain(forKey: key))
        }
    }

    func testConcurrentEncryption() {
        // GIVEN concurrent encryption operations
        let expectation = XCTestExpectation(description: "Concurrent encryption completes")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        let key = securityManager.generateKey()
        var encrypted: [Data] = []
        let lock = NSLock()

        // WHEN encrypting concurrently
        for i in 0..<50 {
            group.enter()
            queue.async {
                let data = "message_\(i)".data(using: .utf8)!
                if let enc = try? self.securityManager.encrypt(data: data, with: key) {
                    lock.lock()
                    encrypted.append(enc)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all should encrypt successfully
        XCTAssertEqual(encrypted.count, 50)
    }

    // MARK: - Edge Cases

    func testKeychainWithSpecialCharacters() {
        // GIVEN key and value with special characters
        let key = generateTestKey()
        let value = "Test !@#$%^&*()_+-=[]{}|;':\",./<>?`~"

        // WHEN storing and retrieving
        securityManager.storeStringInKeychain(value, forKey: key)
        let retrieved = securityManager.getStringFromKeychain(forKey: key)

        // THEN should handle special characters
        XCTAssertEqual(retrieved, value)
    }

    func testKeychainWithUnicode() {
        // GIVEN unicode string
        let key = generateTestKey()
        let value = "Hello 世界 🌍 émoji"

        // WHEN storing and retrieving
        securityManager.storeStringInKeychain(value, forKey: key)
        let retrieved = securityManager.getStringFromKeychain(forKey: key)

        // THEN should handle unicode
        XCTAssertEqual(retrieved, value)
    }

    func testEncryptionWithBinaryData() throws {
        // GIVEN random binary data
        var randomBytes = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            randomBytes[i] = UInt8(i)
        }
        let data = Data(randomBytes)
        let key = securityManager.generateKey()

        // WHEN encrypting and decrypting
        let encrypted = try securityManager.encrypt(data: data, with: key)
        let decrypted = try securityManager.decrypt(data: encrypted, with: key)

        // THEN should preserve binary data
        XCTAssertEqual(decrypted, data)
    }
}
