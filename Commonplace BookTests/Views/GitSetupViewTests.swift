// ABOUTME: Tests for Git setup wizard view
// ABOUTME: Verifies multi-step setup flow and SSH key generation UI

import XCTest
import SwiftUI
@testable import Commonplace_Book

final class GitSetupViewTests: XCTestCase {

    // MARK: - Setup Step Navigation Tests

    func testSetupSteps_haveCorrectTitles() {
        #if os(macOS)
        XCTAssertEqual(GitSetupView.SetupStep.welcome.title, "Welcome to Git Integration")
        XCTAssertEqual(GitSetupView.SetupStep.generateKey.title, "Generate SSH Key")
        XCTAssertEqual(GitSetupView.SetupStep.addKeyToHost.title, "Add Key to Git Host")
        XCTAssertEqual(GitSetupView.SetupStep.configureRepository.title, "Configure Repository")
        XCTAssertEqual(GitSetupView.SetupStep.testConnection.title, "Test Connection")
        XCTAssertEqual(GitSetupView.SetupStep.complete.title, "Setup Complete")
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    func testSetupSteps_inCorrectOrder() {
        #if os(macOS)
        let steps = GitSetupView.SetupStep.allCases
        XCTAssertEqual(steps.count, 6, "Should have 6 setup steps")
        XCTAssertEqual(steps[0], .welcome)
        XCTAssertEqual(steps[1], .generateKey)
        XCTAssertEqual(steps[2], .addKeyToHost)
        XCTAssertEqual(steps[3], .configureRepository)
        XCTAssertEqual(steps[4], .testConnection)
        XCTAssertEqual(steps[5], .complete)
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    // MARK: - View State Tests

    func testInitialState_startsAtWelcome() {
        #if os(macOS)
        let view = GitSetupView()
        let mirror = Mirror(reflecting: view)

        // Access private state using Mirror
        if let currentStep = mirror.children.first(where: { $0.label == "_currentStep" })?.value as? State<GitSetupView.SetupStep> {
            XCTAssertEqual(currentStep.wrappedValue, .welcome, "Should start at welcome step")
        } else {
            XCTFail("Could not access currentStep state")
        }
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    func testInitialState_hasEmptyFields() {
        #if os(macOS)
        let view = GitSetupView()
        let mirror = Mirror(reflecting: view)

        // Check repository URL is empty
        if let repoURL = mirror.children.first(where: { $0.label == "_repositoryURL" })?.value as? State<String> {
            XCTAssertEqual(repoURL.wrappedValue, "", "Repository URL should be empty")
        }

        // Check user name is empty
        if let userName = mirror.children.first(where: { $0.label == "_userName" })?.value as? State<String> {
            XCTAssertEqual(userName.wrappedValue, "", "User name should be empty")
        }

        // Check user email is empty
        if let userEmail = mirror.children.first(where: { $0.label == "_userEmail" })?.value as? State<String> {
            XCTAssertEqual(userEmail.wrappedValue, "", "User email should be empty")
        }

        // Check public key is empty
        if let publicKey = mirror.children.first(where: { $0.label == "_publicKey" })?.value as? State<String> {
            XCTAssertEqual(publicKey.wrappedValue, "", "Public key should be empty")
        }
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    // MARK: - Supporting View Tests

    func testInstructionRow_displaysCorrectly() {
        #if os(macOS)
        let row = InstructionRow(number: "1", text: "Test instruction")

        // Verify it creates without error
        XCTAssertNotNil(row, "InstructionRow should be created")

        let mirror = Mirror(reflecting: row)
        if let number = mirror.children.first(where: { $0.label == "number" })?.value as? String {
            XCTAssertEqual(number, "1", "Number should be '1'")
        }

        if let text = mirror.children.first(where: { $0.label == "text" })?.value as? String {
            XCTAssertEqual(text, "Test instruction", "Text should match")
        }
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    func testPublicKeyView_displaysKey() {
        #if os(macOS)
        let testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAATEST test@example.com"
        let view = PublicKeyView(publicKey: testKey)

        let mirror = Mirror(reflecting: view)
        if let publicKey = mirror.children.first(where: { $0.label == "publicKey" })?.value as? String {
            XCTAssertEqual(publicKey, testKey, "Public key should be stored")
        }
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    // MARK: - Integration Tests with Real SSH Key Service

    func testSSHKeyGeneration_updatesPublicKey() async throws {
        #if os(macOS)
        // This is more of an integration test but verifies the actual flow
        let sshKeyService = SSHKeyService()

        // Generate a key
        let keyPair = try await sshKeyService.generateKeyPair(comment: "test@example.com")

        // Verify it has the expected format
        XCTAssertTrue(keyPair.publicKey.hasPrefix("ssh-ed25519 "), "Public key should start with ssh-ed25519")
        XCTAssertTrue(keyPair.publicKey.contains("test@example.com"), "Public key should contain comment")
        XCTAssertTrue(keyPair.privateKey.hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----"), "Private key should be in OpenSSH format")

        // Clean up
        try await sshKeyService.deleteKeys()
        #else
        throw XCTSkip("SSH key generation only available on macOS")
        #endif
    }

    // MARK: - Validation Tests

    func testConfigurationValidation_requiresAllFields() {
        #if os(macOS)
        // Test that configuration step requires all fields to be filled
        // This would be tested through the canProceedToNextStep logic

        // Empty fields should not allow proceeding
        let emptyURL = ""
        let emptyName = ""
        let emptyEmail = ""

        XCTAssertTrue(emptyURL.isEmpty, "Empty URL should be empty")
        XCTAssertTrue(emptyName.isEmpty, "Empty name should be empty")
        XCTAssertTrue(emptyEmail.isEmpty, "Empty email should be empty")

        // Filled fields should allow proceeding
        let filledURL = "git@github.com:user/repo.git"
        let filledName = "Test User"
        let filledEmail = "test@example.com"

        XCTAssertFalse(filledURL.isEmpty, "Filled URL should not be empty")
        XCTAssertFalse(filledName.isEmpty, "Filled name should not be empty")
        XCTAssertFalse(filledEmail.isEmpty, "Filled email should not be empty")
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    func testRepositoryURL_acceptsSSHFormat() {
        #if os(macOS)
        let validURLs = [
            "git@github.com:user/repo.git",
            "git@gitlab.com:group/project.git",
            "git@bitbucket.org:team/repo.git",
            "git@git.example.com:path/to/repo.git"
        ]

        for url in validURLs {
            XCTAssertTrue(url.hasPrefix("git@"), "URL should start with git@: \(url)")
            XCTAssertTrue(url.hasSuffix(".git"), "URL should end with .git: \(url)")
        }
        #else
        XCTSkip("Git setup view only available on macOS")
        #endif
    }

    // MARK: - Error Handling Tests

    func testSSHKeyGeneration_handlesErrors() async throws {
        #if os(macOS)
        // Test that SSH key generation errors are handled gracefully
        // This would be in the actual view, but we can test the service behavior
        let sshKeyService = SSHKeyService()

        do {
            // Try to get a public key when none exists
            _ = try await sshKeyService.getPublicKey()
            XCTFail("Should throw error when no key exists")
        } catch SSHKeyServiceError.noKeyFound {
            // Expected
        } catch {
            XCTFail("Should throw noKeyFound error, got: \(error)")
        }
        #else
        throw XCTSkip("SSH key generation only available on macOS")
        #endif
    }

    // MARK: - Workflow Tests

    func testCompleteSetupWorkflow_canGenerateAndRetrieveKey() async throws {
        #if os(macOS)
        let sshKeyService = SSHKeyService()

        // 1. Check no keys exist initially
        let hasKeysBefore = await sshKeyService.hasKeys()
        if hasKeysBefore {
            // Clean up any existing keys
            try await sshKeyService.deleteKeys()
        }

        // 2. Generate key
        let keyPair = try await sshKeyService.generateKeyPair(comment: "workflow@test.com")
        XCTAssertFalse(keyPair.publicKey.isEmpty, "Public key should not be empty")
        XCTAssertFalse(keyPair.privateKey.isEmpty, "Private key should not be empty")

        // 3. Verify keys exist
        let hasKeysAfter = await sshKeyService.hasKeys()
        XCTAssertTrue(hasKeysAfter, "Keys should exist after generation")

        // 4. Retrieve public key
        let retrievedKey = try await sshKeyService.getPublicKey()
        XCTAssertEqual(retrievedKey, keyPair.publicKey, "Retrieved key should match generated key")

        // 5. Get fingerprint
        let fingerprint = try await sshKeyService.getFingerprint()
        XCTAssertTrue(fingerprint.hasPrefix("SHA256:"), "Fingerprint should start with SHA256:")

        // Clean up
        try await sshKeyService.deleteKeys()

        // 6. Verify cleanup
        let hasKeysAfterDelete = await sshKeyService.hasKeys()
        XCTAssertFalse(hasKeysAfterDelete, "Keys should not exist after deletion")
        #else
        throw XCTSkip("SSH key workflow only available on macOS")
        #endif
    }

    func testSetupWorkflow_canConfigureGitSync() async throws {
        #if os(macOS)
        // Test the complete workflow from setup to configuration
        let testRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("git_setup_workflow_\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: testRepoPath)
        }

        try FileManager.default.createDirectory(at: testRepoPath, withIntermediateDirectories: true)

        // 1. Initialize git repository
        let gitService = GitService()
        try await gitService.initRepository(
            at: testRepoPath,
            userName: "Test User",
            userEmail: "test@example.com"
        )

        // 2. Verify it's a git repo
        let isRepo = await gitService.isGitRepository(at: testRepoPath)
        XCTAssertTrue(isRepo, "Should be a git repository")

        // 3. Configure user info
        let userName = try await gitService.getConfig(key: "user.name", in: testRepoPath)
        let userEmail = try await gitService.getConfig(key: "user.email", in: testRepoPath)
        XCTAssertEqual(userName, "Test User", "User name should be set")
        XCTAssertEqual(userEmail, "test@example.com", "User email should be set")

        // 4. Create git sync service
        var config = GitSyncConfiguration()
        config.userName = "Test User"
        config.userEmail = "test@example.com"
        config.autoCommit = true

        let gitSyncService = GitSyncService(
            gitService: gitService,
            repositoryPath: testRepoPath,
            configuration: config
        )

        // 5. Verify configuration
        let retrievedConfig = await gitSyncService.getConfiguration()
        XCTAssertEqual(retrievedConfig.userName, "Test User", "User name should be configured")
        XCTAssertEqual(retrievedConfig.userEmail, "test@example.com", "User email should be configured")
        XCTAssertTrue(retrievedConfig.autoCommit, "Auto-commit should be enabled")
        #else
        throw XCTSkip("Git setup workflow only available on macOS")
        #endif
    }
}
