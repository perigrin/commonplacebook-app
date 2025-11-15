// ABOUTME: iOS-specific git synchronization using Working Copy app
// ABOUTME: Provides auto-commit, background push, periodic pull via Working Copy integration

import Foundation

#if os(iOS)
/// iOS-specific git synchronization service using Working Copy
actor GitSyncServiceiOS {
    private let workingCopyService: WorkingCopyService
    private let repositoryPath: URL
    private var configuration: GitSyncConfiguration
    private var pullTimer: Task<Void, Never>?
    private var eventHandler: ((GitSyncEvent) -> Void)?
    private var repositoryName: String?

    // Commit queue for batching
    private var pendingCommits: [(noteID: UUID, action: NoteAction, title: String)] = []
    private var commitBatchTimer: Task<Void, Never>?
    private let commitBatchInterval: TimeInterval = 5.0 // Batch commits over 5 seconds

    init(
        workingCopyService: WorkingCopyService,
        repositoryPath: URL,
        configuration: GitSyncConfiguration = GitSyncConfiguration()
    ) {
        self.workingCopyService = workingCopyService
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

    /// Set the Working Copy repository name
    /// - Parameter name: Repository name in Working Copy
    func setRepositoryName(_ name: String) {
        self.repositoryName = name
    }

    /// Get the Working Copy repository name
    /// - Returns: Repository name
    func getRepositoryName() -> String? {
        return repositoryName
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

        guard let repoName = repositoryName else {
            Logger.warning("No repository name configured, skipping commit", category: .git)
            return
        }

        guard await workingCopyService.isWorkingCopyInstalled() else {
            Logger.warning("Working Copy not installed, skipping commit", category: .git)
            eventHandler?(.syncDisabled)
            return
        }

        // Add to batch queue
        pendingCommits.append((noteID: noteID, action: action, title: title))

        // Start batch timer if not running
        if commitBatchTimer == nil {
            startCommitBatchTimer()
        }
    }

    /// Commit multiple note changes (batch)
    /// - Parameter changes: Array of note changes
    func commitNoteChanges(_ changes: [(noteID: UUID, action: NoteAction, title: String)]) async {
        guard configuration.enabled && configuration.autoCommit else {
            return
        }

        guard !changes.isEmpty else { return }

        guard let repoName = repositoryName else {
            Logger.warning("No repository name configured, skipping commit", category: .git)
            return
        }

        guard await workingCopyService.isWorkingCopyInstalled() else {
            Logger.warning("Working Copy not installed, skipping commit", category: .git)
            eventHandler?(.syncDisabled)
            return
        }

        do {
            // Construct batch commit message
            let message = "Update \(changes.count) note(s)"

            // Get file paths for notes
            let noteFiles = changes.map { "\($0.noteID.uuidString).md" }

            // Commit via Working Copy
            try await workingCopyService.commit(
                repository: repoName,
                message: message,
                files: noteFiles
            )

            Logger.info("Committed \(changes.count) note changes via Working Copy", category: .git)
            eventHandler?(.commitCreated(hash: "wc-batch", message: message))

            // Trigger push if enabled
            if configuration.autoPush {
                Task.detached(priority: .background) { [weak self] in
                    await self?.pushInBackground()
                }
            }

        } catch {
            Logger.error("Failed to commit note changes: \(error.localizedDescription)", category: .git)
        }
    }

    // MARK: - Synchronization

    /// Push changes to remote in background (low priority)
    func pushInBackground() async {
        guard configuration.enabled && configuration.autoPush else {
            return
        }

        guard let repoName = repositoryName else {
            Logger.debug("No repository name configured, skipping push", category: .git)
            return
        }

        guard configuration.remoteURL != nil else {
            Logger.debug("No remote URL configured, skipping push", category: .git)
            return
        }

        guard await workingCopyService.isWorkingCopyInstalled() else {
            Logger.warning("Working Copy not installed, skipping push", category: .git)
            return
        }

        do {
            eventHandler?(.pushStarted)
            Logger.debug("Starting background push via Working Copy", category: .git)

            try await workingCopyService.push(repository: repoName)

            eventHandler?(.pushCompleted)
            Logger.info("Successfully pushed to remote via Working Copy", category: .git)

        } catch {
            eventHandler?(.pushFailed(error))
            Logger.warning("Background push failed: \(error.localizedDescription)", category: .git)
        }
    }

    /// Pull changes from remote
    func pull() async {
        guard configuration.enabled && configuration.autoPull else {
            return
        }

        guard let repoName = repositoryName else {
            Logger.debug("No repository name configured, skipping pull", category: .git)
            return
        }

        guard configuration.remoteURL != nil else {
            Logger.debug("No remote URL configured, skipping pull", category: .git)
            return
        }

        guard await workingCopyService.isWorkingCopyInstalled() else {
            Logger.warning("Working Copy not installed, skipping pull", category: .git)
            return
        }

        do {
            eventHandler?(.pullStarted)
            Logger.debug("Pulling from remote via Working Copy", category: .git)

            try await workingCopyService.pull(repository: repoName)

            eventHandler?(.pullCompleted)
            Logger.info("Successfully pulled from remote via Working Copy", category: .git)

        } catch let error as WorkingCopyServiceError {
            if case .operationFailed(let message) = error, message.contains("conflict") {
                // Conflict detected
                eventHandler?(.conflictDetected(files: []))
                Logger.warning("Merge conflict detected in Working Copy", category: .git)
            } else {
                eventHandler?(.pullFailed(error))
                Logger.warning("Pull failed: \(error.localizedDescription)", category: .git)
            }
        } catch {
            eventHandler?(.pullFailed(error))
            Logger.warning("Pull failed: \(error.localizedDescription)", category: .git)
        }
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
        guard let repoName = repositoryName else {
            throw WorkingCopyServiceError.operationFailed("No repository name configured")
        }

        guard await workingCopyService.isWorkingCopyInstalled() else {
            throw WorkingCopyServiceError.notInstalled
        }

        // On iOS, we assume the repository is already set up in Working Copy
        // We just verify we can access it
        Logger.info("Using Working Copy repository: \(repoName)", category: .git)

        // Start pull timer if enabled
        if configuration.autoPull {
            startPullTimer()
        }
    }

    // MARK: - Helper Methods

    /// Start timer for batching commits
    private func startCommitBatchTimer() {
        commitBatchTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(commitBatchInterval * 1_000_000_000))

            if !Task.isCancelled {
                await flushPendingCommits()
            }
        }
    }

    /// Flush pending commits to Working Copy
    private func flushPendingCommits() async {
        guard !pendingCommits.isEmpty else {
            commitBatchTimer = nil
            return
        }

        // Get all pending commits
        let commits = pendingCommits
        pendingCommits.removeAll()
        commitBatchTimer = nil

        // Commit them as a batch
        await commitNoteChanges(commits)
    }
}
#endif
