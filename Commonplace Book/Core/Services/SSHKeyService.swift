// ABOUTME: Service for SSH key generation, storage, and management
// ABOUTME: Generates Ed25519 keys on macOS and stores private keys securely in keychain

import Foundation
import CryptoKit

/// Errors that can occur during SSH key operations
enum SSHKeyServiceError: Error, LocalizedError {
    case noKeyFound
    case keychainStorageFailed
    case keyGenerationFailed(String)
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .noKeyFound:
            return "No SSH key found. Please generate a new key pair."
        case .keychainStorageFailed:
            return "Failed to store SSH key in keychain."
        case .keyGenerationFailed(let reason):
            return "Failed to generate SSH key: \(reason)"
        case .unsupportedPlatform:
            return "SSH key generation is only supported on macOS in this version."
        }
    }
}

/// Result of SSH key pair generation
struct SSHKeyPair {
    let publicKey: String
    let privateKey: String
}

#if os(macOS)
/// Service for managing SSH keys for git authentication
actor SSHKeyService {
    private let securityManager: SecurityManaging
    private let fileManager: FileManager

    // Keychain keys
    private let privateKeyKeychainKey = "ssh_private_key"
    private let publicKeyKeychainKey = "ssh_public_key"

    init(securityManager: SecurityManaging = SecurityManager.shared, fileManager: FileManager = .default) {
        self.securityManager = securityManager
        self.fileManager = fileManager
    }

    // MARK: - Key Generation

    /// Generate a new SSH key pair using Ed25519
    /// - Parameter comment: Optional comment for the key (typically email)
    /// - Returns: The generated key pair
    /// - Throws: SSHKeyServiceError if generation fails
    func generateKeyPair(comment: String? = nil) async throws -> SSHKeyPair {
        #if os(macOS)
        return try await generateKeyPairMacOS(comment: comment)
        #else
        throw SSHKeyServiceError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    private func generateKeyPairMacOS(comment: String?) async throws -> SSHKeyPair {
        // Create a temporary directory for key generation
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let keyPath = tempDir.appendingPathComponent("id_ed25519")
        let pubKeyPath = tempDir.appendingPathComponent("id_ed25519.pub")

        // Build ssh-keygen command
        var arguments = [
            "-t", "ed25519",
            "-f", keyPath.path,
            "-N", "",  // No passphrase (handled by keychain)
            "-q"       // Quiet mode
        ]

        if let comment = comment {
            arguments.append(contentsOf: ["-C", comment])
        }

        // Execute ssh-keygen
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw SSHKeyServiceError.keyGenerationFailed(errorMessage)
            }

            // Read the generated keys
            guard let privateKeyData = try? Data(contentsOf: keyPath),
                  let privateKey = String(data: privateKeyData, encoding: .utf8),
                  let publicKeyData = try? Data(contentsOf: pubKeyPath),
                  let publicKey = String(data: publicKeyData, encoding: .utf8) else {
                throw SSHKeyServiceError.keyGenerationFailed("Failed to read generated key files")
            }

            // Store private key in keychain
            let success = securityManager.storeInKeychain(privateKeyData, forKey: privateKeyKeychainKey)
            if !success {
                throw SSHKeyServiceError.keychainStorageFailed
            }

            // Store public key in keychain (for easy retrieval)
            _ = securityManager.storeInKeychain(publicKeyData, forKey: publicKeyKeychainKey)

            Logger.info("Generated and stored SSH key pair", category: .security)

            return SSHKeyPair(
                publicKey: publicKey.trimmingCharacters(in: .whitespacesAndNewlines),
                privateKey: privateKey
            )
        } catch let error as SSHKeyServiceError {
            throw error
        } catch {
            throw SSHKeyServiceError.keyGenerationFailed(error.localizedDescription)
        }
    }
    #endif

    // MARK: - Key Retrieval

    /// Check if SSH keys exist
    /// - Returns: True if keys are stored in keychain
    func hasKeys() async -> Bool {
        return securityManager.getFromKeychain(forKey: publicKeyKeychainKey) != nil
    }

    /// Get the public key
    /// - Returns: The public key string
    /// - Throws: SSHKeyServiceError.noKeyFound if no key exists
    func getPublicKey() async throws -> String {
        guard let data = securityManager.getFromKeychain(forKey: publicKeyKeychainKey),
              let publicKey = String(data: data, encoding: .utf8) else {
            throw SSHKeyServiceError.noKeyFound
        }

        return publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get the private key
    /// - Returns: The private key string
    /// - Throws: SSHKeyServiceError.noKeyFound if no key exists
    func getPrivateKey() async throws -> String {
        guard let data = securityManager.getFromKeychain(forKey: privateKeyKeychainKey),
              let privateKey = String(data: data, encoding: .utf8) else {
            throw SSHKeyServiceError.noKeyFound
        }

        return privateKey
    }

    /// Get the SSH key fingerprint (SHA256 hash of public key)
    /// - Returns: The fingerprint string in format "SHA256:..."
    /// - Throws: SSHKeyServiceError.noKeyFound if no key exists
    func getFingerprint() async throws -> String {
        let publicKey = try await getPublicKey()

        // Extract the base64 key data (skip the "ssh-ed25519 " prefix)
        let components = publicKey.components(separatedBy: " ")
        guard components.count >= 2,
              let keyData = Data(base64Encoded: components[1]) else {
            throw SSHKeyServiceError.noKeyFound
        }

        // Compute SHA256 hash
        let hash = SHA256.hash(data: keyData)
        let hashBase64 = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")  // Remove padding

        return "SHA256:\(hashBase64)"
    }

    // MARK: - Key Deletion

    /// Delete SSH keys from keychain
    /// - Throws: Error if deletion fails
    func deleteKeys() async throws {
        securityManager.deleteFromKeychain(forKey: privateKeyKeychainKey)
        securityManager.deleteFromKeychain(forKey: publicKeyKeychainKey)

        Logger.info("Deleted SSH key pair from keychain", category: .security)
    }

    // MARK: - Key Export

    /// Write the private key to a file (for use with git commands)
    /// - Returns: URL of the temporary key file
    /// - Throws: SSHKeyServiceError if no key exists or file write fails
    func writePrivateKeyToTempFile() async throws -> URL {
        let privateKey = try await getPrivateKey()

        // Create a temporary file
        let tempDir = fileManager.temporaryDirectory
        let keyFile = tempDir.appendingPathComponent("commonplace_ssh_key_\(UUID().uuidString)")

        guard let keyData = privateKey.data(using: .utf8) else {
            throw SSHKeyServiceError.noKeyFound
        }

        try keyData.write(to: keyFile, options: .atomic)

        // Set restrictive permissions (600 - owner read/write only)
        #if os(macOS)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFile.path)
        #endif

        return keyFile
    }
}
#endif // os(macOS)
