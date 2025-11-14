// ABOUTME: Service for integrating with Working Copy app via x-callback-url protocol
// ABOUTME: Handles git operations on iOS by delegating to Working Copy app

import Foundation

#if os(iOS)
import UIKit

/// Errors that can occur during Working Copy integration
enum WorkingCopyServiceError: Error, LocalizedError {
    case notInstalled
    case invalidURL
    case operationFailed(String)
    case callbackTimeout
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Working Copy app is not installed. Please install it from the App Store."
        case .invalidURL:
            return "Failed to generate valid Working Copy URL"
        case .operationFailed(let message):
            return "Working Copy operation failed: \(message)"
        case .callbackTimeout:
            return "Working Copy operation timed out"
        case .userCancelled:
            return "Operation cancelled by user"
        }
    }
}

/// Service for integrating with Working Copy app via x-callback-url
actor WorkingCopyService {
    private static let workingCopyScheme = "working-copy"
    private static let appCallbackScheme = "commonplacebook"
    private static let callbackTimeout: TimeInterval = 30.0

    // Callback continuation storage
    private var pendingCallbacks: [String: CheckedContinuation<String?, Error>] = [:]

    // MARK: - Working Copy Detection

    /// Check if Working Copy is installed
    /// - Returns: True if Working Copy can be opened
    func isWorkingCopyInstalled() async -> Bool {
        guard let url = URL(string: "\(Self.workingCopyScheme)://") else {
            return false
        }

        return await MainActor.run {
            UIApplication.shared.canOpenURL(url)
        }
    }

    // MARK: - Git Operations

    /// Commit changes via Working Copy
    /// - Parameters:
    ///   - repository: Repository name
    ///   - message: Commit message
    ///   - files: Optional list of specific files to commit (empty = all changes)
    /// - Throws: WorkingCopyServiceError if operation fails
    func commit(repository: String, message: String, files: [String] = []) async throws {
        guard await isWorkingCopyInstalled() else {
            throw WorkingCopyServiceError.notInstalled
        }

        guard let url = await generateCommitURL(repository: repository, message: message, files: files) else {
            throw WorkingCopyServiceError.invalidURL
        }

        try await openURLWithCallback(url, operation: "commit")
    }

    /// Push to remote via Working Copy
    /// - Parameter repository: Repository name
    /// - Throws: WorkingCopyServiceError if operation fails
    func push(repository: String) async throws {
        guard await isWorkingCopyInstalled() else {
            throw WorkingCopyServiceError.notInstalled
        }

        guard let url = await generatePushURL(repository: repository) else {
            throw WorkingCopyServiceError.invalidURL
        }

        try await openURLWithCallback(url, operation: "push")
    }

    /// Pull from remote via Working Copy
    /// - Parameter repository: Repository name
    /// - Throws: WorkingCopyServiceError if operation fails
    func pull(repository: String) async throws {
        guard await isWorkingCopyInstalled() else {
            throw WorkingCopyServiceError.notInstalled
        }

        guard let url = await generatePullURL(repository: repository) else {
            throw WorkingCopyServiceError.invalidURL
        }

        try await openURLWithCallback(url, operation: "pull")
    }

    /// Get repository status via Working Copy
    /// - Parameter repository: Repository name
    /// - Returns: Git status information
    /// - Throws: WorkingCopyServiceError if operation fails
    func status(repository: String) async throws -> GitStatus {
        guard await isWorkingCopyInstalled() else {
            throw WorkingCopyServiceError.notInstalled
        }

        guard let url = await generateStatusURL(repository: repository) else {
            throw WorkingCopyServiceError.invalidURL
        }

        // Note: Working Copy's status endpoint returns JSON in the callback
        let result = try await openURLWithCallback(url, operation: "status")

        // Parse status from result (Working Copy returns status as query parameter)
        // For now, return a basic status indicating we need to check
        return GitStatus(
            clean: result?.contains("clean=true") ?? false,
            hasStagedChanges: result?.contains("staged=true") ?? false,
            hasUnstagedChanges: result?.contains("modified=true") ?? false,
            hasUntrackedFiles: result?.contains("untracked=true") ?? false,
            modifiedFiles: [],
            untrackedFiles: []
        )
    }

    /// Open repository in Working Copy
    /// - Parameter repository: Repository name
    /// - Throws: WorkingCopyServiceError if operation fails
    func openRepository(repository: String) async throws {
        guard await isWorkingCopyInstalled() else {
            throw WorkingCopyServiceError.notInstalled
        }

        guard let url = await generateOpenRepositoryURL(repository: repository) else {
            throw WorkingCopyServiceError.invalidURL
        }

        await MainActor.run {
            UIApplication.shared.open(url)
        }
    }

    /// Clone repository via Working Copy
    /// - Parameters:
    ///   - url: Git repository URL
    ///   - to: Local repository name
    /// - Throws: WorkingCopyServiceError if operation fails
    func clone(url: String, to repository: String) async throws {
        guard await isWorkingCopyInstalled() else {
            throw WorkingCopyServiceError.notInstalled
        }

        guard let wcURL = await generateCloneURL(remoteURL: url, repository: repository) else {
            throw WorkingCopyServiceError.invalidURL
        }

        try await openURLWithCallback(wcURL, operation: "clone")
    }

    // MARK: - URL Generation

    /// Generate commit URL for Working Copy
    func generateCommitURL(repository: String, message: String, files: [String]) async -> URL? {
        var components = URLComponents()
        components.scheme = Self.workingCopyScheme
        components.host = "x-callback-url"
        components.path = "/commit"

        var queryItems = [
            URLQueryItem(name: "repo", value: repository),
            URLQueryItem(name: "message", value: message),
            URLQueryItem(name: "x-success", value: "\(Self.appCallbackScheme)://git-success"),
            URLQueryItem(name: "x-error", value: "\(Self.appCallbackScheme)://git-error")
        ]

        // Add specific files if provided
        if !files.isEmpty {
            // Working Copy expects files as separate query items or JSON
            queryItems.append(URLQueryItem(name: "path", value: files.joined(separator: ",")))
        }

        components.queryItems = queryItems
        return components.url
    }

    /// Generate push URL for Working Copy
    func generatePushURL(repository: String) async -> URL? {
        var components = URLComponents()
        components.scheme = Self.workingCopyScheme
        components.host = "x-callback-url"
        components.path = "/push"

        components.queryItems = [
            URLQueryItem(name: "repo", value: repository),
            URLQueryItem(name: "x-success", value: "\(Self.appCallbackScheme)://git-success"),
            URLQueryItem(name: "x-error", value: "\(Self.appCallbackScheme)://git-error")
        ]

        return components.url
    }

    /// Generate pull URL for Working Copy
    func generatePullURL(repository: String) async -> URL? {
        var components = URLComponents()
        components.scheme = Self.workingCopyScheme
        components.host = "x-callback-url"
        components.path = "/pull"

        components.queryItems = [
            URLQueryItem(name: "repo", value: repository),
            URLQueryItem(name: "x-success", value: "\(Self.appCallbackScheme)://git-success"),
            URLQueryItem(name: "x-error", value: "\(Self.appCallbackScheme)://git-error")
        ]

        return components.url
    }

    /// Generate status URL for Working Copy
    func generateStatusURL(repository: String) async -> URL? {
        var components = URLComponents()
        components.scheme = Self.workingCopyScheme
        components.host = "x-callback-url"
        components.path = "/status"

        components.queryItems = [
            URLQueryItem(name: "repo", value: repository),
            URLQueryItem(name: "x-success", value: "\(Self.appCallbackScheme)://git-success"),
            URLQueryItem(name: "x-error", value: "\(Self.appCallbackScheme)://git-error")
        ]

        return components.url
    }

    /// Generate open repository URL for Working Copy
    func generateOpenRepositoryURL(repository: String) async -> URL? {
        var components = URLComponents()
        components.scheme = Self.workingCopyScheme
        components.host = "x-callback-url"
        components.path = "/open"

        components.queryItems = [
            URLQueryItem(name: "repo", value: repository)
        ]

        return components.url
    }

    /// Generate clone URL for Working Copy
    func generateCloneURL(remoteURL: String, repository: String) async -> URL? {
        var components = URLComponents()
        components.scheme = Self.workingCopyScheme
        components.host = "x-callback-url"
        components.path = "/clone"

        components.queryItems = [
            URLQueryItem(name: "remote", value: remoteURL),
            URLQueryItem(name: "repo", value: repository),
            URLQueryItem(name: "x-success", value: "\(Self.appCallbackScheme)://git-success"),
            URLQueryItem(name: "x-error", value: "\(Self.appCallbackScheme)://git-error")
        ]

        return components.url
    }

    // MARK: - Callback Handling

    /// Open URL with Working Copy and wait for callback
    /// - Parameters:
    ///   - url: URL to open
    ///   - operation: Operation name for logging
    /// - Returns: Callback result data
    /// - Throws: WorkingCopyServiceError if operation fails or times out
    @discardableResult
    private func openURLWithCallback(_ url: URL, operation: String) async throws -> String? {
        let callbackID = UUID().uuidString

        // Create continuation for callback
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                // Store continuation
                await storeContinuation(continuation, for: callbackID)

                // Open URL
                await MainActor.run {
                    UIApplication.shared.open(url) { success in
                        if !success {
                            Task {
                                await self.handleCallback(
                                    callbackID: callbackID,
                                    success: false,
                                    error: "Failed to open Working Copy"
                                )
                            }
                        }
                    }
                }

                // Set timeout
                try? await Task.sleep(nanoseconds: UInt64(Self.callbackTimeout * 1_000_000_000))
                await handleCallbackTimeout(callbackID: callbackID)
            }
        }
    }

    /// Store continuation for callback
    private func storeContinuation(_ continuation: CheckedContinuation<String?, Error>, for callbackID: String) {
        pendingCallbacks[callbackID] = continuation
    }

    /// Handle callback from Working Copy
    /// - Parameters:
    ///   - callbackID: Callback identifier
    ///   - success: Whether operation succeeded
    ///   - error: Error message if failed
    ///   - data: Optional result data
    func handleCallback(callbackID: String, success: Bool, error: String? = nil, data: String? = nil) {
        guard let continuation = pendingCallbacks.removeValue(forKey: callbackID) else {
            return
        }

        if success {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: WorkingCopyServiceError.operationFailed(error ?? "Unknown error"))
        }
    }

    /// Handle callback timeout
    private func handleCallbackTimeout(callbackID: String) {
        guard let continuation = pendingCallbacks.removeValue(forKey: callbackID) else {
            return
        }

        continuation.resume(throwing: WorkingCopyServiceError.callbackTimeout)
    }

    /// Handle incoming URL callback from Working Copy
    /// - Parameter url: Callback URL from Working Copy
    /// - Returns: True if callback was handled
    func handleIncomingURL(_ url: URL) -> Bool {
        guard url.scheme == Self.appCallbackScheme else {
            return false
        }

        let path = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Extract data from query parameters
        var data: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                data[item.name] = value
            }
        }

        // Determine success/failure and handle callback
        // For now, we use a simple approach: check if there's an error parameter
        let success = path.contains("success")
        let error = data["error"] ?? data["errorMessage"]
        let resultData = data["result"] ?? data["status"]

        // Find the most recent callback (simple approach - in production, use proper ID matching)
        if let callbackID = pendingCallbacks.keys.first {
            Task {
                await handleCallback(callbackID: callbackID, success: success, error: error, data: resultData)
            }
        }

        return true
    }
}
#endif
