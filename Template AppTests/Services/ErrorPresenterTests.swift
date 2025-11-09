// ABOUTME: Tests for error presenter service
// ABOUTME: Validates error presentation, categorization, and user-friendly messaging

import XCTest
@testable import Template_App

@MainActor
final class ErrorPresenterTests: XCTestCase {
    var presenter: ErrorPresenter!

    override func setUpWithError() throws {
        presenter = ErrorPresenter()
    }

    override func tearDownWithError() throws {
        presenter = nil
    }

    // MARK: - Presentation Tests

    func testPresentErrorSetsCurrentError() throws {
        // GIVEN an error
        let error = RepositoryError.noteNotFound(UUID())

        // WHEN presenting the error
        presenter.present(error)

        // THEN should set current error
        XCTAssertNotNil(presenter.currentError, "Should set current error")
        XCTAssertTrue(presenter.showError, "Should show error")
    }

    func testDismissErrorClearsState() throws {
        // GIVEN a presented error
        let error = RepositoryError.noteNotFound(UUID())
        presenter.present(error)
        XCTAssertNotNil(presenter.currentError)

        // WHEN dismissing
        presenter.dismiss()

        // THEN should clear state
        XCTAssertNil(presenter.currentError, "Should clear current error")
        XCTAssertFalse(presenter.showError, "Should hide error")
    }

    // MARK: - Error Categorization Tests

    func testRepositoryErrorCreatesDataError() throws {
        // GIVEN repository error
        let error = RepositoryError.storageError("Test error")

        // WHEN creating presentable error
        let presentable = PresentableError(from: error)

        // THEN should be categorized correctly
        XCTAssertEqual(presentable.title, "Data Error")
        XCTAssertNotNil(presentable.suggestion)
        XCTAssertEqual(presentable.category, .database)
    }

    func testPresentableErrorHasRecoveryAction() throws {
        // GIVEN repository error
        let error = RepositoryError.noteNotFound(UUID())

        // WHEN creating presentable error
        let presentable = PresentableError(from: error)

        // THEN should have retry action
        XCTAssertEqual(presentable.recoveryAction, .retry)
    }

    func testCustomPresentableError() throws {
        // WHEN creating custom error
        let presentable = PresentableError(
            title: "Custom Error",
            message: "Custom message",
            suggestion: "Try this",
            category: .network,
            recoveryAction: .openSettings
        )

        // THEN should have all properties
        XCTAssertEqual(presentable.title, "Custom Error")
        XCTAssertEqual(presentable.message, "Custom message")
        XCTAssertEqual(presentable.suggestion, "Try this")
        XCTAssertEqual(presentable.category, .network)
        XCTAssertEqual(presentable.recoveryAction, .openSettings)
    }

    // MARK: - Recovery Action Tests

    func testRecoveryActionLabels() throws {
        XCTAssertEqual(RecoveryAction.retry.label, "Try Again")
        XCTAssertEqual(RecoveryAction.openSettings.label, "Open Settings")
        XCTAssertEqual(RecoveryAction.contact.label, "Contact Support")
        XCTAssertEqual(RecoveryAction.dismiss.label, "OK")
    }
}
