// ABOUTME: Tests for Working Copy app integration service
// ABOUTME: Verifies URL scheme generation and x-callback-url protocol handling

import XCTest
@testable import Commonplace_Book

#if os(iOS)
import UIKit

final class WorkingCopyServiceTests: XCTestCase {
    var sut: WorkingCopyService!

    override func setUp() async throws {
        try await super.setUp()
        sut = WorkingCopyService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Working Copy Detection Tests

    func testIsWorkingCopyInstalled_returnsBoolean() async {
        // When: Check if Working Copy is installed
        let isInstalled = await sut.isWorkingCopyInstalled()

        // Then: Should return a boolean (true or false depending on device)
        // We can't assert a specific value since it depends on the test environment
        XCTAssertNotNil(isInstalled)
    }

    // MARK: - URL Generation Tests

    func testGenerateCommitURL_createsValidURL() async {
        // Given: Repository name and commit message
        let repoName = "test-repo"
        let message = "Test commit"

        // When: Generate commit URL
        let url = await sut.generateCommitURL(repository: repoName, message: message, files: [])

        // Then: URL should be valid and contain expected components
        XCTAssertNotNil(url, "URL should be generated")
        XCTAssertEqual(url?.scheme, "working-copy", "Scheme should be working-copy")
        XCTAssertTrue(url?.absoluteString.contains("x-callback-url") ?? false, "Should use x-callback-url")
        XCTAssertTrue(url?.absoluteString.contains("commit") ?? false, "Should be commit action")
        XCTAssertTrue(url?.absoluteString.contains(repoName) ?? false, "Should include repository name")
        XCTAssertTrue(url?.absoluteString.contains("Test%20commit") ?? false, "Should include encoded message")
    }

    func testGenerateCommitURL_withFiles_includesFilePaths() async {
        // Given: Repository name, message, and specific files
        let repoName = "test-repo"
        let message = "Update files"
        let files = ["note1.md", "note2.md"]

        // When: Generate commit URL with files
        let url = await sut.generateCommitURL(repository: repoName, message: message, files: files)

        // Then: URL should include file paths
        XCTAssertNotNil(url, "URL should be generated")
        XCTAssertTrue(url?.absoluteString.contains("note1.md") ?? false, "Should include first file")
        XCTAssertTrue(url?.absoluteString.contains("note2.md") ?? false, "Should include second file")
    }

    func testGeneratePushURL_createsValidURL() async {
        // Given: Repository name
        let repoName = "test-repo"

        // When: Generate push URL
        let url = await sut.generatePushURL(repository: repoName)

        // Then: URL should be valid and contain expected components
        XCTAssertNotNil(url, "URL should be generated")
        XCTAssertEqual(url?.scheme, "working-copy", "Scheme should be working-copy")
        XCTAssertTrue(url?.absoluteString.contains("x-callback-url") ?? false, "Should use x-callback-url")
        XCTAssertTrue(url?.absoluteString.contains("push") ?? false, "Should be push action")
        XCTAssertTrue(url?.absoluteString.contains(repoName) ?? false, "Should include repository name")
    }

    func testGeneratePullURL_createsValidURL() async {
        // Given: Repository name
        let repoName = "test-repo"

        // When: Generate pull URL
        let url = await sut.generatePullURL(repository: repoName)

        // Then: URL should be valid and contain expected components
        XCTAssertNotNil(url, "URL should be generated")
        XCTAssertEqual(url?.scheme, "working-copy", "Scheme should be working-copy")
        XCTAssertTrue(url?.absoluteString.contains("x-callback-url") ?? false, "Should use x-callback-url")
        XCTAssertTrue(url?.absoluteString.contains("pull") ?? false, "Should be pull action")
        XCTAssertTrue(url?.absoluteString.contains(repoName) ?? false, "Should include repository name")
    }

    func testGenerateStatusURL_createsValidURL() async {
        // Given: Repository name
        let repoName = "test-repo"

        // When: Generate status URL
        let url = await sut.generateStatusURL(repository: repoName)

        // Then: URL should be valid and contain expected components
        XCTAssertNotNil(url, "URL should be generated")
        XCTAssertEqual(url?.scheme, "working-copy", "Scheme should be working-copy")
        XCTAssertTrue(url?.absoluteString.contains("x-callback-url") ?? false, "Should use x-callback-url")
        XCTAssertTrue(url?.absoluteString.contains("status") ?? false, "Should be status action")
        XCTAssertTrue(url?.absoluteString.contains(repoName) ?? false, "Should include repository name")
    }

    // MARK: - Callback URL Tests

    func testGenerateCallbackURLs_includesSuccessAndError() async {
        // Given: Repository name
        let repoName = "test-repo"

        // When: Generate commit URL (which should include callbacks)
        let url = await sut.generateCommitURL(repository: repoName, message: "test", files: [])

        // Then: URL should include success and error callback URLs
        XCTAssertNotNil(url, "URL should be generated")
        XCTAssertTrue(url?.absoluteString.contains("x-success") ?? false, "Should include success callback")
        XCTAssertTrue(url?.absoluteString.contains("x-error") ?? false, "Should include error callback")
        XCTAssertTrue(url?.absoluteString.contains("commonplacebook") ?? false, "Should use app's URL scheme")
    }

    // MARK: - Repository Path Tests

    func testOpenRepository_generatesValidURL() async {
        // Given: Repository name
        let repoName = "test-repo"

        // When: Generate open repository URL
        let url = await sut.generateOpenRepositoryURL(repository: repoName)

        // Then: URL should be valid
        XCTAssertNotNil(url, "URL should be generated")
        XCTAssertEqual(url?.scheme, "working-copy", "Scheme should be working-copy")
        XCTAssertTrue(url?.absoluteString.contains(repoName) ?? false, "Should include repository name")
    }
}
#endif
