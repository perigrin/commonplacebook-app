// ABOUTME: Tests for automatic git synchronization service
// ABOUTME: Verifies auto-commit, background push/pull, and configuration management

import XCTest
@testable import Commonplace_Book

final class GitSyncServiceTests: XCTestCase {
    var sut: GitSyncService!
    var testRepoPath: URL!
    var gitService: GitService!

    override func setUp() async throws {
        try await super.setUp()

        // Create a temporary directory for test repository
        testRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("git_sync_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testRepoPath, withIntermediateDirectories: true)

        gitService = GitService()

        // Initialize repository
        #if os(macOS)
        try await gitService.initRepository(
            at: testRepoPath,
            userName: "Test User",
            userEmail: "test@example.com"
        )
        #endif

        var config = GitSyncConfiguration()
        config.userName = "Test User"
        config.userEmail = "test@example.com"
        config.autoPush = false // Disable push for tests
        config.autoPull = false // Disable pull for tests

        sut = GitSyncService(gitService: gitService, repositoryPath: testRepoPath, configuration: config)
    }

    override func tearDown() async throws {
        // Clean up test repository
        if let testRepoPath = testRepoPath {
            try? FileManager.default.removeItem(at: testRepoPath)
        }
        sut = nil
        gitService = nil
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

    // MARK: - Auto-Commit Tests

    func testCommitNoteChange_createsCommit() async throws {
        #if os(macOS)
        // Given: A new note file
        let noteID = UUID()
        let noteFile = testRepoPath.appendingPathComponent("\(noteID.uuidString).md")
        try "# Test Note\n\nContent".write(to: noteFile, atomically: true, encoding: .utf8)

        // When: Commit the note change
        await sut.commitNoteChange(noteID: noteID, action: .add, title: "Test Note")

        // Then: Commit should be created
        let log = try await gitService.log(limit: 1, in: testRepoPath)
        XCTAssertEqual(log.count, 1, "Should have one commit")
        XCTAssertEqual(log.first?.message, "Add note: Test Note", "Commit message should match")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    func testCommitNoteChange_updateAction() async throws {
        #if os(macOS)
        // Given: An existing committed note
        let noteID = UUID()
        let noteFile = testRepoPath.appendingPathComponent("\(noteID.uuidString).md")
        try "# Original".write(to: noteFile, atomically: true, encoding: .utf8)
        await sut.commitNoteChange(noteID: noteID, action: .add, title: "Original")

        // When: Update the note
        try "# Updated".write(to: noteFile, atomically: true, encoding: .utf8)
        await sut.commitNoteChange(noteID: noteID, action: .update, title: "Updated")

        // Then: Should have two commits with correct messages
        let log = try await gitService.log(limit: 2, in: testRepoPath)
        XCTAssertEqual(log.count, 2, "Should have two commits")
        XCTAssertEqual(log.first?.message, "Update note: Updated", "Most recent commit should be update")
        XCTAssertEqual(log.last?.message, "Add note: Original", "Oldest commit should be add")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    func testCommitNoteChanges_batchCommit() async throws {
        #if os(macOS)
        // Given: Multiple new note files
        let notes = [
            (id: UUID(), title: "Note 1"),
            (id: UUID(), title: "Note 2"),
            (id: UUID(), title: "Note 3")
        ]

        for note in notes {
            let noteFile = testRepoPath.appendingPathComponent("\(note.id.uuidString).md")
            try "# \(note.title)".write(to: noteFile, atomically: true, encoding: .utf8)
        }

        // When: Batch commit all notes
        let changes = notes.map { (noteID: $0.id, action: NoteAction.add, title: $0.title) }
        await sut.commitNoteChanges(changes)

        // Then: Should have one commit for all changes
        let log = try await gitService.log(limit: 1, in: testRepoPath)
        XCTAssertEqual(log.count, 1, "Should have one commit")
        XCTAssertTrue(log.first?.message.contains("3 note(s)") ?? false, "Commit message should mention count")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    func testCommitNoteChange_skipsWhenAutoCommitDisabled() async throws {
        #if os(macOS)
        // Given: Auto-commit is disabled
        var config = await sut.getConfiguration()
        config.autoCommit = false
        await sut.updateConfiguration(config)

        // And: A new note file
        let noteID = UUID()
        let noteFile = testRepoPath.appendingPathComponent("\(noteID.uuidString).md")
        try "# Test".write(to: noteFile, atomically: true, encoding: .utf8)

        // When: Attempt to commit
        await sut.commitNoteChange(noteID: noteID, action: .add, title: "Test")

        // Then: No commit should be created
        let log = try await gitService.log(limit: 1, in: testRepoPath)
        XCTAssertEqual(log.count, 0, "Should have no commits")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    // MARK: - Event Handler Tests

    func testEventHandler_receivesCommitEvent() async throws {
        #if os(macOS)
        // Given: An event handler
        var receivedEvents: [GitSyncEvent] = []
        await sut.setEventHandler { event in
            receivedEvents.append(event)
        }

        // And: A new note file
        let noteID = UUID()
        let noteFile = testRepoPath.appendingPathComponent("\(noteID.uuidString).md")
        try "# Test".write(to: noteFile, atomically: true, encoding: .utf8)

        // When: Commit the note
        await sut.commitNoteChange(noteID: noteID, action: .add, title: "Test")

        // Then: Should receive commit event
        // Give it a moment to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        XCTAssertFalse(receivedEvents.isEmpty, "Should receive at least one event")

        if case .commitCreated(let hash, let message) = receivedEvents.first {
            XCTAssertFalse(hash.isEmpty, "Commit hash should not be empty")
            XCTAssertEqual(message, "Add note: Test", "Commit message should match")
        } else {
            XCTFail("Should receive commit created event")
        }
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    // MARK: - Repository Initialization Tests

    func testInitializeRepository_setsUpGit() async throws {
        #if os(macOS)
        // Given: A new directory without git
        let newRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("new_repo_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: newRepoPath, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: newRepoPath)
        }

        var config = GitSyncConfiguration()
        config.userName = "Test User"
        config.userEmail = "test@example.com"
        config.autoPull = false

        let newSut = GitSyncService(
            gitService: gitService,
            repositoryPath: newRepoPath,
            configuration: config
        )

        // When: Initialize repository
        try await newSut.initializeRepository()

        // Then: Should be a git repository
        let isRepo = await gitService.isGitRepository(at: newRepoPath)
        XCTAssertTrue(isRepo, "Should be a git repository")

        // And: Should have user config
        let userName = try await gitService.getConfig(key: "user.name", in: newRepoPath)
        XCTAssertEqual(userName, "Test User", "Should set user name")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    func testInitializeRepository_addsRemote() async throws {
        #if os(macOS)
        // Given: A new directory with remote URL configured
        let newRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("new_repo_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: newRepoPath, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: newRepoPath)
        }

        var config = GitSyncConfiguration()
        config.userName = "Test"
        config.userEmail = "test@test.com"
        config.remoteURL = "git@github.com:test/repo.git"
        config.autoPull = false

        let newSut = GitSyncService(
            gitService: gitService,
            repositoryPath: newRepoPath,
            configuration: config
        )

        // When: Initialize repository
        try await newSut.initializeRepository()

        // Then: Should have remote configured
        let remoteURL = try await gitService.getConfig(key: "remote.origin.url", in: newRepoPath)
        XCTAssertEqual(remoteURL, "git@github.com:test/repo.git", "Should set remote URL")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }
}
