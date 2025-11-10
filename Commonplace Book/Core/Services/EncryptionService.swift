// ABOUTME: Database encryption service managing symmetric keys and data encryption
// ABOUTME: Handles key generation, storage, rotation, and transparent database encryption

import Foundation
import CryptoKit
import Combine

/// Service managing encryption keys and database encryption
@MainActor
class EncryptionService: ObservableObject {

    // MARK: - Properties

    /// Whether encryption is currently enabled
    @Published private(set) var isEncryptionEnabled: Bool

    /// Current encryption key (cached in memory when encryption is enabled)
    private var cachedKey: SymmetricKey?

    // MARK: - Dependencies

    private let securityManager: SecurityManaging
    private let userDefaults: UserDefaults

    // MARK: - Constants

    private let encryptionKeyIdentifier = "com.commonplacebook.database.encryption.key"
    private let encryptionEnabledKey = "databaseEncryptionEnabled"

    // MARK: - Initialization

    init(securityManager: SecurityManaging = SecurityManager.shared, userDefaults: UserDefaults = .standard) {
        self.securityManager = securityManager
        self.userDefaults = userDefaults
        self.isEncryptionEnabled = userDefaults.bool(forKey: encryptionEnabledKey)

        // Load cached key if encryption is enabled
        if isEncryptionEnabled {
            if let keyData = securityManager.getFromKeychain(forKey: encryptionKeyIdentifier) {
                self.cachedKey = SymmetricKey(data: keyData)
            }
        }
    }

    // MARK: - Key Generation

    /// Generate a new 256-bit AES encryption key
    /// - Returns: A new symmetric key
    func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }

    // MARK: - Key Storage

    /// Store an encryption key in the keychain
    /// - Parameter key: The key to store
    /// - Returns: True if storage was successful
    func storeKey(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        let success = securityManager.storeInKeychain(keyData, forKey: encryptionKeyIdentifier)

        if success {
            cachedKey = key
        }

        return success
    }

    /// Load the encryption key from the keychain
    /// - Returns: The stored key, or nil if not found
    func loadKey() -> SymmetricKey? {
        // Return cached key if available
        if let cached = cachedKey {
            return cached
        }

        // Load from keychain
        guard let keyData = securityManager.getFromKeychain(forKey: encryptionKeyIdentifier) else {
            return nil
        }

        let key = SymmetricKey(data: keyData)
        cachedKey = key
        return key
    }

    /// Get the current encryption key (if encryption is enabled)
    /// - Returns: The current key, or nil if encryption is disabled
    func getCurrentKey() -> SymmetricKey? {
        guard isEncryptionEnabled else { return nil }
        return loadKey()
    }

    // MARK: - Encryption/Decryption

    /// Encrypt data using AES-256-GCM
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - key: The encryption key
    /// - Returns: The encrypted data
    func encrypt(data: Data, with key: SymmetricKey) throws -> Data {
        return try securityManager.encrypt(data: data, with: key)
    }

    /// Decrypt data using AES-256-GCM
    /// - Parameters:
    ///   - data: The encrypted data
    ///   - key: The decryption key
    /// - Returns: The decrypted data
    func decrypt(data: Data, with key: SymmetricKey) throws -> Data {
        return try securityManager.decrypt(data: data, with: key)
    }

    // MARK: - Encryption Management

    /// Enable database encryption
    /// - Returns: True if encryption was enabled successfully
    func enableEncryption() -> Bool {
        guard !isEncryptionEnabled else {
            // Already enabled
            return true
        }

        // Generate and store new key
        let key = generateKey()
        guard storeKey(key) else {
            return false
        }

        // Update settings
        isEncryptionEnabled = true
        userDefaults.set(true, forKey: encryptionEnabledKey)

        Logger.info("Database encryption enabled", category: .security)
        return true
    }

    /// Disable database encryption
    /// WARNING: This will remove the encryption key. Ensure database is decrypted first.
    func disableEncryption() {
        // Clear cached key securely
        clearCachedKey()

        // Remove key from keychain
        securityManager.deleteFromKeychain(forKey: encryptionKeyIdentifier)

        // Update settings
        isEncryptionEnabled = false
        userDefaults.set(false, forKey: encryptionEnabledKey)

        Logger.info("Database encryption disabled", category: .security)
    }

    /// Clear cached encryption key from memory (security best practice)
    /// Call this when app enters background or when key is no longer needed
    func clearCachedKey() {
        if cachedKey != nil {
            // Clear the reference to allow deallocation
            cachedKey = nil
            Logger.debug("Cleared cached encryption key from memory", category: .security)
        }
    }

    /// Restore cached key from keychain (after clearing)
    /// - Returns: True if key was successfully restored
    func restoreCachedKey() -> Bool {
        guard isEncryptionEnabled else { return false }

        guard let keyData = securityManager.getFromKeychain(forKey: encryptionKeyIdentifier) else {
            Logger.error("Failed to restore cached key: key not found in keychain", category: .security)
            return false
        }

        cachedKey = SymmetricKey(data: keyData)
        Logger.debug("Restored cached encryption key from keychain", category: .security)
        return true
    }

    // MARK: - Key Rotation

    /// Rotate the encryption key
    /// WARNING: This requires re-encrypting all data with the new key
    /// - Returns: True if rotation was successful
    func rotateKey() -> Bool {
        guard isEncryptionEnabled else {
            Logger.warning("Cannot rotate key when encryption is disabled", category: .security)
            return false
        }

        // Generate new key
        let newKey = generateKey()

        // Store new key
        guard storeKey(newKey) else {
            Logger.error("Failed to store new encryption key during rotation", category: .security)
            return false
        }

        Logger.info("Encryption key rotated successfully", category: .security)
        return true
    }
}
