// ABOUTME: Protocol defining security management operations for dependency injection
// ABOUTME: Enables mocking of SecurityManager for unit testing

import Foundation
import CryptoKit

/// Protocol for security management operations
protocol SecurityManaging {
    /// Gets the available biometric authentication type
    func getBiometricType() -> SecurityManager.BiometricType

    /// Authenticates with biometrics
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void)

    /// Authenticates with device passcode (fallback method)
    func authenticateWithDevicePasscode(reason: String, completion: @escaping (Bool, Error?) -> Void)

    /// Stores data securely in the keychain
    func storeInKeychain(_ data: Data, forKey key: String) -> Bool

    /// Retrieves data from the keychain
    func getFromKeychain(forKey key: String) -> Data?

    /// Deletes data from the keychain
    func deleteFromKeychain(forKey key: String)

    /// Encrypts data using AES-GCM
    func encrypt(data: Data, with key: SymmetricKey) throws -> Data

    /// Decrypts data using AES-GCM
    func decrypt(data: Data, with key: SymmetricKey) throws -> Data
}

/// Make SecurityManager conform to the protocol
extension SecurityManager: SecurityManaging {}
