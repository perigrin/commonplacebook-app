// ABOUTME: Tests for Git repository operations service
// ABOUTME: Verifies init, clone, commit, push, pull, and merge operations using shell git

import XCTest
@testable import Commonplace_Book

final class GitServiceTests: XCTestCase {
    var sut: GitService!
    var testRepoPath: URL!
    var sshKeyService: MockSSHKeyService!

    override func setUp() async throws {
        try await super.setUp()

        // Create a temporary directory for test repository
        testRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("git_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testRepoPath, withIntermediateDirectories: true)

        sshKeyService = MockSSHKeyService()
        sut = GitService(sshKeyService: sshKeyService)
    }

    override func tearDown() async throws {
        // Clean up test repository
        if let testRepoPath = testRepoPath {
            try? FileManager.default.removeItem(at: testRepoPath)
        }
        sut = nil
        sshKeyService = nil
        try await super.tearDown()
    }

    // MARK: - Repository Initialization Tests

    func testInitRepository_createsGitRepo() async throws {
        #if os(macOS)
        // When: Initialize a git repository
        try await sut.initRepository(at: testRepoPath)

        // Then: Should create .git directory
        let gitDir = testRepoPath.appendingPathComponent(".git")
        XCTAssertTrue(FileManager.default.fileExists(atPath: gitDir.path), ".git directory should exist")

        // And: Should be a valid git repository
        let isRepo = await sut.isGitRepository(at: testRepoPath)
        XCTAssertTrue(isRepo, "Should be a valid git repository")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    func testInitRepository_configuresUserInfo() async throws {
        #if os(macOS)
        // When: Initialize with user info
        try await sut.initRepository(at: testRepoPath, userName: "Test User", userEmail: "test@example.com")

        // Then: Should set user name and email
        let name = try await sut.getConfig(key: "user.name", in: testRepoPath)
        let email = try await sut.getConfig(key: "user.email", in: testRepoPath)

        XCTAssertEqual(name, "Test User", "Should set user name")
        XCTAssertEqual(email, "test@example.com", "Should set user email")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    // MARK: - Commit Tests

    func testCommit_createsCommit() async throws {
        #if os(macOS)
        // Given: An initialized repository with a file
        try await sut.initRepository(at: testRepoPath, userName: "Test", userEmail: "test@test.com")
        let testFile = testRepoPath.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // When: Stage and commit the file
        try await sut.add(files: ["test.txt"], in: testRepoPath)
        let commitHash = try await sut.commit(message: "Test commit", in: testRepoPath)

        // Then: Should return a commit hash
        XCTAssertFalse(commitHash.isEmpty, "Should return commit hash")
        XCTAssertEqual(commitHash.count, 40, "Commit hash should be 40 characters (SHA-1)")

        // And: Commit should exist in log
        let log = try await sut.log(limit: 1, in: testRepoPath)
        XCTAssertEqual(log.count, 1, "Should have one commit")
        XCTAssertEqual(log.first?.message, "Test commit", "Commit message should match")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    func testCommit_withMultipleFiles() async throws {
        #if os(macOS)
        // Given: An initialized repository with multiple files
        try await sut.initRepository(at: testRepoPath, userName: "Test", userEmail: "test@test.com")

        let file1 = testRepoPath.appendingPathComponent("file1.txt")
        let file2 = testRepoPath.appendingPathComponent("file2.txt")
        try "content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "content 2".write(to: file2, atomically: true, encoding: .utf8)

        // When: Stage and commit all files
        try await sut.add(files: ["file1.txt", "file2.txt"], in: testRepoPath)
        _ = try await sut.commit(message: "Add multiple files", in: testRepoPath)

        // Then: Both files should be in the repository
        let status = try await sut.status(in: testRepoPath)
        XCTAssertTrue(status.clean, "Repository should be clean after commit")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    // MARK: - Status Tests

    func testStatus_detectsChanges() async throws {
        #if os(macOS)
        // Given: An initialized repository with committed file
        try await sut.initRepository(at: testRepoPath, userName: "Test", userEmail: "test@test.com")
        let testFile = testRepoPath.appendingPathComponent("test.txt")
        try "original".write(to: testFile, atomically: true, encoding: .utf8)
        try await sut.add(files: ["test.txt"], in: testRepoPath)
        _ = try await sut.commit(message: "Initial commit", in: testRepoPath)

        // When: Modify the file
        try "modified".write(to: testFile, atomically: true, encoding: .utf8)

        // Then: Status should show changes
        let status = try await sut.status(in: testRepoPath)
        XCTAssertFalse(status.clean, "Should not be clean")
        XCTAssertTrue(status.hasUnstagedChanges, "Should have unstaged changes")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    // MARK: - Remote Tests

    func testAddRemote_configuresRemote() async throws {
        #if os(macOS)
        // Given: An initialized repository
        try await sut.initRepository(at: testRepoPath)

        // When: Add a remote
        try await sut.addRemote(name: "origin", url: "git@github.com:test/repo.git", in: testRepoPath)

        // Then: Remote should be configured
        let remoteURL = try await sut.getConfig(key: "remote.origin.url", in: testRepoPath)
        XCTAssertEqual(remoteURL, "git@github.com:test/repo.git", "Remote URL should be set")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    // MARK: - Branch Tests

    func testGetCurrentBranch_returnsDefaultBranch() async throws {
        #if os(macOS)
        // Given: An initialized repository with a commit
        try await sut.initRepository(at: testRepoPath, userName: "Test", userEmail: "test@test.com")
        let testFile = testRepoPath.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        try await sut.add(files: ["test.txt"], in: testRepoPath)
        _ = try await sut.commit(message: "Initial commit", in: testRepoPath)

        // When: Get current branch
        let branch = try await sut.getCurrentBranch(in: testRepoPath)

        // Then: Should return a branch name (main or master)
        XCTAssertTrue(branch == "main" || branch == "master", "Should be on default branch")
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    // MARK: - Error Handling Tests

    func testInitRepository_throwsWhenPathDoesNotExist() async throws {
        #if os(macOS)
        // Given: A non-existent path
        let nonExistentPath = testRepoPath.appendingPathComponent("nonexistent")

        // When/Then: Should throw error
        do {
            try await sut.initRepository(at: nonExistentPath)
            XCTFail("Should throw error for non-existent path")
        } catch {
            // Expected
        }
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }

    func testCommit_throwsWhenNoChangesStaged() async throws {
        #if os(macOS)
        // Given: An initialized repository with no staged changes
        try await sut.initRepository(at: testRepoPath, userName: "Test", userEmail: "test@test.com")

        // When/Then: Should throw error
        do {
            _ = try await sut.commit(message: "Empty commit", in: testRepoPath)
            XCTFail("Should throw error when nothing staged")
        } catch {
            // Expected
        }
        #else
        throw XCTSkip("Git operations only supported on macOS")
        #endif
    }
}

// MARK: - Mock SSH Key Service

class MockSSHKeyService {
    var hasKeysResult = true
    var privateKeyPath: URL?

    func hasKeys() async -> Bool {
        return hasKeysResult
    }

    func writePrivateKeyToTempFile() async throws -> URL {
        if let path = privateKeyPath {
            return path
        }
        // Create a dummy key file
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("mock_key")
        try "mock key".write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile
    }
}
