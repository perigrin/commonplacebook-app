// ABOUTME: Tests for iOS git setup wizard using Working Copy
// ABOUTME: Verifies wizard step navigation and Working Copy integration

import XCTest
import SwiftUI
@testable import Commonplace_Book

#if os(iOS)
final class GitSetupViewiOSTests: XCTestCase {

    // MARK: - Setup Step Tests

    func testSetupStep_allCases() {
        // Given/When: All setup steps
        let steps = GitSetupViewiOS.SetupStep.allCases

        // Then: Should have all expected steps
        XCTAssertEqual(steps.count, 6, "Should have 6 setup steps")
        XCTAssertTrue(steps.contains(.welcome), "Should include welcome step")
        XCTAssertTrue(steps.contains(.installWorkingCopy), "Should include install Working Copy step")
        XCTAssertTrue(steps.contains(.configureRepository), "Should include configure repository step")
        XCTAssertTrue(steps.contains(.cloneRepository), "Should include clone repository step")
        XCTAssertTrue(steps.contains(.testConnection), "Should include test connection step")
        XCTAssertTrue(steps.contains(.complete), "Should include complete step")
    }

    func testSetupStep_titles() {
        // Given: Each setup step
        // When/Then: Should have appropriate title
        XCTAssertEqual(GitSetupViewiOS.SetupStep.welcome.title, "Welcome to Git Integration")
        XCTAssertEqual(GitSetupViewiOS.SetupStep.installWorkingCopy.title, "Install Working Copy")
        XCTAssertEqual(GitSetupViewiOS.SetupStep.configureRepository.title, "Configure Repository")
        XCTAssertEqual(GitSetupViewiOS.SetupStep.cloneRepository.title, "Clone Repository")
        XCTAssertEqual(GitSetupViewiOS.SetupStep.testConnection.title, "Test Connection")
        XCTAssertEqual(GitSetupViewiOS.SetupStep.complete.title, "Setup Complete")
    }

    // MARK: - View Model Tests

    func testViewModel_initialState() {
        // When: Create view model
        let viewModel = GitSetupViewiOS.ViewModel()

        // Then: Should have initial state
        XCTAssertEqual(viewModel.currentStep, .welcome, "Should start at welcome step")
        XCTAssertTrue(viewModel.repositoryURL.isEmpty, "Repository URL should be empty")
        XCTAssertTrue(viewModel.repositoryName.isEmpty, "Repository name should be empty")
        XCTAssertFalse(viewModel.isWorkingCopyInstalled, "Working Copy detection should be false initially")
    }

    func testViewModel_repositoryURLValidation() {
        // Given: View model
        let viewModel = GitSetupViewiOS.ViewModel()

        // When: Set valid SSH URL
        viewModel.repositoryURL = "git@github.com:user/repo.git"

        // Then: Should be valid
        XCTAssertTrue(viewModel.isValidRepositoryURL, "SSH URL should be valid")

        // When: Set valid HTTPS URL
        viewModel.repositoryURL = "https://github.com/user/repo.git"

        // Then: Should be valid
        XCTAssertTrue(viewModel.isValidRepositoryURL, "HTTPS URL should be valid")

        // When: Set invalid URL
        viewModel.repositoryURL = "not a url"

        // Then: Should be invalid
        XCTAssertFalse(viewModel.isValidRepositoryURL, "Invalid URL should not be valid")
    }

    func testViewModel_repositoryNameExtraction() {
        // Given: View model with repository URL
        let viewModel = GitSetupViewiOS.ViewModel()

        // When: Set GitHub URL
        viewModel.repositoryURL = "git@github.com:user/my-notes.git"

        // Then: Should extract repository name
        viewModel.extractRepositoryName()
        XCTAssertEqual(viewModel.repositoryName, "my-notes", "Should extract repository name from URL")

        // When: Set HTTPS URL
        viewModel.repositoryURL = "https://github.com/user/another-repo.git"

        // Then: Should extract repository name
        viewModel.extractRepositoryName()
        XCTAssertEqual(viewModel.repositoryName, "another-repo", "Should extract repository name from HTTPS URL")
    }

    func testViewModel_canProceedFromStep() {
        // Given: View model
        let viewModel = GitSetupViewiOS.ViewModel()

        // Then: Should be able to proceed from welcome
        XCTAssertTrue(viewModel.canProceed(from: .welcome), "Should always allow proceeding from welcome")

        // When: Working Copy not installed
        viewModel.isWorkingCopyInstalled = false

        // Then: Should not proceed from install step
        XCTAssertFalse(viewModel.canProceed(from: .installWorkingCopy), "Should not proceed without Working Copy")

        // When: Working Copy installed
        viewModel.isWorkingCopyInstalled = true

        // Then: Should proceed from install step
        XCTAssertTrue(viewModel.canProceed(from: .installWorkingCopy), "Should proceed with Working Copy installed")

        // When: Repository not configured
        viewModel.repositoryURL = ""
        viewModel.repositoryName = ""

        // Then: Should not proceed from configure step
        XCTAssertFalse(viewModel.canProceed(from: .configureRepository), "Should not proceed without repository configuration")

        // When: Repository configured
        viewModel.repositoryURL = "git@github.com:user/repo.git"
        viewModel.repositoryName = "repo"

        // Then: Should proceed from configure step
        XCTAssertTrue(viewModel.canProceed(from: .configureRepository), "Should proceed with repository configured")
    }
}
#endif
