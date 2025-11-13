// ABOUTME: Service for Git repository operations using shell commands
// ABOUTME: Provides init, clone, commit, push, pull, merge, and status operations for macOS

import Foundation

/// Errors that can occur during git operations
enum GitServiceError: Error, LocalizedError {
    case commandFailed(command: String, output: String)
    case notARepository
    case noSSHKey
    case invalidPath
    case mergeConflict(files: [String])
    case authenticationFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let output):
            return "Git command failed: \(command)\n\(output)"
        case .notARepository:
            return "Not a git repository"
        case .noSSHKey:
            return "No SSH key configured. Please generate an SSH key first."
        case .invalidPath:
            return "Invalid repository path"
        case .mergeConflict(let files):
            return "Merge conflict in files: \(files.joined(separator: ", "))"
        case .authenticationFailed:
            return "Git authentication failed. Please check your SSH key."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

/// Git commit information
struct GitCommit {
    let hash: String
    let author: String
    let date: Date
    let message: String
}

/// Git repository status
struct GitStatus {
    let clean: Bool
    let hasStagedChanges: Bool
    let hasUnstagedChanges: Bool
    let hasUntrackedFiles: Bool
    let modifiedFiles: [String]
    let untrackedFiles: [String]
}

/// Service for git repository operations
actor GitService {
    private let sshKeyService: SSHKeyService
    private let fileManager: FileManager

    init(sshKeyService: SSHKeyService = SSHKeyService(), fileManager: FileManager = .default) {
        self.sshKeyService = sshKeyService
        self.fileManager = fileManager
    }

    // MARK: - Repository Operations

    /// Initialize a new git repository
    /// - Parameters:
    ///   - path: Path where to create the repository
    ///   - userName: Optional git user name
    ///   - userEmail: Optional git user email
    /// - Throws: GitServiceError if initialization fails
    func initRepository(at path: URL, userName: String? = nil, userEmail: String? = nil) async throws {
        #if os(macOS)
        guard fileManager.fileExists(atPath: path.path) else {
            throw GitServiceError.invalidPath
        }

        // Initialize repository
        _ = try await runGitCommand(["init"], in: path)

        // Configure user if provided
        if let userName = userName {
            try await setConfig(key: "user.name", value: userName, in: path)
        }

        if let userEmail = userEmail {
            try await setConfig(key: "user.email", value: userEmail, in: path)
        }

        // Set default branch name to main
        try await runGitCommand(["config", "init.defaultBranch", "main"], in: path)

        Logger.info("Initialized git repository at \(path.path)", category: .git)
        #else
        throw GitServiceError.commandFailed(command: "init", output: "Git operations only supported on macOS")
        #endif
    }

    /// Check if a directory is a git repository
    /// - Parameter path: Path to check
    /// - Returns: True if it's a git repository
    func isGitRepository(at path: URL) async -> Bool {
        let gitDir = path.appendingPathComponent(".git")
        return fileManager.fileExists(atPath: gitDir.path)
    }

    /// Clone a remote repository
    /// - Parameters:
    ///   - url: Git repository URL (SSH format)
    ///   - destination: Local path for the clone
    /// - Throws: GitServiceError if clone fails
    func clone(url: String, to destination: URL) async throws {
        #if os(macOS)
        guard await sshKeyService.hasKeys() else {
            throw GitServiceError.noSSHKey
        }

        let keyFile = try await sshKeyService.writePrivateKeyToTempFile()
        defer {
            try? fileManager.removeItem(at: keyFile)
        }

        // Set up SSH command with identity file
        let sshCommand = "ssh -i \(keyFile.path) -o StrictHostKeyChecking=accept-new"

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_SSH_COMMAND"] = sshCommand

        _ = try await runGitCommand(
            ["clone", url, destination.path],
            in: fileManager.temporaryDirectory,
            environment: environment
        )

        Logger.info("Cloned repository from \(url) to \(destination.path)", category: .git)
        #else
        throw GitServiceError.commandFailed(command: "clone", output: "Git operations only supported on macOS")
        #endif
    }

    // MARK: - Working Directory Operations

    /// Add files to the staging area
    /// - Parameters:
    ///   - files: Files to add (relative paths or "." for all)
    ///   - path: Repository path
    /// - Throws: GitServiceError if add fails
    func add(files: [String], in path: URL) async throws {
        #if os(macOS)
        _ = try await runGitCommand(["add"] + files, in: path)
        Logger.debug("Added files to staging: \(files.joined(separator: ", "))", category: .git)
        #else
        throw GitServiceError.commandFailed(command: "add", output: "Git operations only supported on macOS")
        #endif
    }

    /// Commit staged changes
    /// - Parameters:
    ///   - message: Commit message
    ///   - path: Repository path
    /// - Returns: Commit hash
    /// - Throws: GitServiceError if commit fails
    @discardableResult
    func commit(message: String, in path: URL) async throws -> String {
        #if os(macOS)
        let output = try await runGitCommand(["commit", "-m", message], in: path)

        // Extract commit hash from output
        // Output format: "[main abc1234] Commit message"
        if let hashRange = output.range(of: #"\[[^\]]+\s+([a-f0-9]+)\]"#, options: .regularExpression),
           let hashMatch = output[hashRange].split(separator: " ").last {
            let hash = String(hashMatch).replacingOccurrences(of: "]", with: "")
            Logger.info("Created commit \(hash): \(message)", category: .git)
            return hash
        }

        // If we can't parse, get the hash from HEAD
        return try await runGitCommand(["rev-parse", "HEAD"], in: path).trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw GitServiceError.commandFailed(command: "commit", output: "Git operations only supported on macOS")
        #endif
    }

    /// Get repository status
    /// - Parameter path: Repository path
    /// - Returns: Repository status
    /// - Throws: GitServiceError if status check fails
    func status(in path: URL) async throws -> GitStatus {
        #if os(macOS)
        let output = try await runGitCommand(["status", "--porcelain"], in: path)

        var modifiedFiles: [String] = []
        var untrackedFiles: [String] = []
        var hasStagedChanges = false
        var hasUnstagedChanges = false

        for line in output.components(separatedBy: .newlines) where !line.isEmpty {
            let status = String(line.prefix(2))
            let file = String(line.dropFirst(3))

            if status.hasPrefix("M") || status.hasPrefix("A") || status.hasPrefix("D") {
                hasStagedChanges = true
            }

            if status.hasSuffix("M") || status.hasSuffix("D") {
                hasUnstagedChanges = true
                modifiedFiles.append(file)
            }

            if status.hasPrefix("?") {
                untrackedFiles.append(file)
            }
        }

        return GitStatus(
            clean: output.isEmpty,
            hasStagedChanges: hasStagedChanges,
            hasUnstagedChanges: hasUnstagedChanges,
            hasUntrackedFiles: !untrackedFiles.isEmpty,
            modifiedFiles: modifiedFiles,
            untrackedFiles: untrackedFiles
        )
        #else
        throw GitServiceError.commandFailed(command: "status", output: "Git operations only supported on macOS")
        #endif
    }

    // MARK: - Remote Operations

    /// Add a remote repository
    /// - Parameters:
    ///   - name: Remote name (typically "origin")
    ///   - url: Remote URL
    ///   - path: Repository path
    /// - Throws: GitServiceError if adding remote fails
    func addRemote(name: String, url: String, in path: URL) async throws {
        #if os(macOS)
        _ = try await runGitCommand(["remote", "add", name, url], in: path)
        Logger.info("Added remote '\(name)': \(url)", category: .git)
        #else
        throw GitServiceError.commandFailed(command: "remote add", output: "Git operations only supported on macOS")
        #endif
    }

    /// Push to remote repository
    /// - Parameters:
    ///   - remote: Remote name (default: "origin")
    ///   - branch: Branch name (default: current branch)
    ///   - path: Repository path
    ///   - setUpstream: Whether to set upstream tracking
    /// - Throws: GitServiceError if push fails
    func push(remote: String = "origin", branch: String? = nil, setUpstream: Bool = false, in path: URL) async throws {
        #if os(macOS)
        guard await sshKeyService.hasKeys() else {
            throw GitServiceError.noSSHKey
        }

        let keyFile = try await sshKeyService.writePrivateKeyToTempFile()
        defer {
            try? fileManager.removeItem(at: keyFile)
        }

        let sshCommand = "ssh -i \(keyFile.path) -o StrictHostKeyChecking=accept-new"

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_SSH_COMMAND"] = sshCommand

        let branchName = branch ?? try await getCurrentBranch(in: path)

        var arguments = ["push"]
        if setUpstream {
            arguments.append(contentsOf: ["-u", remote, branchName])
        } else {
            arguments.append(contentsOf: [remote, branchName])
        }

        _ = try await runGitCommand(arguments, in: path, environment: environment)
        Logger.info("Pushed to \(remote)/\(branchName)", category: .git)
        #else
        throw GitServiceError.commandFailed(command: "push", output: "Git operations only supported on macOS")
        #endif
    }

    /// Pull from remote repository
    /// - Parameters:
    ///   - remote: Remote name (default: "origin")
    ///   - branch: Branch name (default: current branch)
    ///   - path: Repository path
    /// - Throws: GitServiceError if pull fails
    func pull(remote: String = "origin", branch: String? = nil, in path: URL) async throws {
        #if os(macOS)
        guard await sshKeyService.hasKeys() else {
            throw GitServiceError.noSSHKey
        }

        let keyFile = try await sshKeyService.writePrivateKeyToTempFile()
        defer {
            try? fileManager.removeItem(at: keyFile)
        }

        let sshCommand = "ssh -i \(keyFile.path) -o StrictHostKeyChecking=accept-new"

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_SSH_COMMAND"] = sshCommand

        let branchName = branch ?? try await getCurrentBranch(in: path)

        _ = try await runGitCommand(["pull", remote, branchName], in: path, environment: environment)
        Logger.info("Pulled from \(remote)/\(branchName)", category: .git)
        #else
        throw GitServiceError.commandFailed(command: "pull", output: "Git operations only supported on macOS")
        #endif
    }

    /// Fetch from remote repository
    /// - Parameters:
    ///   - remote: Remote name (default: "origin")
    ///   - path: Repository path
    /// - Throws: GitServiceError if fetch fails
    func fetch(remote: String = "origin", in path: URL) async throws {
        #if os(macOS)
        guard await sshKeyService.hasKeys() else {
            throw GitServiceError.noSSHKey
        }

        let keyFile = try await sshKeyService.writePrivateKeyToTempFile()
        defer {
            try? fileManager.removeItem(at: keyFile)
        }

        let sshCommand = "ssh -i \(keyFile.path) -o StrictHostKeyChecking=accept-new"

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_SSH_COMMAND"] = sshCommand

        _ = try await runGitCommand(["fetch", remote], in: path, environment: environment)
        Logger.info("Fetched from \(remote)", category: .git)
        #else
        throw GitServiceError.commandFailed(command: "fetch", output: "Git operations only supported on macOS")
        #endif
    }

    // MARK: - Branch Operations

    /// Get current branch name
    /// - Parameter path: Repository path
    /// - Returns: Current branch name
    /// - Throws: GitServiceError if getting branch fails
    func getCurrentBranch(in path: URL) async throws -> String {
        #if os(macOS)
        let output = try await runGitCommand(["branch", "--show-current"], in: path)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw GitServiceError.commandFailed(command: "branch", output: "Git operations only supported on macOS")
        #endif
    }

    // MARK: - Log Operations

    /// Get commit log
    /// - Parameters:
    ///   - limit: Maximum number of commits to return
    ///   - path: Repository path
    /// - Returns: Array of commits
    /// - Throws: GitServiceError if getting log fails
    func log(limit: Int = 10, in path: URL) async throws -> [GitCommit] {
        #if os(macOS)
        let format = "%H%n%an%n%at%n%s%n---END---"
        let output = try await runGitCommand(["log", "-\(limit)", "--format=\(format)"], in: path)

        var commits: [GitCommit] = []
        let commitStrings = output.components(separatedBy: "---END---\n")

        for commitString in commitStrings where !commitString.isEmpty {
            let lines = commitString.components(separatedBy: "\n")
            guard lines.count >= 4 else { continue }

            let hash = lines[0]
            let author = lines[1]
            let timestamp = TimeInterval(lines[2]) ?? 0
            let message = lines[3]

            commits.append(GitCommit(
                hash: hash,
                author: author,
                date: Date(timeIntervalSince1970: timestamp),
                message: message
            ))
        }

        return commits
        #else
        throw GitServiceError.commandFailed(command: "log", output: "Git operations only supported on macOS")
        #endif
    }

    // MARK: - Configuration

    /// Set a git configuration value
    /// - Parameters:
    ///   - key: Configuration key
    ///   - value: Configuration value
    ///   - path: Repository path
    /// - Throws: GitServiceError if setting config fails
    func setConfig(key: String, value: String, in path: URL) async throws {
        #if os(macOS)
        _ = try await runGitCommand(["config", key, value], in: path)
        #else
        throw GitServiceError.commandFailed(command: "config", output: "Git operations only supported on macOS")
        #endif
    }

    /// Get a git configuration value
    /// - Parameters:
    ///   - key: Configuration key
    ///   - path: Repository path
    /// - Returns: Configuration value
    /// - Throws: GitServiceError if getting config fails
    func getConfig(key: String, in path: URL) async throws -> String {
        #if os(macOS)
        let output = try await runGitCommand(["config", key], in: path)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw GitServiceError.commandFailed(command: "config", output: "Git operations only supported on macOS")
        #endif
    }

    // MARK: - Helper Methods

    private func runGitCommand(
        _ arguments: [String],
        in workingDirectory: URL,
        environment: [String: String]? = nil
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        if let environment = environment {
            process.environment = environment
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                let command = arguments.joined(separator: " ")
                Logger.error("Git command failed: \(command)\n\(error)", category: .git)
                throw GitServiceError.commandFailed(command: command, output: error)
            }

            return output
        } catch let error as GitServiceError {
            throw error
        } catch {
            let command = arguments.joined(separator: " ")
            throw GitServiceError.commandFailed(command: command, output: error.localizedDescription)
        }
    }
}
