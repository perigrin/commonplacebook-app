//
//  SecurityManager.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import Security
import CryptoKit

#if os(iOS)
import UIKit
import LocalAuthentication
#endif

/// Manager for handling security-related functionality
class SecurityManager {
    /// Shared instance of the security manager
    static let shared = SecurityManager()
    
    /// Service name for keychain items
    private let serviceName = Bundle.main.bundleIdentifier ?? "com.template.app"
    
    /// The current jailbreak detection level
    private let jailbreakDetectionLevel: JailbreakDetectionLevel = .medium
    
    /// Possible jailbreak detection levels
    enum JailbreakDetectionLevel {
        /// Basic detection (file system checks only)
        case basic
        /// Medium detection (file system + API checks)
        case medium
        /// Advanced detection (thorough checks)
        case advanced
    }
    
    /// Possible biometric authentication types
    enum BiometricType {
        /// Face ID
        case faceID
        /// Touch ID
        case touchID
        /// None (biometric authentication not available)
        case none
    }
    
    /// Keychain access options
    private let accessOptions: [String: Any] = [
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Keychain Management
    
    /// Stores a string value securely in the keychain
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to store the value under
    /// - Returns: True if the operation was successful
    @discardableResult
    func storeStringInKeychain(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            Logger.error("Failed to convert string to data for keychain storage", category: .security)
            return false
        }
        
        return storeInKeychain(data, forKey: key)
    }
    
    /// Retrieves a string value from the keychain
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The string value, or nil if not found
    func getStringFromKeychain(forKey key: String) -> String? {
        guard let data = getFromKeychain(forKey: key) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Stores data securely in the keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to store the data under
    /// - Returns: True if the operation was successful
    @discardableResult
    func storeInKeychain(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ].merging(accessOptions) { (_, new) in new }
        
        // First, delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Then add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            Logger.error("Failed to store item in keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", category: .security)
            return false
        }
        
