// ABOUTME: Tests for ErrorHandler managing centralized error handling and retry logic
// ABOUTME: Validates error propagation, retry mechanism, logging integration, and SwiftUI extensions

import XCTest
import Combine
@testable import Commonplace_Book

@MainActor
final class ErrorHandlerTests: XCTestCase {
    var errorHandler: ErrorHandler!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        errorHandler = ErrorHandler.shared
        cancellables = []

        // Clear any existing error
        errorHandler.clearError()
    }

    override func tearDown() {
        cancellables = nil
        errorHandler.clearError()
        errorHandler = nil
        super.tearDown()
    }

    // MARK: - Error Handling Tests

    func testHandleErrorSetsCurrentError() {
        // GIVEN a test error
        let testError = NSError(domain: "TestDomain", code: 100, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        // WHEN handling the error
        errorHandler.handle(testError)

        // THEN current error should be set
        // Wait briefly for async handling
        let expectation = XCTestExpectation(description: "Error set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.errorHandler.currentError)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testClearErrorRemovesCurrentError() {
        // GIVEN an error that has been handled
        let testError = AppError.general("Test error")
        errorHandler.handle(testError)

        // Wait for error to be set
        let setExpectation = XCTestExpectation(description: "Error set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            setExpectation.fulfill()
        }
        wait(for: [setExpectation], timeout: 1.0)

        // WHEN clearing the error
        errorHandler.clearError()

        // THEN current error should be nil
        XCTAssertNil(errorHandler.currentError)
    }

    func testErrorPublisherEmitsErrors() {
        // GIVEN subscription to error publisher
        var receivedErrors: [AppError] = []
        let expectation = XCTestExpectation(description: "Error published")

        errorHandler.errorPublisher
            .sink { error in
                receivedErrors.append(error)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // WHEN handling an error
        let testError = AppError.general("Test error")
        errorHandler.handle(testError)

        // THEN error should be published
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedErrors.count, 1)
        XCTAssertEqual(receivedErrors.first, testError)
    }

    // MARK: - AppError Conversion Tests

    func testConvertNetworkError() {
        // GIVEN a network error
        let networkError = NetworkError.noInternetConnection

        // WHEN converting to AppError
        let appError = AppError.from(networkError)

        // THEN should be network error type
        if case .network(let error) = appError {
            XCTAssertEqual(error.localizedDescription, networkError.localizedDescription)
        } else {
            XCTFail("Should convert to network error")
        }
    }

    func testConvertRepositoryError() {
        // GIVEN a repository error
        let repoError = RepositoryError.storageError("Test storage error")

        // WHEN converting to AppError
        let appError = AppError.from(repoError)

        // THEN should be repository error type
        if case .repository(let error) = appError {
            XCTAssertEqual(error.localizedDescription, repoError.localizedDescription)
        } else {
            XCTFail("Should convert to repository error")
        }
    }

    func testConvertUnknownError() {
        // GIVEN an unknown error type
        struct CustomError: Error {}
        let customError = CustomError()

        // WHEN converting to AppError
        let appError = AppError.from(customError)

        // THEN should be unknown error type
        if case .unknown = appError {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should convert to unknown error")
        }
    }

    func testConvertAppErrorReturnsItself() {
        // GIVEN an existing AppError
        let originalError = AppError.general("Test")

        // WHEN converting
        let converted = AppError.from(originalError)

        // THEN should return the same error
        XCTAssertEqual(converted, originalError)
    }

    // MARK: - Error Properties Tests

    func testNetworkErrorLogLevel() {
        // GIVEN different network errors
        let noInternetError = AppError.network(NetworkError.noInternetConnection)
        let serverError = AppError.network(NetworkError.serverError(statusCode: 500, message: "Server error"))
        let clientError = AppError.network(NetworkError.serverError(statusCode: 400, message: "Client error"))

        // THEN log levels should be appropriate
        XCTAssertEqual(noInternetError.logLevel, .warning)
        XCTAssertEqual(serverError.logLevel, .error)
        XCTAssertEqual(clientError.logLevel, .warning)
    }

    func testRepositoryErrorLogLevel() {
        // GIVEN repository error
        let error = AppError.repository(RepositoryError.storageError("Test"))

        // THEN should be error level
        XCTAssertEqual(error.logLevel, .error)
    }

    func testAuthenticationErrorLogLevel() {
        // GIVEN authentication error
        let error = AppError.authentication(.invalidCredentials)

        // THEN should be warning level
        XCTAssertEqual(error.logLevel, .warning)
    }

    func testValidationErrorLogLevel() {
        // GIVEN validation error
        let error = AppError.validation(.requiredFieldMissing("Email"))

        // THEN should be warning level
        XCTAssertEqual(error.logLevel, .warning)
    }

    // MARK: - Retry Logic Tests

    func testRetryableErrors() {
        // GIVEN various errors
        let retryableErrors: [AppError] = [
            .network(NetworkError.noInternetConnection),
            .network(NetworkError.timeoutError),
            .network(NetworkError.serverError(statusCode: 500, message: "Server error")),
            .repository(RepositoryError.storageError("Test")),
            .general("Test")
        ]

        // THEN all should be retryable
        for error in retryableErrors {
            XCTAssertTrue(error.isRetryable, "Error \(error) should be retryable")
        }
    }

    func testNonRetryableErrors() {
        // GIVEN various errors
        let nonRetryableErrors: [AppError] = [
            .authentication(.invalidCredentials),
            .validation(.requiredFieldMissing("Email")),
            .network(NetworkError.serverError(statusCode: 400, message: "Bad request"))
        ]

        // THEN none should be retryable
        for error in nonRetryableErrors {
            XCTAssertFalse(error.isRetryable, "Error \(error) should not be retryable")
        }
    }

    // MARK: - Recovery Suggestion Tests

    func testNetworkErrorRecoverySuggestions() {
        // GIVEN network errors
        let noInternet = AppError.network(NetworkError.noInternetConnection)
        let serverError = AppError.network(NetworkError.serverError(statusCode: 500, message: "Server error"))
        let clientError = AppError.network(NetworkError.serverError(statusCode: 400, message: "Client error"))
        let timeout = AppError.network(NetworkError.timeoutError)

        // THEN should have appropriate suggestions
        XCTAssertEqual(noInternet.recoverySuggestion, "Please check your internet connection and try again.")
        XCTAssertEqual(serverError.recoverySuggestion, "Please try again later.")
        XCTAssertEqual(clientError.recoverySuggestion, "Please check your input and try again.")
        XCTAssertEqual(timeout.recoverySuggestion, "The server is taking too long to respond. Please try again later.")
    }

    func testRepositoryErrorRecoverySuggestion() {
        // GIVEN repository error
        let error = AppError.repository(RepositoryError.storageError("Test"))

        // THEN should suggest restart
        XCTAssertEqual(error.recoverySuggestion, "Please try again. If the problem persists, restart the app.")
    }

    func testAuthenticationErrorRecoverySuggestion() {
        // GIVEN authentication error
        let error = AppError.authentication(.sessionExpired)

        // THEN should suggest login
        XCTAssertEqual(error.recoverySuggestion, "Please log in again.")
    }

    func testValidationErrorRecoverySuggestion() {
        // GIVEN validation error
        let error = AppError.validation(.invalidFormat("Email"))

        // THEN should suggest checking input
        XCTAssertEqual(error.recoverySuggestion, "Please check your input and try again.")
    }

    // MARK: - Error ID Tests

    func testErrorIDIsConsistent() {
        // GIVEN same error created twice
        let error1 = AppError.general("Test error")
        let error2 = AppError.general("Test error")

        // THEN IDs should be the same
        XCTAssertEqual(error1.id, error2.id)
    }

    func testDifferentErrorsHaveDifferentIDs() {
        // GIVEN different errors
        let error1 = AppError.general("Error 1")
        let error2 = AppError.general("Error 2")

        // THEN IDs should be different
        XCTAssertNotEqual(error1.id, error2.id)
    }

    // MARK: - AuthenticationError Tests

    func testAuthenticationErrorDescriptions() {
        // GIVEN various authentication errors
        let testCases: [(AuthenticationError, String)] = [
            (.invalidCredentials, "Invalid username or password."),
            (.sessionExpired, "Your session has expired. Please log in again."),
            (.notAuthenticated, "You need to be logged in to perform this action."),
            (.permissionDenied, "You don't have permission to perform this action."),
            (.biometricAuthenticationFailed, "Biometric authentication failed."),
            (.accountLocked, "Your account has been locked. Please contact support."),
            (.tokenExpired, "Your authentication token has expired. Please log in again."),
            (.tokenInvalid, "Your authentication token is invalid. Please log in again.")
        ]

        for (error, expectedDescription) in testCases {
            // THEN descriptions should match
            XCTAssertEqual(error.errorDescription, expectedDescription)
        }
    }

    // MARK: - ValidationError Tests

    func testValidationErrorDescriptions() {
        // GIVEN various validation errors
        let testCases: [(ValidationError, String)] = [
            (.requiredFieldMissing("Email"), "Email is required."),
            (.invalidFormat("Phone"), "Phone has an invalid format."),
            (.invalidLength("Password"), "Password has an invalid length."),
            (.invalidValue("Age"), "Age has an invalid value."),
            (.valuesDontMatch("Password"), "Password values don't match."),
            (.maxValueExceeded("Amount"), "Amount exceeds the maximum allowed value."),
            (.minValueNotMet("Quantity"), "Quantity is below the minimum required value.")
        ]

        for (error, expectedDescription) in testCases {
            // THEN descriptions should match
            XCTAssertEqual(error.errorDescription, expectedDescription)
        }
    }

    // MARK: - Result Extension Tests

    func testResultSuccessHandling() {
        // GIVEN a successful result
        let result: Result<String, Error> = .success("test value")
        var transformedValue: String?

        // WHEN handling with transform
        result.handleError(with: errorHandler) { value in
            transformedValue = value
        }

        // THEN transform should be called
        XCTAssertEqual(transformedValue, "test value")
        XCTAssertNil(errorHandler.currentError)
    }

    func testResultFailureHandling() {
        // GIVEN a failed result
        let testError = NSError(domain: "Test", code: 1)
        let result: Result<String, Error> = .failure(testError)
        var transformedValue: String?

        // WHEN handling
        result.handleError(with: errorHandler) { value in
            transformedValue = value
        }

        // THEN error should be handled
        XCTAssertNil(transformedValue)

        // Wait for async error handling
        let expectation = XCTestExpectation(description: "Error handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.errorHandler.currentError)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Publisher Extension Tests

    func testPublisherErrorHandling() {
        // GIVEN a publisher that will fail
        let publisher = Fail<String, Error>(error: NSError(domain: "Test", code: 1))
            .handleError(with: errorHandler)

        let expectation = XCTestExpectation(description: "Publisher completes")
        var receivedValues: [String] = []

        // WHEN subscribing
        publisher
            .sink(
                receiveCompletion: { _ in
                    expectation.fulfill()
                },
                receiveValue: { value in
                    receivedValues.append(value)
                }
            )
            .store(in: &cancellables)

        // THEN should complete without values
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 0)
    }

    func testPublisherSuccessHandling() {
        // GIVEN a successful publisher
        let publisher = Just("test value")
            .setFailureType(to: Error.self)
            .handleError(with: errorHandler)

        let expectation = XCTestExpectation(description: "Publisher completes")
        var receivedValues: [String] = []

        // WHEN subscribing
        publisher
            .sink(
                receiveCompletion: { _ in
                    expectation.fulfill()
                },
                receiveValue: { value in
                    receivedValues.append(value)
                }
            )
            .store(in: &cancellables)

        // THEN should receive value
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedValues.first, "test value")
    }

    // MARK: - Equality Tests

    func testAppErrorEquality() {
        // GIVEN same errors
        let error1 = AppError.general("Test")
        let error2 = AppError.general("Test")

        // THEN should be equal
        XCTAssertEqual(error1, error2)
    }

    func testAppErrorInequality() {
        // GIVEN different errors
        let error1 = AppError.general("Test 1")
        let error2 = AppError.general("Test 2")

        // THEN should not be equal
        XCTAssertNotEqual(error1, error2)
    }

    // MARK: - Localized Description Tests

    func testGeneralErrorDescription() {
        // GIVEN general error
        let error = AppError.general("Custom error message")

        // THEN description should match message
        XCTAssertEqual(error.localizedDescription, "Custom error message")
    }

    func testUnknownErrorDescription() {
        // GIVEN unknown error
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { "Custom error" }
        }
        let error = AppError.unknown(CustomError())

        // THEN description should include original error
        XCTAssertTrue(error.localizedDescription.contains("unexpected"))
        XCTAssertTrue(error.localizedDescription.contains("Custom error"))
    }

    // MARK: - Edge Cases

    func testHandleMultipleErrorsInSequence() {
        // GIVEN multiple errors
        let errors = [
            AppError.general("Error 1"),
            AppError.general("Error 2"),
            AppError.general("Error 3")
        ]

        // WHEN handling in sequence
        for error in errors {
            errorHandler.handle(error)
        }

        // THEN last error should be current
        let expectation = XCTestExpectation(description: "Errors handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(self.errorHandler.currentError, errors.last)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testClearErrorBeforeErrorIsSet() {
        // GIVEN no error
        // WHEN clearing error
        errorHandler.clearError()

        // THEN should not crash
        XCTAssertNil(errorHandler.currentError)
    }

    func testHandleNilWrappedError() {
        // GIVEN an optional error that is nil
        let optionalError: Error? = nil

        // WHEN handling if let unwraps
        if let error = optionalError {
            errorHandler.handle(error)
            XCTFail("Should not reach here")
        }

        // THEN no error should be set
        XCTAssertNil(errorHandler.currentError)
    }
}
