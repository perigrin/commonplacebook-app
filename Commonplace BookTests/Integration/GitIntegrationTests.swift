// ABOUTME: Integration tests for FileSystemNoteRepository with GitSyncService
// ABOUTME: Verifies end-to-end git synchronization workflow on macOS

import XCTest
@testable import Commonplace_Book

final class GitIntegrationTests: XCTestCase {
    var testRepoPath: URL!
    var gitService: GitService!
    var gitSyncService: GitSyncService!
    var noteRepository: FileSystemNoteRepository!
    var sshKeyService: SSHKeyService!

    override func setUp() async throws {
        try await super.setUp()

        #if os(macOS)
        // Create temporary directory for test repository
        testRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("git_integration_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testRepoPath, withIntermediateDirectories: true)

        // Initialize git services
        sshKeyService = SSHKeyService()
        gitService = GitService(sshKeyService: sshKeyService)

        // Initialize git repository
        try await gitService.initRepository(
            at: testRepoPath,
            userName: "Test User",
            userEmail: "test@example.com"
        )

        // Configure git sync
        var config = GitSyncConfiguration()
        config.userName = "Test User"
        config.userEmail = "test@example.com"
        config.autoCommit = true
        config.autoPush = false // Don't try to push in tests
        config.autoPull = false // Don't try to pull in tests

        gitSyncService = GitSyncService(
            gitService: gitService,
            repositoryPath: testRepoPath,
            configuration: config
        )

        // Create note repository with git sync
        noteRepository = FileSystemNoteRepository(
            directory: testRepoPath,
            gitSyncService: gitSyncService
        )
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    override func tearDown() async throws {
        if let testRepoPath = testRepoPath {
            try? FileManager.default.removeItem(at: testRepoPath)
        }
        noteRepository = nil
        gitSyncService = nil
        gitService = nil
        sshKeyService = nil
        try await super.tearDown()
    }

    // MARK: - Integration Tests

    func testCreateNote_automaticallyCommitsToGit() async throws {
        #if os(macOS)
        // Given: A new note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "# Test Note\n\nThis is a test note.",
            title: "Test Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // When: Create the note
        _ = try await noteRepository.create(note: note)

        // Wait a moment for async git commit
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then: Git should have a commit
        let log = try await gitService.log(limit: 1, in: testRepoPath)
        XCTAssertEqual(log.count, 1, "Should have one commit")
        XCTAssertEqual(log.first?.message, "Add note: Test Note", "Commit message should match")

        // And: Note file should exist in git
        let noteFile = testRepoPath.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: noteFile.path), "Note file should exist")

        // And: Repository should be clean
        let status = try await gitService.status(in: testRepoPath)
        XCTAssertTrue(status.clean, "Repository should be clean after commit")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testUpdateNote_automaticallyCommitsToGit() async throws {
        #if os(macOS)
        // Given: An existing note
        var note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "# Original Content",
            title: "Original Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await noteRepository.create(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)

        // When: Update the note
        note.content = "# Updated Content"
        note.title = "Updated Title"
        note.modified = Date()
        _ = try await noteRepository.update(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Should have two commits
        let log = try await gitService.log(limit: 2, in: testRepoPath)
        XCTAssertEqual(log.count, 2, "Should have two commits")
        XCTAssertEqual(log.first?.message, "Update note: Updated Title", "Recent commit should be update")
        XCTAssertEqual(log.last?.message, "Add note: Original Title", "Old commit should be add")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testDeleteNote_automaticallyCommitsToGit() async throws {
        #if os(macOS)
        // Given: An existing note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "# Test Note",
            title: "Test Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await noteRepository.create(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)

        // When: Delete the note
        try await noteRepository.delete(id: note.id)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Should have two commits
        let log = try await gitService.log(limit: 2, in: testRepoPath)
        XCTAssertEqual(log.count, 2, "Should have two commits")
        XCTAssertEqual(log.first?.message, "Delete note: Test Note", "Recent commit should be delete")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testMultipleNotes_eachHasOwnCommit() async throws {
        #if os(macOS)
        // Given: Multiple notes
        let notes = [
            Note(id: UUID(), created: Date(), device: "Test", location: nil, content: "# Note 1", title: "Note 1", backlinks: [], unknownFrontmatterFields: [:]),
            Note(id: UUID(), created: Date(), device: "Test", location: nil, content: "# Note 2", title: "Note 2", backlinks: [], unknownFrontmatterFields: [:]),
            Note(id: UUID(), created: Date(), device: "Test", location: nil, content: "# Note 3", title: "Note 3", backlinks: [], unknownFrontmatterFields: [:])
        ]

        // When: Create all notes
        for note in notes {
            _ = try await noteRepository.create(note: note)
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        // Then: Should have three commits
        let log = try await gitService.log(limit: 3, in: testRepoPath)
        XCTAssertEqual(log.count, 3, "Should have three commits")
        XCTAssertTrue(log.allSatisfy { $0.message.hasPrefix("Add note:") }, "All commits should be adds")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testRestoreNote_commitsAsUpdate() async throws {
        #if os(macOS)
        // Given: A deleted note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "# Test Note",
            title: "Test Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await noteRepository.create(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)
        try await noteRepository.delete(id: note.id)
        try await Task.sleep(nanoseconds: 500_000_000)

        // When: Restore the note
        try await noteRepository.restore(id: note.id)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Should have three commits
        let log = try await gitService.log(limit: 3, in: testRepoPath)
        XCTAssertEqual(log.count, 3, "Should have three commits")
        XCTAssertTrue(log.first?.message.hasPrefix("Update note:") ?? false, "Restore should be an update")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testPurgeNote_commitsDelete() async throws {
        #if os(macOS)
        // Given: A deleted note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "# Test Note",
            title: "Test Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await noteRepository.create(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)
        try await noteRepository.delete(id: note.id)
        try await Task.sleep(nanoseconds: 500_000_000)

        // When: Purge the note
        try await noteRepository.purge(id: note.id)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Should have three commits
        let log = try await gitService.log(limit: 3, in: testRepoPath)
        XCTAssertEqual(log.count, 3, "Should have three commits")
        XCTAssertTrue(log.first?.message.hasPrefix("Delete note:") ?? false, "Purge should be a delete")
        XCTAssertTrue(log.first?.message.contains("Purged:") ?? false, "Should mention purge")

        // And: Note file should be removed
        let noteFile = testRepoPath.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: noteFile.path), "Note file should be removed")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testRepositoryWithoutGitSync_stillWorks() async throws {
        #if os(macOS)
        // Given: A repository without git sync
        let plainRepo = FileSystemNoteRepository(directory: testRepoPath)

        // When: Create a note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "# Plain Note",
            title: "Plain Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await plainRepo.create(note: note)

        // Then: Note should be created without git commit
        let noteFile = testRepoPath.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: noteFile.path), "Note file should exist")

        // And: Should still have previous commits from setup, but no new one
        let initialCommitCount = try await gitService.log(limit: 100, in: testRepoPath).count
        try await Task.sleep(nanoseconds: 500_000_000)
        let finalCommitCount = try await gitService.log(limit: 100, in: testRepoPath).count
        XCTAssertEqual(initialCommitCount, finalCommitCount, "No new commits should be created")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    // MARK: - End-to-End Tests

    func testCompleteWorkflow_createUpdateDeleteRestore() async throws {
        #if os(macOS)
        // Given: A fresh repository
        var note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "# Initial Content",
            title: "Initial Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // When: Execute complete workflow
        // 1. Create
        _ = try await noteRepository.create(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)

        // 2. Update
        note.content = "# Updated Content"
        note.title = "Updated Title"
        note.modified = Date()
        _ = try await noteRepository.update(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)

        // 3. Delete
        try await noteRepository.delete(id: note.id)
        try await Task.sleep(nanoseconds: 500_000_000)

        // 4. Restore
        try await noteRepository.restore(id: note.id)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Should have four commits
        let log = try await gitService.log(limit: 4, in: testRepoPath)
        XCTAssertEqual(log.count, 4, "Should have four commits")

        // Verify commit sequence
        XCTAssertTrue(log[0].message.hasPrefix("Update note:"), "Most recent should be restore (update)")
        XCTAssertEqual(log[1].message, "Delete note: Updated Title", "Third should be delete")
        XCTAssertEqual(log[2].message, "Update note: Updated Title", "Second should be update")
        XCTAssertEqual(log[3].message, "Add note: Initial Title", "First should be add")

        // And: Repository should be clean
        let status = try await gitService.status(in: testRepoPath)
        XCTAssertTrue(status.clean, "Repository should be clean")

        // And: Note should exist and be restored
        let retrievedNote = try await noteRepository.read(id: note.id)
        XCTAssertNotNil(retrievedNote, "Note should exist")
        XCTAssertNil(retrievedNote?.deletedAt, "Note should not be deleted")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testCompleteWorkflow_multipleNotesWithBacklinks() async throws {
        #if os(macOS)
        // Given: Multiple interconnected notes
        let note1 = Note(
            id: UUID(),
            created: Date(),
            device: "Test",
            location: nil,
            content: "# Note 1",
            title: "Note 1",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let note2 = Note(
            id: UUID(),
            created: Date(),
            device: "Test",
            location: nil,
            content: "# Note 2\n\nLinks to [\(note1.id.uuidString)]",
            title: "Note 2",
            backlinks: [note1.id],
            unknownFrontmatterFields: [:]
        )

        // When: Create both notes
        _ = try await noteRepository.create(note: note1)
        try await Task.sleep(nanoseconds: 500_000_000)
        _ = try await noteRepository.create(note: note2)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Both notes should be committed
        let log = try await gitService.log(limit: 2, in: testRepoPath)
        XCTAssertEqual(log.count, 2, "Should have two commits")

        // And: Both files should exist in git
        let file1 = testRepoPath.appendingPathComponent("\(note1.id.uuidString).md")
        let file2 = testRepoPath.appendingPathComponent("\(note2.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1.path), "Note 1 file should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path), "Note 2 file should exist")

        // And: Backlink should be preserved in file content
        let file2Content = try String(contentsOf: file2, encoding: .utf8)
        XCTAssertTrue(file2Content.contains("backlinks:"), "Backlinks should be in frontmatter")
        XCTAssertTrue(file2Content.contains(note1.id.uuidString), "Backlink ID should be preserved")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testCompleteWorkflow_withLocation() async throws {
        #if os(macOS)
        // Given: A note with location
        let location = Location(latitude: 37.7749, longitude: -122.4194, accuracy: 5.0)
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: location,
            content: "# Note with Location",
            title: "Note with Location",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // When: Create the note
        _ = try await noteRepository.create(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Note should be committed
        let log = try await gitService.log(limit: 1, in: testRepoPath)
        XCTAssertEqual(log.count, 1, "Should have one commit")

        // And: Location should be preserved in file
        let noteFile = testRepoPath.appendingPathComponent("\(note.id.uuidString).md")
        let fileContent = try String(contentsOf: noteFile, encoding: .utf8)
        XCTAssertTrue(fileContent.contains("location:"), "Location should be in frontmatter")
        XCTAssertTrue(fileContent.contains("latitude: 37.7749"), "Latitude should be preserved")
        XCTAssertTrue(fileContent.contains("longitude: -122.4194"), "Longitude should be preserved")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }

    func testGitSyncDisabled_noCommitsCreated() async throws {
        #if os(macOS)
        // Given: Git sync disabled
        var config = await gitSyncService.getConfiguration()
        config.enabled = false
        await gitSyncService.updateConfiguration(config)

        // When: Create a note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Test",
            location: nil,
            content: "# Test",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await noteRepository.create(note: note)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: No new commits should be created
        let log = try await gitService.log(limit: 100, in: testRepoPath)
        XCTAssertEqual(log.count, 0, "No commits should be created when sync disabled")

        // But: Note file should still exist
        let noteFile = testRepoPath.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: noteFile.path), "Note file should exist")
        #else
        throw XCTSkip("Git integration tests only supported on macOS")
        #endif
    }
}
