// ABOUTME: Tests for Logger centralized logging system
// ABOUTME: Validates log levels, categories, formatting, filtering, and Combine publisher

import XCTest
import Combine
@testable import Commonplace_Book

final class LoggerTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    var receivedLogs: [Logger.LogEntry]!

    override func setUp() {
        super.setUp()
        cancellables = []
        receivedLogs = []
    }

    override func tearDown() {
        cancellables = nil
        receivedLogs = nil
        super.tearDown()
    }

    // MARK: - Log Level Tests

    func testLogLevelComparison() {
        // GIVEN log levels
        let debug = Logger.Level.debug
        let info = Logger.Level.info
        let warning = Logger.Level.warning
        let error = Logger.Level.error
        let critical = Logger.Level.critical

        // THEN comparison should work correctly
        XCTAssertTrue(debug < info)
        XCTAssertTrue(info < warning)
        XCTAssertTrue(warning < error)
        XCTAssertTrue(error < critical)
        XCTAssertFalse(critical < error)
    }

    func testLogLevelRawValues() {
        // GIVEN log levels
        // THEN raw values should be in ascending order
        XCTAssertEqual(Logger.Level.debug.rawValue, 0)
        XCTAssertEqual(Logger.Level.info.rawValue, 1)
        XCTAssertEqual(Logger.Level.warning.rawValue, 2)
        XCTAssertEqual(Logger.Level.error.rawValue, 3)
        XCTAssertEqual(Logger.Level.critical.rawValue, 4)
    }

    func testLogLevelDescriptions() {
        // GIVEN log levels
        let testCases: [(Logger.Level, String)] = [
            (.debug, "DEBUG"),
            (.info, "INFO"),
            (.warning, "WARNING"),
            (.error, "ERROR"),
            (.critical, "CRITICAL")
        ]

        for (level, expectedDescription) in testCases {
            // THEN descriptions should match
            XCTAssertEqual(level.description, expectedDescription)
        }
    }

    func testLogLevelOSLogTypes() {
        // GIVEN log levels
        // THEN OSLogType should be appropriate
        XCTAssertEqual(Logger.Level.debug.osLogType, .debug)
        XCTAssertEqual(Logger.Level.info.osLogType, .info)
        XCTAssertEqual(Logger.Level.warning.osLogType, .default)
        XCTAssertEqual(Logger.Level.error.osLogType, .error)
        XCTAssertEqual(Logger.Level.critical.osLogType, .fault)
    }

    // MARK: - Category Tests

    func testAllCategoriesExist() {
        // GIVEN all categories
        let categories = Logger.Category.allCases

        // THEN should have expected categories
        XCTAssertTrue(categories.contains(.general))
        XCTAssertTrue(categories.contains(.network))
        XCTAssertTrue(categories.contains(.database))
        XCTAssertTrue(categories.contains(.ui))
        XCTAssertTrue(categories.contains(.analytics))
        XCTAssertTrue(categories.contains(.user))
        XCTAssertTrue(categories.contains(.security))
        XCTAssertTrue(categories.contains(.performance))
        XCTAssertTrue(categories.contains(.embedding))
    }

    func testCategoryRawValues() {
        // GIVEN categories
        // THEN raw values should match expected strings
        XCTAssertEqual(Logger.Category.general.rawValue, "general")
        XCTAssertEqual(Logger.Category.network.rawValue, "network")
        XCTAssertEqual(Logger.Category.database.rawValue, "database")
        XCTAssertEqual(Logger.Category.ui.rawValue, "ui")
        XCTAssertEqual(Logger.Category.analytics.rawValue, "analytics")
        XCTAssertEqual(Logger.Category.user.rawValue, "user")
        XCTAssertEqual(Logger.Category.security.rawValue, "security")
        XCTAssertEqual(Logger.Category.performance.rawValue, "performance")
        XCTAssertEqual(Logger.Category.embedding.rawValue, "embedding")
    }

    // MARK: - Log Publisher Tests

    func testLogPublisherEmitsMessages() {
        // GIVEN subscription to log publisher
        let expectation = XCTestExpectation(description: "Log published")

        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
            expectation.fulfill()
        }
        .store(in: &cancellables)

        // WHEN logging a message
        Logger.info("Test message", category: .general)

        // THEN log should be published
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedLogs.count, 1)
        XCTAssertEqual(receivedLogs.first?.message, "Test message")
    }

    func testLogPublisherReceivesMultipleMessages() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging multiple messages
        Logger.info("Message 1")
        Logger.warning("Message 2")
        Logger.error("Message 3")

        // THEN all should be received
        // Wait briefly for async logging
        let expectation = XCTestExpectation(description: "Logs published")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertGreaterThanOrEqual(receivedLogs.count, 3)
    }

    // MARK: - Logging Method Tests

    func testDebugLogging() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging debug message
        Logger.debug("Debug message", category: .general)

        // Wait for log
        let expectation = XCTestExpectation(description: "Debug logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should have correct level
        let debugLogs = receivedLogs.filter { $0.level == .debug }
        XCTAssertGreaterThan(debugLogs.count, 0)
    }

    func testInfoLogging() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging info message
        Logger.info("Info message", category: .network)

        // Wait for log
        let expectation = XCTestExpectation(description: "Info logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should have correct level and category
        let infoLogs = receivedLogs.filter { $0.level == .info && $0.category == .network }
        XCTAssertGreaterThan(infoLogs.count, 0)
    }

    func testWarningLogging() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging warning
        Logger.warning("Warning message", category: .database)

        // Wait for log
        let expectation = XCTestExpectation(description: "Warning logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should have correct level
        let warningLogs = receivedLogs.filter { $0.level == .warning }
        XCTAssertGreaterThan(warningLogs.count, 0)
    }

    func testErrorLogging() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging error
        Logger.error("Error message", category: .security)

        // Wait for log
        let expectation = XCTestExpectation(description: "Error logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should have correct level
        let errorLogs = receivedLogs.filter { $0.level == .error }
        XCTAssertGreaterThan(errorLogs.count, 0)
    }

    func testCriticalLogging() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging critical
        Logger.critical("Critical message", category: .general)

        // Wait for log
        let expectation = XCTestExpectation(description: "Critical logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should have correct level
        let criticalLogs = receivedLogs.filter { $0.level == .critical }
        XCTAssertGreaterThan(criticalLogs.count, 0)
    }

    // MARK: - Error Object Logging Tests

    func testLogErrorObject() {
        // GIVEN an error object
        let error = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])

        // AND subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging the error
        Logger.log(error: error, category: .network)

        // Wait for log
        let expectation = XCTestExpectation(description: "Error logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN log should contain error details
        let errorLogs = receivedLogs.filter { $0.message.contains("Not found") }
        XCTAssertGreaterThan(errorLogs.count, 0)

        if let log = errorLogs.first {
            XCTAssertTrue(log.message.contains("Code: 404"))
            XCTAssertTrue(log.message.contains("Domain: TestDomain"))
        }
    }

    // MARK: - Performance Measurement Tests

    func testMeasureBlockExecution() {
        // GIVEN a block to measure
        var executed = false

        // WHEN measuring
        let result = Logger.measure("Test operation") {
            executed = true
            return "result"
        }

        // THEN block should execute and return result
        XCTAssertTrue(executed)
        XCTAssertEqual(result, "result")
    }

    func testMeasureLogsPerformanceMessage() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN measuring an operation
        Logger.measure("Test operation", category: .performance) {
            // Simulate work
            Thread.sleep(forTimeInterval: 0.01)
        }

        // Wait for log
        let expectation = XCTestExpectation(description: "Performance logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should log with duration
        let perfLogs = receivedLogs.filter { $0.category == .performance }
        XCTAssertGreaterThan(perfLogs.count, 0)

        if let log = perfLogs.first {
            XCTAssertTrue(log.message.contains("completed in"))
            XCTAssertTrue(log.message.contains("ms"))
        }
    }

    func testMeasureThrowingBlockPreservesError() {
        // GIVEN a throwing block
        struct TestError: Error {}

        // WHEN measuring
        // THEN error should be thrown
        XCTAssertThrowsError(try Logger.measure("Failing operation") {
            throw TestError()
        })
    }

    // MARK: - Log Entry Tests

    func testLogEntryContainsMetadata() {
        // GIVEN subscription
        var capturedEntry: Logger.LogEntry?

        Logger.subscribe { entry in
            capturedEntry = entry
        }
        .store(in: &cancellables)

        // WHEN logging
        Logger.info("Test message", category: .database)

        // Wait for log
        let expectation = XCTestExpectation(description: "Entry captured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN entry should have metadata
        XCTAssertNotNil(capturedEntry)
        XCTAssertEqual(capturedEntry?.message, "Test message")
        XCTAssertEqual(capturedEntry?.level, .info)
        XCTAssertEqual(capturedEntry?.category, .database)
        XCTAssertNotNil(capturedEntry?.timestamp)
        XCTAssertFalse(capturedEntry?.file.isEmpty ?? true)
        XCTAssertFalse(capturedEntry?.function.isEmpty ?? true)
        XCTAssertGreaterThan(capturedEntry?.line ?? 0, 0)
    }

    func testLogEntryFormattedString() {
        // GIVEN a log entry
        let entry = Logger.LogEntry(
            message: "Test message",
            level: .info,
            category: .general,
            file: "/path/to/TestFile.swift",
            function: "testFunction()",
            line: 42,
            timestamp: Date()
        )

        // WHEN getting formatted string
        let formatted = entry.formattedString

        // THEN should contain all components
        XCTAssertTrue(formatted.contains("INFO"))
        XCTAssertTrue(formatted.contains("general"))
        XCTAssertTrue(formatted.contains("TestFile.swift"))
        XCTAssertTrue(formatted.contains("42"))
        XCTAssertTrue(formatted.contains("testFunction()"))
        XCTAssertTrue(formatted.contains("Test message"))
    }

    func testLogEntryFormattedStringWithISO8601Timestamp() {
        // GIVEN a log entry
        let timestamp = Date()
        let entry = Logger.LogEntry(
            message: "Test",
            level: .info,
            category: .general,
            file: "/test.swift",
            function: "test()",
            line: 1,
            timestamp: timestamp
        )

        // WHEN formatting
        let formatted = entry.formattedString

        // THEN should contain ISO8601 timestamp
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedTimestamp = dateFormatter.string(from: timestamp)

        XCTAssertTrue(formatted.contains(expectedTimestamp))
    }

    // MARK: - Minimum Log Level Tests

    func testMinimumLogLevelFiltersLogs() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // Save original minimum level
        let originalMinLevel = Logger.minimumLogLevel

        // WHEN setting minimum level to warning
        Logger.minimumLogLevel = .warning

        // AND logging at various levels
        Logger.debug("Debug") // Should be filtered
        Logger.info("Info")   // Should be filtered
        Logger.warning("Warning") // Should pass
        Logger.error("Error") // Should pass

        // Wait for logs
        let expectation = XCTestExpectation(description: "Logs filtered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN only warning and above should be logged
        XCTAssertFalse(receivedLogs.contains { $0.message == "Debug" })
        XCTAssertFalse(receivedLogs.contains { $0.message == "Info" })
        XCTAssertTrue(receivedLogs.contains { $0.message == "Warning" })
        XCTAssertTrue(receivedLogs.contains { $0.message == "Error" })

        // Restore original minimum level
        Logger.minimumLogLevel = originalMinLevel
    }

    // MARK: - Multiple Subscribers Tests

    func testMultipleSubscribersReceiveLogs() {
        // GIVEN multiple subscribers
        var logs1: [Logger.LogEntry] = []
        var logs2: [Logger.LogEntry] = []

        Logger.subscribe { entry in
            logs1.append(entry)
        }
        .store(in: &cancellables)

        Logger.subscribe { entry in
            logs2.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging
        Logger.info("Shared message")

        // Wait for logs
        let expectation = XCTestExpectation(description: "Subscribers notified")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN both should receive the log
        XCTAssertTrue(logs1.contains { $0.message == "Shared message" })
        XCTAssertTrue(logs2.contains { $0.message == "Shared message" })
    }

    // MARK: - Edge Cases

    func testLogEmptyMessage() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging empty message
        Logger.info("", category: .general)

        // Wait for log
        let expectation = XCTestExpectation(description: "Empty logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should still log
        XCTAssertTrue(receivedLogs.contains { $0.message == "" })
    }

    func testLogVeryLongMessage() {
        // GIVEN a very long message
        let longMessage = String(repeating: "A", count: 10000)

        // AND subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging
        Logger.info(longMessage)

        // Wait for log
        let expectation = XCTestExpectation(description: "Long message logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should handle long messages
        XCTAssertTrue(receivedLogs.contains { $0.message.count == 10000 })
    }

    func testLogSpecialCharacters() {
        // GIVEN message with special characters
        let message = "Test !@#$%^&*()_+-=[]{}|;':\",./<>?`~ 世界 🌍"

        // AND subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging
        Logger.info(message)

        // Wait for log
        let expectation = XCTestExpectation(description: "Special chars logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN should preserve special characters
        XCTAssertTrue(receivedLogs.contains { $0.message == message })
    }

    func testConcurrentLogging() {
        // GIVEN subscription
        Logger.subscribe { entry in
            self.receivedLogs.append(entry)
        }
        .store(in: &cancellables)

        // WHEN logging from multiple threads
        let expectation = XCTestExpectation(description: "Concurrent logging")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0..<100 {
            group.enter()
            queue.async {
                Logger.info("Message \(i)")
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all logs should be received
        // Allow some time for async processing
        let finalExpectation = XCTestExpectation(description: "Logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            finalExpectation.fulfill()
        }
        wait(for: [finalExpectation], timeout: 2.0)

        // Should have received most/all logs (allow for timing)
        XCTAssertGreaterThan(receivedLogs.count, 50)
    }
}
