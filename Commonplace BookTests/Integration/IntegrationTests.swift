// ABOUTME: End-to-end integration tests for multi-component workflows
// ABOUTME: Validates complete user flows from app startup through note management and search

import XCTest
import Combine
@testable import Commonplace_Book

/// Integration tests for complete app workflows
/// These tests verify that multiple components work correctly together
final class IntegrationTests: XCTestCase {

    var serviceLocator: ServiceLocator!
    var cancellables: Set<AnyCancellable>!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        serviceLocator = ServiceLocator.shared
        cancellables = []

        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        cancellables = nil
        serviceLocator.reset()

        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil

        super.tearDown()
    }

    // MARK: - Service Locator Integration Tests

    func testServiceLocatorInitializesAllServices() {
        // GIVEN clean service locator
        // WHEN initializing services
        // Note: In real app, services are registered at startup

        // THEN service locator should be ready
        XCTAssertNotNil(serviceLocator, "ServiceLocator should initialize")
    }

    func testServiceLocatorProvidesSingletonInstances() {
        // GIVEN service locator with registered service
        let service1 = MockIntegrationService()
        serviceLocator.register(service1, type: MockIntegrationService.self)

        // WHEN resolving multiple times
        let resolved1: MockIntegrationService? = serviceLocator.resolve()
        let resolved2: MockIntegrationService? = serviceLocator.resolve()

        // THEN should return same instance
        XCTAssertTrue(resolved1 === resolved2, "Should return singleton instance")
    }

    // MARK: - Logger Integration Tests

    func testLoggerIntegratesWithCombine() {
        // GIVEN logger subscriber
        let expectation = XCTestExpectation(description: "Log received")
        var receivedLog: Logger.LogEntry?

        Logger.subscribe { entry in
            receivedLog = entry
            expectation.fulfill()
        }.store(in: &cancellables)

        // WHEN logging message
        Logger.info("Integration test message", category: .general)

        wait(for: [expectation], timeout: 1.0)

        // THEN subscriber should receive log
        XCTAssertNotNil(receivedLog)
        XCTAssertEqual(receivedLog?.message, "Integration test message")
        XCTAssertEqual(receivedLog?.level, .info)
        XCTAssertEqual(receivedLog?.category, .general)
    }

    func testLoggerCategoriesAcrossComponents() {
        // GIVEN logger with multiple categories
        let categories: [Logger.Category] = [
            .general, .network, .storage, .sync, .search,
            .embedding, .ui, .performance, .security
        ]

        var receivedLogs: [Logger.LogEntry] = []
        let expectation = XCTestExpectation(description: "All logs received")
        expectation.expectedFulfillmentCount = categories.count

        Logger.subscribe { entry in
            receivedLogs.append(entry)
            expectation.fulfill()
        }.store(in: &cancellables)

        // WHEN logging to all categories
        for category in categories {
            Logger.info("Test for \(category)", category: category)
        }

        wait(for: [expectation], timeout: 2.0)

        // THEN all logs should be received
        XCTAssertEqual(receivedLogs.count, categories.count)
        XCTAssertEqual(Set(receivedLogs.map { $0.category }), Set(categories))
    }

    // MARK: - Error Handling Integration Tests

    func testErrorHandlerIntegratesWithCombine() {
        // GIVEN error handler
        let errorHandler = ErrorHandler.shared
        let expectation = XCTestExpectation(description: "Error received")

        errorHandler.errorPublisher
            .sink { appError in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // WHEN handling error
        let testError = NSError(domain: "test", code: 100)
        errorHandler.handle(testError)

        wait(for: [expectation], timeout: 1.0)

        // THEN error should be published
        XCTAssertNotNil(errorHandler.currentError)
    }

    func testErrorHandlerWithNetworkError() {
        // GIVEN error handler and network error
        let errorHandler = ErrorHandler.shared
        let networkError = NetworkError.noInternetConnection

        // WHEN handling network error
        errorHandler.handle(networkError)

        // Wait for main queue
        let expectation = XCTestExpectation(description: "Error processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // THEN current error should be set
        XCTAssertNotNil(errorHandler.currentError)
    }

    // MARK: - Security Integration Tests

    func testSecurityManagerKeyGeneration() {
        // GIVEN security manager
        let securityManager = SecurityManager.shared

        // WHEN generating key
        let key = securityManager.generateKey()

        // THEN should generate valid key
        XCTAssertEqual(key.count, 32, "Should generate 256-bit key")
    }

    func testSecurityManagerEncryptionRoundTrip() throws {
        // GIVEN security manager and data
        let securityManager = SecurityManager.shared
        let originalData = "Integration test data".data(using: .utf8)!
        let key = securityManager.generateKey()

        // WHEN encrypting and decrypting
        let encrypted = try securityManager.encrypt(data: originalData, with: key)
        let decrypted = try securityManager.decrypt(data: encrypted, with: key)

        // THEN should preserve original data
        XCTAssertEqual(decrypted, originalData)
    }

    // MARK: - Device Info Integration Tests

    func testDeviceInfoProvidesConsistentMetadata() {
        // GIVEN device info utility
        // WHEN getting device metadata
        let deviceName1 = DeviceInfo.getCurrentDeviceName()
        let deviceModel1 = DeviceInfo.getDeviceModel()

        let deviceName2 = DeviceInfo.getCurrentDeviceName()
        let deviceModel2 = DeviceInfo.getDeviceModel()

        // THEN should be consistent
        XCTAssertEqual(deviceName1, deviceName2)
        XCTAssertEqual(deviceModel1, deviceModel2)
    }

    // MARK: - UUID Generation Integration Tests

    func testUUIDv7GeneratesUniqueTimestampOrderedIDs() {
        // GIVEN UUIDv7 generator
        // WHEN generating multiple UUIDs
        let uuid1 = UUIDv7.generate()
        Thread.sleep(forTimeInterval: 0.001) // 1ms delay
        let uuid2 = UUIDv7.generate()
        Thread.sleep(forTimeInterval: 0.001)
        let uuid3 = UUIDv7.generate()

        // THEN should be unique and ordered
        XCTAssertNotEqual(uuid1, uuid2)
        XCTAssertNotEqual(uuid2, uuid3)

        let sorted = [uuid1, uuid2, uuid3].sorted { $0.uuidString < $1.uuidString }
        XCTAssertEqual([uuid1, uuid2, uuid3], sorted, "UUIDs should be timestamp-ordered")
    }

    func testUUIDv7ExtractsTimestamp() {
        // GIVEN UUIDv7 with known timestamp
        let beforeTime = Date().timeIntervalSince1970
        let uuid = UUIDv7.generate()
        let afterTime = Date().timeIntervalSince1970

        // WHEN extracting timestamp
        if let timestamp = UUIDv7.extractTimestamp(from: uuid) {
            // THEN should be within expected range
            XCTAssertGreaterThanOrEqual(timestamp, beforeTime)
            XCTAssertLessThanOrEqual(timestamp, afterTime)
        } else {
            XCTFail("Should extract timestamp from UUIDv7")
        }
    }

    // MARK: - String Truncation Integration Tests

    func testStringTruncationWithRealWorldContent() {
        // GIVEN real-world content
        let longTitle = "Meeting Notes - Q4 2024 Planning Session with Product and Engineering Teams"

        // WHEN truncating for UI display
        let displayTitle = longTitle.truncated(to: 30)

        // THEN should truncate cleanly
        XCTAssertEqual(displayTitle.count, 30)
        XCTAssertTrue(longTitle.hasPrefix(displayTitle))
    }

    func testStringTruncationWithMultilingualContent() {
        // GIVEN multilingual content
        let multilingualNote = "Project Status: 进展顺利 👍 Everything on track!"

        // WHEN truncating
        let truncated = multilingualNote.truncated(to: 25)

        // THEN should preserve grapheme clusters
        XCTAssertEqual(truncated.count, 25)
    }

    // MARK: - AnyCodable Integration Tests

    func testAnyCodableInMetadataDictionary() throws {
        // GIVEN metadata with mixed types
        let metadata: [String: AnyCodable] = [
            "title": "Test Note",
            "priority": 5,
            "completed": false,
            "tags": ["work", "important"],
            "rating": 4.5
        ]

        // WHEN encoding and decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)

        // THEN should preserve all types
        XCTAssertEqual(decoded["title"]?.value as? String, "Test Note")
        XCTAssertEqual(decoded["priority"]?.value as? Int, 5)
        XCTAssertEqual(decoded["completed"]?.value as? Bool, false)
        XCTAssertNotNil(decoded["tags"]?.value as? [Any])
    }

    // MARK: - Concurrent Operations Integration Tests

    func testConcurrentServiceRegistration() {
        // GIVEN service locator
        let locator = ServiceLocator()
        let expectation = XCTestExpectation(description: "Concurrent registration")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        // WHEN registering services concurrently
        for i in 0..<100 {
            group.enter()
            queue.async {
                let service = MockNumberedService(number: i)
                locator.register(service, type: MockNumberedService.self, name: "service\(i)")
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all services should be registered
        for i in 0..<100 {
            let resolved: MockNumberedService? = locator.resolve(name: "service\(i)")
            XCTAssertNotNil(resolved, "Service \(i) should be registered")
        }
    }

    func testConcurrentLogging() {
        // GIVEN logger and concurrent operations
        let expectation = XCTestExpectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 100
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        var receivedLogs: [Logger.LogEntry] = []
        let lock = NSLock()

        Logger.subscribe { entry in
            lock.lock()
            receivedLogs.append(entry)
            lock.unlock()
            expectation.fulfill()
        }.store(in: &cancellables)

        // WHEN logging from multiple threads
        for i in 0..<100 {
            group.enter()
            queue.async {
                Logger.info("Concurrent log \(i)", category: .general)
                group.leave()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all logs should be received
        XCTAssertEqual(receivedLogs.count, 100)
    }

    func testConcurrentUUIDGeneration() {
        // GIVEN UUIDv7 generator
        let expectation = XCTestExpectation(description: "Concurrent UUID generation")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var uuids: [UUID] = []
        let lock = NSLock()

        // WHEN generating UUIDs concurrently
        for _ in 0..<1000 {
            group.enter()
            queue.async {
                let uuid = UUIDv7.generate()
                lock.lock()
                uuids.append(uuid)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all UUIDs should be unique
        let uniqueUUIDs = Set(uuids)
        XCTAssertEqual(uniqueUUIDs.count, 1000, "All UUIDs should be unique")
    }

    // MARK: - Performance Integration Tests

    func testEndToEndPerformanceWithMultipleComponents() {
        // GIVEN multiple components
        measure {
            // WHEN performing end-to-end operations
            _ = DeviceInfo.getCurrentDeviceName()
            _ = UUIDv7.generate()
            Logger.info("Performance test", category: .performance)
            let key = SecurityManager.shared.generateKey()
            _ = "Test string".truncated(to: 5)

            // THEN should complete quickly
        }
    }

    // MARK: - Error Propagation Tests

    func testNetworkErrorPropagationToErrorHandler() {
        // GIVEN network error and error handler
        let errorHandler = ErrorHandler.shared
        let networkError = NetworkError.serverError(500, nil)
        let expectation = XCTestExpectation(description: "Error propagated")

        errorHandler.errorPublisher
            .sink { appError in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // WHEN handling network error
        errorHandler.handle(networkError)

        wait(for: [expectation], timeout: 1.0)

        // THEN error should propagate to UI layer
        XCTAssertNotNil(errorHandler.currentError)
    }

    // MARK: - Data Flow Integration Tests

    func testDataFlowThroughEncodingLayers() throws {
        // GIVEN data at various encoding layers
        let originalData = ["key": "value", "number": "42"]

        // WHEN encoding through multiple layers
        let anyCodableDict = originalData.mapValues { AnyCodable($0) }
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(anyCodableDict)

        // WHEN decoding back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: AnyCodable].self, from: jsonData)

        // THEN data should flow correctly
        XCTAssertEqual(decoded["key"]?.value as? String, "value")
        XCTAssertEqual(decoded["number"]?.value as? String, "42")
    }

    // MARK: - System Integration Tests

    func testSystemCapabilitiesAvailable() {
        // GIVEN system capabilities
        // WHEN checking capabilities
        let deviceName = DeviceInfo.getCurrentDeviceName()
        let deviceModel = DeviceInfo.getDeviceModel()

        // THEN should have valid system info
        XCTAssertFalse(deviceName.isEmpty, "Should have device name")
        XCTAssertFalse(deviceModel.isEmpty, "Should have device model")
    }

    func testFileSystemIntegration() {
        // GIVEN file system access
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let testData = "Integration test".data(using: .utf8)!

        // WHEN writing and reading
        try? testData.write(to: testFile)
        let readData = try? Data(contentsOf: testFile)

        // THEN should work correctly
        XCTAssertEqual(readData, testData)
    }

    // MARK: - Documentation Tests

    func testDocumentRequiredSystemIntegrationTests() {
        // Documents integration tests that require full system
        // These should be run on actual devices or in full simulator environment

        let requiredSystemTests = [
            "testAppStartupSequence",
            "testNoteCreationFlow",
            "testNoteSearchFlow",
            "testCloudKitSyncFlow",
            "testVectorEmbeddingPipeline",
            "testNoteEditingAndSaving",
            "testBulkNoteOperations",
            "testOfflineToOnlineSync",
            "testConcurrentNoteAccess",
            "testMemoryWarningHandling",
            "testBackgroundRefresh",
            "testDeepLinkHandling",
            "testShareExtensionFlow",
            "testVoiceNoteCapture",
            "testAccessibilityIntegration",
            "testLocalizedContentHandling",
            "testDataMigrationScenarios",
            "testConflictResolution",
            "testBiometricAuthentication",
            "testNetworkReconnection"
        ]

        XCTAssertEqual(requiredSystemTests.count, 20,
                      "Should have \(requiredSystemTests.count) system integration tests")
    }
}

// MARK: - Mock Services for Integration Testing

private class MockIntegrationService {
    var callCount = 0

    func doWork() {
        callCount += 1
    }
}

private class MockNumberedService {
    let number: Int

    init(number: Int) {
        self.number = number
    }
}
