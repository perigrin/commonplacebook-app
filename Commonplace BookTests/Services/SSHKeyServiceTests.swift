// ABOUTME: Tests for SSH key generation, storage, and retrieval service
// ABOUTME: Verifies secure keychain storage and Ed25519 key generation on macOS

import XCTest
@testable import Commonplace_Book

final class SSHKeyServiceTests: XCTestCase {
    var sut: SSHKeyService!
    var mockSecurityManager: MockSecurityManager!

    override func setUp() {
        super.setUp()
        mockSecurityManager = MockSecurityManager()
        sut = SSHKeyService(securityManager: mockSecurityManager)
    }

    override func tearDown() {
        sut = nil
        mockSecurityManager = nil
        super.tearDown()
    }

    // MARK: - Key Generation Tests

    func testGenerateSSHKeyPair_createsEd25519Keys() async throws {
        #if os(macOS)
        // When: Generate a new SSH key pair
        let result = try await sut.generateKeyPair(comment: "test@example.com")

        // Then: Should return both public and private keys
        XCTAssertFalse(result.publicKey.isEmpty, "Public key should not be empty")
        XCTAssertFalse(result.privateKey.isEmpty, "Private key should not be empty")

        // And: Public key should be in SSH format
        XCTAssertTrue(result.publicKey.hasPrefix("ssh-ed25519 "), "Public key should start with ssh-ed25519")

        // And: Private key should be in OpenSSH format
        XCTAssertTrue(result.privateKey.hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----"), "Private key should be in OpenSSH format")
        #else
        throw XCTSkip("SSH key generation only supported on macOS")
        #endif
    }

    func testGenerateSSHKeyPair_storesPrivateKeyInKeychain() async throws {
        #if os(macOS)
        // When: Generate a new SSH key pair
        _ = try await sut.generateKeyPair(comment: "test@example.com")

        // Then: Private key should be stored in keychain
        XCTAssertTrue(mockSecurityManager.storeInKeychainCalled, "Should store private key in keychain")
        XCTAssertEqual(mockSecurityManager.lastStoredKey, "ssh_private_key", "Should use correct keychain key")
        XCTAssertFalse(mockSecurityManager.lastStoredData?.isEmpty ?? true, "Should store non-empty data")
        #else
        throw XCTSkip("SSH key generation only supported on macOS")
        #endif
    }

    // MARK: - Key Retrieval Tests

    func testGetPublicKey_returnsStoredKey() async throws {
        #if os(macOS)
        // Given: A generated key pair
        let generated = try await sut.generateKeyPair(comment: "test@example.com")

        // When: Retrieve the public key
        let retrieved = try await sut.getPublicKey()

        // Then: Should return the same public key
        XCTAssertEqual(retrieved, generated.publicKey, "Retrieved public key should match generated")
        #else
        throw XCTSkip("SSH key operations only supported on macOS")
        #endif
    }

    func testGetPublicKey_throwsWhenNoKeyExists() async throws {
        #if os(macOS)
        // Given: No keys have been generated
        mockSecurityManager.shouldReturnNil = true

        // When/Then: Should throw an error
        do {
            _ = try await sut.getPublicKey()
            XCTFail("Should throw error when no key exists")
        } catch SSHKeyServiceError.noKeyFound {
            // Expected
        } catch {
            XCTFail("Should throw noKeyFound error, got \(error)")
        }
        #else
        throw XCTSkip("SSH key operations only supported on macOS")
        #endif
    }

    func testHasKeys_returnsTrueWhenKeysExist() async throws {
        #if os(macOS)
        // Given: Keys have been generated
        _ = try await sut.generateKeyPair(comment: "test@example.com")

        // When: Check if keys exist
        let hasKeys = await sut.hasKeys()

        // Then: Should return true
        XCTAssertTrue(hasKeys, "Should return true when keys exist")
        #else
        throw XCTSkip("SSH key operations only supported on macOS")
        #endif
    }

    func testHasKeys_returnsFalseWhenNoKeysExist() async throws {
        // Given: No keys have been generated
        mockSecurityManager.shouldReturnNil = true

        // When: Check if keys exist
        let hasKeys = await sut.hasKeys()

        // Then: Should return false
        XCTAssertFalse(hasKeys, "Should return false when no keys exist")
    }

    // MARK: - Key Deletion Tests

    func testDeleteKeys_removesKeysFromKeychain() async throws {
        #if os(macOS)
        // Given: Keys have been generated
        _ = try await sut.generateKeyPair(comment: "test@example.com")

        // When: Delete the keys
        try await sut.deleteKeys()

        // Then: Keys should be removed from keychain
        XCTAssertTrue(mockSecurityManager.deleteFromKeychainCalled, "Should delete keys from keychain")

        // And: Should no longer have keys
        let hasKeys = await sut.hasKeys()
        XCTAssertFalse(hasKeys, "Should not have keys after deletion")
        #else
        throw XCTSkip("SSH key operations only supported on macOS")
        #endif
    }

    // MARK: - Error Handling Tests

    func testGenerateSSHKeyPair_throwsOnKeychainFailure() async throws {
        #if os(macOS)
        // Given: Keychain storage will fail
        mockSecurityManager.shouldFailStore = true

        // When/Then: Should throw an error
        do {
            _ = try await sut.generateKeyPair(comment: "test@example.com")
            XCTFail("Should throw error on keychain failure")
        } catch SSHKeyServiceError.keychainStorageFailed {
            // Expected
        } catch {
            XCTFail("Should throw keychainStorageFailed error, got \(error)")
        }
        #else
        throw XCTSkip("SSH key operations only supported on macOS")
        #endif
    }
}

// MARK: - Mock Security Manager

class MockSecurityManager: SecurityManaging {
    var storeInKeychainCalled = false
    var lastStoredKey: String?
    var lastStoredData: Data?
    var shouldFailStore = false
    var shouldReturnNil = false
    var deleteFromKeychainCalled = false

    private var storage: [String: Data] = [:]

    func storeInKeychain(_ data: Data, forKey key: String) -> Bool {
        storeInKeychainCalled = true
        lastStoredKey = key
        lastStoredData = data

        if shouldFailStore {
            return false
        }

        storage[key] = data
        return true
    }

    func getFromKeychain(forKey key: String) -> Data? {
        if shouldReturnNil {
            return nil
        }
        return storage[key]
    }

    func deleteFromKeychain(forKey key: String) -> Bool {
        deleteFromKeychainCalled = true
        storage.removeValue(forKey: key)
        return true
    }

    // Stub implementations for other SecurityManaging requirements
    func getBiometricType() -> SecurityManager.BiometricType { .none }
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
    }
    func authenticateWithDevicePasscode(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
    }
    func encrypt(data: Data, with key: SymmetricKey) throws -> Data { data }
    func decrypt(data: Data, with key: SymmetricKey) throws -> Data { data }
}