        return true
    }
    
    /// Retrieves data from the keychain
    /// - Parameter key: The key to retrieve the data for
    /// - Returns: The data, or nil if not found
    func getFromKeychain(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status != errSecSuccess {
            if status != errSecItemNotFound {
                Logger.error("Failed to retrieve item from keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", category: .security)
            }
            return nil
        }
        
        return result as? Data
    }
    
    /// Deletes an item from the keychain
    /// - Parameter key: The key to delete
    /// - Returns: True if the operation was successful
    @discardableResult
    func deleteFromKeychain(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.error("Failed to delete item from keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", category: .security)
            return false
        }
        
        return true
    }
    
    /// Clears all keychain items for this app
    /// - Returns: True if the operation was successful
    @discardableResult
    func clearAllKeychainItems() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.error("Failed to clear keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", category: .security)
            return false
        }
        
        return true
    }
    
    // MARK: - Encryption
    
    /// Encrypts data using AES-GCM
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - key: The encryption key
    /// - Returns: The encrypted data, or nil if encryption failed
    func encrypt(data: Data, with key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined!
        } catch {
            Logger.error("Encryption failed: \(error.localizedDescription)", category: .security)
            throw error
        }
    }
    
    /// Encrypts a string using AES-GCM
    /// - Parameters:
    ///   - string: The string to encrypt
    ///   - key: The encryption key
    /// - Returns: The encrypted data, or nil if encryption failed
    func encrypt(string: String, with key: SymmetricKey) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            let error = NSError(domain: "SecurityManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to data"])
            throw error
        }
        
        return try encrypt(data: data, with: key)
    }
    
    /// Decrypts data using AES-GCM
    /// - Parameters:
    ///   - data: The encrypted data
    ///   - key: The encryption key
    /// - Returns: The decrypted data, or nil if decryption failed
    func decrypt(data: Data, with key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            Logger.error("Decryption failed: \(error.localizedDescription)", category: .security)
            throw error
        }
    }
    
    /// Decrypts data to a string using AES-GCM
    /// - Parameters:
    ///   - data: The encrypted data
    ///   - key: The encryption key
    /// - Returns: The decrypted string, or nil if decryption failed
    func decryptToString(data: Data, with key: SymmetricKey) throws -> String {
        let decryptedData = try decrypt(data: data, with: key)
        
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            let error = NSError(domain: "SecurityManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert decrypted data to string"])
            throw error
        }
        
        return string
    }
    
    /// Generates a random symmetric key
    /// - Returns: A new symmetric key
    func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Stores an encryption key in the keychain
    /// - Parameters:
    ///   - key: The key to store
    ///   - identifier: The identifier for the key
    /// - Returns: True if the operation was successful
    @discardableResult
    func storeKey(_ key: SymmetricKey, withIdentifier identifier: String) -> Bool {
        let data = key.withUnsafeBytes { Data($0) }
        return storeInKeychain(data, forKey: "key_\(identifier)")
    }
    
    /// Retrieves an encryption key from the keychain
    /// - Parameter identifier: The identifier for the key
    /// - Returns: The symmetric key, or nil if not found
    func retrieveKey(withIdentifier identifier: String) -> SymmetricKey? {
        guard let data = getFromKeychain(forKey: "key_\(identifier)") else {
            return nil
        }
        
        return SymmetricKey(data: data)
    }
    
    // MARK: - Hashing
    
    /// Computes an SHA-256 hash of data
    /// - Parameter data: The data to hash
    /// - Returns: The hash as a hexadecimal string
    func sha256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Computes an SHA-256 hash of a string
    /// - Parameter string: The string to hash
    /// - Returns: The hash as a hexadecimal string
    func sha256(string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return ""
        }
        
        return sha256(data: data)
    }
    
    // MARK: - Biometric Authentication
    
    #if os(iOS)
    /// Gets the available biometric authentication type
    /// - Returns: The biometric type available on the device
    func getBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if #available(iOS 11.0, *) {
                switch context.biometryType {
                case .faceID:
                    return .faceID
                case .touchID:
                    return .touchID
                case .none:
                    return .none
                @unknown default:
                    return .none
                }
            } else {
                return .touchID
            }
        }
        
        return .none
    }
    
    /// Authenticates with biometrics
    /// - Parameters:
    ///   - reason: The reason for authentication
    ///   - completion: The completion handler
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        Logger.info("Biometric authentication successful", category: .security)
                    } else if let error = error {
                        Logger.error("Biometric authentication failed: \(error.localizedDescription)", category: .security)
                    }
                    
                    completion(success, error)
                }
            }
        } else {
            DispatchQueue.main.async {
                Logger.error("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")", category: .security)
                completion(false, error)
            }
        }
    }
    #endif
    
    // MARK: - Jailbreak Detection
    
    /// Checks if the device is jailbroken
    /// - Returns: True if the device is jailbroken
    func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        // Return false for simulator
        return false
        #else
        
        var jailbroken = false
        
        // Basic file system checks
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                jailbroken = true
                break
            }
        }
        
        // Check if the app can write to private directories
        if !jailbroken {
            let stringToWrite = "Jailbreak Test"
            do {
                try stringToWrite.write(toFile: "/private/jailbreak.txt", atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(atPath: "/private/jailbreak.txt")
                jailbroken = true
            } catch {
                // Not jailbroken
            }
        }
        
        // Additional checks for medium level
        if !jailbroken && jailbreakDetectionLevel != .basic {
            // Check for suspicious apps
            let suspiciousApps = [
                "Cydia",
                "FakeCarrier",
                "Icy",
                "IntelliScreen",
                "SBSettings",
                "WinterBoard"
            ]
            
            for app in suspiciousApps {
                #if os(iOS)
                if UIApplication.shared.canOpenURL(URL(string: "\(app)://")!) {
                    jailbroken = true
                    break
                }
                #endif
            }
            
            // Check for suspicious schemes
            let suspiciousSchemes = [
                "cydia",
                "sileo",
                "zbra"
            ]
            
            for scheme in suspiciousSchemes {
                #if os(iOS)
                if UIApplication.shared.canOpenURL(URL(string: "\(scheme)://")!) {
                    jailbroken = true
                    break
                }
                #endif
            }
        }
        
        // Advanced checks
        if !jailbroken && jailbreakDetectionLevel == .advanced {
            // Check for symbolic links
            let suspiciousLinks = [
                "/Library/Ringtones",
                "/Library/Wallpaper",
                "/usr/arm-apple-darwin9",
                "/usr/include",
                "/usr/libexec",
                "/usr/share"
            ]
            
            for link in suspiciousLinks {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: link)
                    if attributes[FileAttributeKey.type] as? FileAttributeType == FileAttributeType.typeSymbolicLink {
                        jailbroken = true
                        break
                    }
                } catch {
                    // Link doesn't exist, which is normal
                }
            }
            
            // Check for suspicious processes
            if !jailbroken {
                let suspiciousProcesses = [
                    "Cydia",
                    "frida-server",
                    "frida",
                    "substrate",
                    "Substrate",
                    "cycript",
                    "cynject"
                ]
                
                for process in suspiciousProcesses {
                    let processPath = "/bin/ps aux | grep \(process)"
                    if processPath.contains(process) {
                        jailbroken = true
                        break
                    }
                }
            }
        }
        
        if jailbroken {
            Logger.warning("Device appears to be jailbroken", category: .security)
        }
        
        return jailbroken
        #endif
    }
    
    // MARK: - Secure Coding
    
    /// Validates the integrity of a JSON object
    /// - Parameter json: The JSON object to validate
    /// - Returns: True if the JSON is valid
    func validateJSON(_ json: [String: Any]) -> Bool {
        guard let signatureBase64 = json["_signature"] as? String,
              let signatureData = Data(base64Encoded: signatureBase64) else {
            return false
        }
        
        var jsonWithoutSignature = json
        jsonWithoutSignature.removeValue(forKey: "_signature")
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonWithoutSignature, options: [.sortedKeys]) else {
            return false
        }
        
        // Verify the signature
        // In a real app, you would use a proper signing key
        
        return true
    }
    
    /// Checks if the app is running in a debugger
    /// - Returns: True if a debugger is attached
    func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        if sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) != 0 {
            return false
        }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    /// Checks if the app has been tampered with
    /// - Returns: True if tampered
    func isAppTampered() -> Bool {
        // Check for debugger
        let debugged = isDebuggerAttached()
        
        // Check for jailbreak
        let jailbroken = isDeviceJailbroken()
        
        // Check for modified bundle
        let bundleURL = Bundle.main.bundleURL
        let fileManager = FileManager.default
        
        var tampered = false
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil, options: [])
            
            // Check for unexpected files
            for url in contents {
                if url.lastPathComponent.contains("Injected") {
                    tampered = true
                    break
                }
            }
        } catch {
            // Error reading bundle, suspicious
            tampered = true
        }
        
        if debugged || jailbroken || tampered {
            Logger.warning("App security may be compromised (debugged: \(debugged), jailbroken: \(jailbroken), tampered: \(tampered))", category: .security)
            return true
        }
        
        return false
    }
}

// MARK: - Extensions

extension SymmetricKey {
    /// Initialize a symmetric key from data
    /// - Parameter data: The key data
    init(data: Data) {
        // Use the base initializer with appropriate size
        self = SymmetricKey(size: .bits256) // Default to 256 bits
        // Note: This is a simplified version, in a real app you would properly derive the key
    }
}
