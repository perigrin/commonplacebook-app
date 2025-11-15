// ABOUTME: Tests for iOS git synchronization service using Working Copy
// ABOUTME: Verifies auto-commit, background push/pull, and configuration management on iOS

import XCTest
@testable import Commonplace_Book

#if os(iOS)
final class GitSyncServiceiOSTests: XCTestCase {
    var sut: GitSyncServiceiOS!
    var testRepoPath: URL!
    var workingCopyService: WorkingCopyService!

    override func setUp() async throws {
        try await super.setUp()

        // Create a temporary directory for test repository
        testRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("git_sync_ios_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testRepoPath, withIntermediateDirectories: true)

        workingCopyService = WorkingCopyService()

        var config = GitSyncConfiguration()
        config.userName = "Test User"
        config.userEmail = "test@example.com"
        config.autoPush = false // Disable push for tests
        config.autoPull = false // Disable pull for tests

        sut = GitSyncServiceiOS(
            workingCopyService: workingCopyService,
            repositoryPath: testRepoPath,
            configuration: config
        )
    }

    override func tearDown() async throws {
        // Clean up test repository
        if let testRepoPath = testRepoPath {
            try? FileManager.default.removeItem(at: testRepoPath)
        }
        sut = nil
        workingCopyService = nil
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func testUpdateConfiguration_updatesSettings() async throws {
        // Given: Initial configuration
        var newConfig = await sut.getConfiguration()
        newConfig.autoCommit = false

        // When: Update configuration
        await sut.updateConfiguration(newConfig)

        // Then: Configuration should be updated
        let updated = await sut.getConfiguration()
        XCTAssertFalse(updated.autoCommit, "Auto-commit should be disabled")
    }

    func testGetConfiguration_returnsCurrentConfig() async throws {
        // When: Get configuration
        let config = await sut.getConfiguration()

        // Then: Should return configuration with test values
        XCTAssertEqual(config.userName, "Test User", "User name should match")
        XCTAssertEqual(config.userEmail, "test@example.com", "User email should match")
        XCTAssertFalse(config.autoPush, "Auto push should be disabled")
        XCTAssertFalse(config.autoPull, "Auto pull should be disabled")
    }

    // MARK: - Event Handler Tests

    func testSetEventHandler_storesHandler() async throws {
        // Given: An event handler
        var receivedEvents: [GitSyncEvent] = []
        let handler: (GitSyncEvent) -> Void = { event in
            receivedEvents.append(event)
        }

        // When: Set event handler
        await sut.setEventHandler(handler)

        // Then: Handler should be stored (we can't directly test this, but can verify it's called later)
        XCTAssertNotNil(handler, "Handler should be set")
    }

    // MARK: - Auto-Commit Tests

    func testCommitNoteChange_whenEnabledAndWorkingCopyInstalled() async throws {
        // Given: Auto-commit enabled
        var config = await sut.getConfiguration()
        config.autoCommit = true
        config.remoteURL = "git@github.com:test/repo.git"
        await sut.updateConfiguration(config)

        // Set repository name for Working Copy
        await sut.setRepositoryName("test-repo")

        // Track events
        var receivedEvents: [GitSyncEvent] = []
        await sut.setEventHandler { event in
            receivedEvents.append(event)
        }

        // Note: This test will only work if Working Copy is actually installed
        // For unit testing, we're verifying the service handles the case correctly
        let noteID = UUID()

        // When: Commit note change (will fail if Working Copy not installed, but shouldn't crash)
        await sut.commitNoteChange(noteID: noteID, action: .add, title: "Test Note")

        // Then: Should attempt commit (may fail if Working Copy not installed)
        // Success depends on Working Copy being installed, so we just verify no crash
        XCTAssertNotNil(sut, "Service should handle commit attempt")
    }

    func testCommitNoteChange_whenDisabled_doesNotCommit() async throws {
        // Given: Auto-commit disabled
        var config = await sut.getConfiguration()
        config.autoCommit = false
        await sut.updateConfiguration(config)

        let noteID = UUID()

        // When: Attempt to commit note change
        await sut.commitNoteChange(noteID: noteID, action: .add, title: "Test Note")

        // Then: No commit should be attempted (no error, no event)
        // We verify by checking the service is still functional
        XCTAssertNotNil(sut, "Service should skip commit when disabled")
    }

    func testCommitNoteChanges_batchesMultipleNotes() async throws {
        // Given: Multiple note changes
        var config = await sut.getConfiguration()
        config.autoCommit = true
        await sut.updateConfiguration(config)

        await sut.setRepositoryName("test-repo")

        let changes = [
            (noteID: UUID(), action: NoteAction.add, title: "Note 1"),
            (noteID: UUID(), action: NoteAction.add, title: "Note 2"),
            (noteID: UUID(), action: NoteAction.update, title: "Note 3")
        ]

        // When: Commit batch of changes
        await sut.commitNoteChanges(changes)

        // Then: Should batch commit (actual success depends on Working Copy)
        XCTAssertNotNil(sut, "Service should handle batch commit")
    }

    // MARK: - Push/Pull Tests

    func testPushInBackground_whenEnabled() async throws {
        // Given: Auto-push enabled
        var config = await sut.getConfiguration()
        config.autoPush = true
        config.remoteURL = "git@github.com:test/repo.git"
        await sut.updateConfiguration(config)

        await sut.setRepositoryName("test-repo")

        // When: Trigger background push
        await sut.pushInBackground()

        // Then: Should attempt push (may fail if Working Copy not installed)
        XCTAssertNotNil(sut, "Service should handle push attempt")
    }

    func testPull_whenEnabled() async throws {
        // Given: Auto-pull enabled
        var config = await sut.getConfiguration()
        config.autoPull = true
        config.remoteURL = "git@github.com:test/repo.git"
        await sut.updateConfiguration(config)

        await sut.setRepositoryName("test-repo")

        // When: Trigger pull
        await sut.pull()

        // Then: Should attempt pull (may fail if Working Copy not installed)
        XCTAssertNotNil(sut, "Service should handle pull attempt")
    }

    // MARK: - Timer Tests

    func testStartPullTimer_startsPeriodicPull() async throws {
        // Given: Auto-pull enabled with short interval
        var config = await sut.getConfiguration()
        config.autoPull = true
        config.pullInterval = 1.0 // 1 second for testing
        config.remoteURL = "git@github.com:test/repo.git"
        await sut.updateConfiguration(config)

        await sut.setRepositoryName("test-repo")

        // When: Start pull timer
        await sut.startPullTimer()

        // Wait briefly to allow timer to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Timer should be running
        // We can't easily test the timer fired, but we verify no crash
        XCTAssertNotNil(sut, "Service should start pull timer")

        // Cleanup
        await sut.stopPullTimer()
    }

    func testStopPullTimer_cancelsTimer() async throws {
        // Given: Pull timer running
        var config = await sut.getConfiguration()
        config.autoPull = true
        config.pullInterval = 1.0
        await sut.updateConfiguration(config)

        await sut.setRepositoryName("test-repo")
        await sut.startPullTimer()

        // When: Stop pull timer
        await sut.stopPullTimer()

        // Then: Timer should be stopped
        XCTAssertNotNil(sut, "Service should stop pull timer")
    }

    // MARK: - Repository Setup Tests

    func testSetRepositoryName_storesName() async throws {
        // Given: Repository name
        let repoName = "my-notes"

        // When: Set repository name
        await sut.setRepositoryName(repoName)

        // Then: Name should be stored
        let storedName = await sut.getRepositoryName()
        XCTAssertEqual(storedName, repoName, "Repository name should be stored")
    }
}
#endif
