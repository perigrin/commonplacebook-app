// ABOUTME: Service for automatic git synchronization in the background
// ABOUTME: Handles auto-commit, opportunistic push, periodic pull, and conflict resolution

import Foundation

/// Configuration for git synchronization
struct GitSyncConfiguration {
    /// Whether automatic synchronization is enabled
    var enabled: Bool = true

    /// Whether to automatically commit after note changes
    var autoCommit: Bool = true

    /// Whether to automatically push to remote
    var autoPush: Bool = true

    /// Whether to automatically pull from remote
    var autoPull: Bool = true

    /// Interval between pull attempts (in seconds)
    var pullInterval: TimeInterval = 300 // 5 minutes

    /// User name for git commits
    var userName: String?

    /// User email for git commits
    var userEmail: String?

    /// Remote repository URL
    var remoteURL: String?

    /// Remote name (typically "origin")
    var remoteName: String = "origin"
}

/// Events that can occur during synchronization
enum GitSyncEvent {
    case commitCreated(hash: String, message: String)
    case pushStarted
    case pushCompleted
    case pushFailed(Error)
    case pullStarted
    case pullCompleted
    case pullFailed(Error)
    case conflictDetected(files: [String])
    case syncDisabled
}

#if os(macOS)
/// Service for automatic git synchronization
actor GitSyncService {
    private let gitService: GitService
    private let repositoryPath: URL
    private var configuration: GitSyncConfiguration
    private var pullTimer: Task<Void, Never>?
    private var eventHandler: ((GitSyncEvent) -> Void)?

    init(
        gitService: GitService = GitService(),
        repositoryPath: URL,
        configuration: GitSyncConfiguration = GitSyncConfiguration()
    ) {
        self.gitService = gitService
        self.repositoryPath = repositoryPath
        self.configuration = configuration
    }

    // MARK: - Configuration

    /// Update the synchronization configuration
    /// - Parameter configuration: New configuration
    func updateConfiguration(_ configuration: GitSyncConfiguration) {
        self.configuration = configuration

        // Restart pull timer if interval changed
        if configuration.enabled && configuration.autoPull {
            startPullTimer()
        } else {
            stopPullTimer()
        }
    }

    /// Get the current configuration
    /// - Returns: Current configuration
    func getConfiguration() -> GitSyncConfiguration {
        return configuration
    }

    /// Set the event handler for synchronization events
    /// - Parameter handler: Event handler closure
    func setEventHandler(_ handler: @escaping (GitSyncEvent) -> Void) {
        self.eventHandler = handler
    }

    // MARK: - Note Operations

    /// Commit a note change
    /// - Parameters:
    ///   - noteID: ID of the note
    ///   - action: Action performed (add, update, delete)
    ///   - title: Title of the note
    func commitNoteChange(noteID: UUID, action: NoteAction, title: String) async {
        guard configuration.enabled && configuration.autoCommit else {
            return
        }

        #if os(macOS)
        do {
            // Check if repository is initialized
            guard await gitService.isGitRepository(at: repositoryPath) else {
                Logger.warning("Repository not initialized, skipping commit", category: .git)
                return
            }

            // Construct commit message
            let message = action.commitMessage(for: title)

            // Add the note file
            let noteFile = "\(noteID.uuidString).md"
            try await gitService.add(files: [noteFile], in: repositoryPath)

            // Commit
            let hash = try await gitService.commit(message: message, in: repositoryPath)

            Logger.info("Committed note change: \(message) [\(hash)]", category: .git)
            eventHandler?(.commitCreated(hash: hash, message: message))

            // Trigger push if enabled
            if configuration.autoPush {
                Task.detached(priority: .background) { [weak self] in
                    await self?.pushInBackground()
                }
            }

        } catch {
            Logger.error("Failed to commit note change: \(error.localizedDescription)", category: .git)
        }
        #endif
    }

    /// Commit multiple note changes (batch)
    /// - Parameter changes: Array of note changes
    func commitNoteChanges(_ changes: [(noteID: UUID, action: NoteAction, title: String)]) async {
        guard configuration.enabled && configuration.autoCommit else {
            return
        }

        #if os(macOS)
        guard !changes.isEmpty else { return }

        do {
            // Check if repository is initialized
            guard await gitService.isGitRepository(at: repositoryPath) else {
                Logger.warning("Repository not initialized, skipping commit", category: .git)
                return
            }

            // Add all note files
            let noteFiles = changes.map { "\($0.noteID.uuidString).md" }
            try await gitService.add(files: noteFiles, in: repositoryPath)

            // Construct batch commit message
            let message = "Update \(changes.count) note(s)"

            // Commit
            let hash = try await gitService.commit(message: message, in: repositoryPath)

            Logger.info("Committed \(changes.count) note changes [\(hash)]", category: .git)
            eventHandler?(.commitCreated(hash: hash, message: message))

            // Trigger push if enabled
            if configuration.autoPush {
                Task.detached(priority: .background) { [weak self] in
                    await self?.pushInBackground()
                }
            }

        } catch {
            Logger.error("Failed to commit note changes: \(error.localizedDescription)", category: .git)
        }
        #endif
    }

    // MARK: - Synchronization

    /// Push changes to remote in background (low priority)
    func pushInBackground() async {
        guard configuration.enabled && configuration.autoPush else {
            return
        }

        #if os(macOS)
        guard let remoteURL = configuration.remoteURL else {
            Logger.debug("No remote URL configured, skipping push", category: .git)
            return
        }

        do {
            // Check if we have any commits to push
            let status = try await gitService.status(in: repositoryPath)

            // Only push if repository is clean (all changes committed)
            guard status.clean else {
                Logger.debug("Repository has uncommitted changes, skipping push", category: .git)
                return
            }

            eventHandler?(.pushStarted)
            Logger.debug("Starting background push to \(remoteURL)", category: .git)

            try await gitService.push(in: repositoryPath)

            eventHandler?(.pushCompleted)
            Logger.info("Successfully pushed to remote", category: .git)

        } catch {
            eventHandler?(.pushFailed(error))
            Logger.warning("Background push failed: \(error.localizedDescription)", category: .git)
        }
        #endif
    }

    /// Pull changes from remote
    func pull() async {
        guard configuration.enabled && configuration.autoPull else {
            return
        }

        #if os(macOS)
        guard let remoteURL = configuration.remoteURL else {
            Logger.debug("No remote URL configured, skipping pull", category: .git)
            return
        }

        do {
            eventHandler?(.pullStarted)
            Logger.debug("Pulling from \(remoteURL)", category: .git)

            try await gitService.pull(in: repositoryPath)

            eventHandler?(.pullCompleted)
            Logger.info("Successfully pulled from remote", category: .git)

        } catch let error as GitServiceError {
            if case .commandFailed(_, let output) = error, output.contains("CONFLICT") {
                // Extract conflicting files
                let files = extractConflictingFiles(from: output)
                eventHandler?(.conflictDetected(files: files))
                Logger.warning("Merge conflict detected: \(files.joined(separator: ", "))", category: .git)
            } else {
                eventHandler?(.pullFailed(error))
                Logger.warning("Pull failed: \(error.localizedDescription)", category: .git)
            }
        } catch {
            eventHandler?(.pullFailed(error))
            Logger.warning("Pull failed: \(error.localizedDescription)", category: .git)
        }
        #endif
    }

    /// Start automatic periodic pulling
    func startPullTimer() {
        // Cancel existing timer
        stopPullTimer()

        guard configuration.enabled && configuration.autoPull else {
            return
        }

        pullTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(configuration.pullInterval * 1_000_000_000))

                if !Task.isCancelled {
                    await pull()
                }
            }
        }

        Logger.info("Started pull timer with interval \(configuration.pullInterval)s", category: .git)
    }

    /// Stop automatic periodic pulling
    func stopPullTimer() {
        pullTimer?.cancel()
        pullTimer = nil
        Logger.info("Stopped pull timer", category: .git)
    }

    // MARK: - Repository Setup

    /// Initialize the repository for git synchronization
    /// - Throws: Error if initialization fails
    func initializeRepository() async throws {
        #if os(macOS)
        // Initialize git repository if needed
        if !(await gitService.isGitRepository(at: repositoryPath)) {
            try await gitService.initRepository(
                at: repositoryPath,
                userName: configuration.userName,
                userEmail: configuration.userEmail
            )
            Logger.info("Initialized git repository", category: .git)
        }

        // Add remote if configured
        if let remoteURL = configuration.remoteURL {
            do {
                try await gitService.addRemote(
                    name: configuration.remoteName,
                    url: remoteURL,
                    in: repositoryPath
                )
                Logger.info("Added remote: \(remoteURL)", category: .git)
            } catch {
                // Remote might already exist, ignore error
                Logger.debug("Remote already exists or failed to add: \(error.localizedDescription)", category: .git)
            }
        }

        // Start pull timer if enabled
        if configuration.autoPull {
            startPullTimer()
        }
        #else
        throw GitServiceError.commandFailed(command: "init", output: "Git operations only supported on macOS")
        #endif
    }

    // MARK: - Helper Methods

    private func extractConflictingFiles(from output: String) -> [String] {
        var files: [String] = []

        for line in output.components(separatedBy: .newlines) {
            if line.contains("CONFLICT") {
                // Extract file name from "CONFLICT (content): Merge conflict in filename.md"
                if let range = line.range(of: "Merge conflict in ") {
                    let fileName = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    files.append(fileName)
                }
            }
        }

        return files
    }
}
#endif // os(macOS)

// MARK: - Note Action

/// Actions that can be performed on notes
enum NoteAction {
    case add
    case update
    case delete

    func commitMessage(for noteTitle: String) -> String {
        switch self {
        case .add:
            return "Add note: \(noteTitle)"
        case .update:
            return "Update note: \(noteTitle)"
        case .delete:
            return "Delete note: \(noteTitle)"
        }
    }
}
