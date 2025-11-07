// ABOUTME: Tests for automatic metadata collection service
// ABOUTME: Covers device detection, timestamp generation, and location services

import XCTest
import CoreLocation
@testable import CommonplaceBook

final class MetadataCollectorTests: XCTestCase {

    var collector: MetadataCollector!

    override func setUp() async throws {
        try await super.setUp()
        collector = MetadataCollector()
    }

    override func tearDown() async throws {
        collector = nil
        try await super.tearDown()
    }

    // MARK: - Device Detection Tests

    func testGetCurrentDeviceReturnsNonEmptyString() async {
        // When
        let device = await collector.getCurrentDevice()

        // Then
        XCTAssertFalse(device.isEmpty, "Device name should not be empty")
        XCTAssertGreaterThan(device.count, 0, "Device name should have characters")
    }

    func testDeviceNameFormatIsCorrect() async {
        // When
        let device = await collector.getCurrentDevice()

        // Then
        // Device name should be a readable format like "iPhone 15 Pro", "iPad Pro", "Mac"
        // Not a technical identifier like "iPhone15,2"
        XCTAssertFalse(device.contains(","), "Device name should not contain technical identifiers")
        XCTAssertTrue(device.count > 3, "Device name should be descriptive")
    }

    func testGetCurrentDeviceIsConsistent() async {
        // When
        let device1 = await collector.getCurrentDevice()
        let device2 = await collector.getCurrentDevice()

        // Then
        XCTAssertEqual(device1, device2, "Device name should be consistent across calls")
    }

    // MARK: - Timestamp Tests

    func testGenerateTimestampReturnsRecentDate() async {
        // Given
        let beforeCall = Date()

        // When
        let timestamp = await collector.generateTimestamp()

        // Then
        let afterCall = Date()
        XCTAssertGreaterThanOrEqual(timestamp, beforeCall, "Timestamp should be after or equal to before time")
        XCTAssertLessThanOrEqual(timestamp, afterCall, "Timestamp should be before or equal to after time")
    }

    func testGenerateTimestampReturnsCurrentTime() async {
        // When
        let timestamp = await collector.generateTimestamp()
        let now = Date()

        // Then
        let difference = abs(now.timeIntervalSince(timestamp))
        XCTAssertLessThan(difference, 1.0, "Timestamp should be within 1 second of current time")
    }

    func testGenerateTimestampIsDifferentAcrossCalls() async {
        // When
        let timestamp1 = await collector.generateTimestamp()
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let timestamp2 = await collector.generateTimestamp()

        // Then
        XCTAssertNotEqual(timestamp1, timestamp2, "Timestamps should be different across calls")
        XCTAssertLessThan(timestamp1, timestamp2, "Later timestamp should be after earlier one")
    }

    // MARK: - Location Tests (Mocked)

    func testGetCurrentLocationReturnsNilWhenDenied() async {
        // Given
        let mockLocationManager = MockCLLocationManager(authorizationStatus: .denied)
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNil(location, "Location should be nil when permission denied")
    }

    func testGetCurrentLocationReturnsNilWhenRestricted() async {
        // Given
        let mockLocationManager = MockCLLocationManager(authorizationStatus: .restricted)
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNil(location, "Location should be nil when permission restricted")
    }

    func testGetCurrentLocationReturnsNilWhenNotDetermined() async {
        // Given
        let mockLocationManager = MockCLLocationManager(authorizationStatus: .notDetermined)
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNil(location, "Location should be nil when permission not determined")
    }

    func testGetCurrentLocationReturnsLocationWhenAuthorizedWhenInUse() async {
        // Given
        let mockCLLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let mockLocationManager = MockCLLocationManager(
            authorizationStatus: .authorizedWhenInUse,
            currentLocation: mockCLLocation
        )
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNotNil(location, "Location should not be nil when authorized")
        XCTAssertEqual(location?.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(location?.longitude, -122.4194, accuracy: 0.0001)
    }

    func testGetCurrentLocationReturnsLocationWhenAuthorizedAlways() async {
        // Given
        let mockCLLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let mockLocationManager = MockCLLocationManager(
            authorizationStatus: .authorizedAlways,
            currentLocation: mockCLLocation
        )
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNotNil(location, "Location should not be nil when authorized")
        XCTAssertEqual(location?.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(location?.longitude, -74.0060, accuracy: 0.0001)
    }

    func testLocationHasValidCoordinates() async {
        // Given
        let mockCLLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            altitude: 0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        let mockLocationManager = MockCLLocationManager(
            authorizationStatus: .authorizedWhenInUse,
            currentLocation: mockCLLocation
        )
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNotNil(location)
        if let location = location {
            // Valid latitude: -90 to 90
            XCTAssertGreaterThanOrEqual(location.latitude, -90.0)
            XCTAssertLessThanOrEqual(location.latitude, 90.0)

            // Valid longitude: -180 to 180
            XCTAssertGreaterThanOrEqual(location.longitude, -180.0)
            XCTAssertLessThanOrEqual(location.longitude, 180.0)
        }
    }

    func testLocationAccuracyIsPositive() async {
        // Given
        let mockCLLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 15.5,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        let mockLocationManager = MockCLLocationManager(
            authorizationStatus: .authorizedWhenInUse,
            currentLocation: mockCLLocation
        )
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNotNil(location)
        if let location = location {
            XCTAssertGreaterThan(location.accuracy, 0.0, "Accuracy should be positive")
            XCTAssertEqual(location.accuracy, 15.5, accuracy: 0.01)
        }
    }

    func testGetCurrentLocationReturnsNilWhenLocationUnavailable() async {
        // Given - Mock with authorized but no location available
        let mockLocationManager = MockCLLocationManager(
            authorizationStatus: .authorizedWhenInUse,
            currentLocation: nil
        )
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let location = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertNil(location, "Location should be nil when unavailable")
    }

    // MARK: - Permission Handling Tests

    func testRequestLocationPermissionWhenNotDetermined() async {
        // Given
        let mockLocationManager = MockCLLocationManager(authorizationStatus: .notDetermined)
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        _ = await collectorWithMock.getCurrentLocation()

        // Then
        XCTAssertTrue(mockLocationManager.didRequestPermission,
                      "Should request permission when not determined")
    }

    func testDoesNotBlockWhenLocationUnavailable() async {
        // Given
        let mockLocationManager = MockCLLocationManager(
            authorizationStatus: .authorizedWhenInUse,
            currentLocation: nil
        )
        let collectorWithMock = MetadataCollector(locationManager: mockLocationManager)

        // When
        let startTime = Date()
        let location = await collectorWithMock.getCurrentLocation()
        let endTime = Date()

        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertNil(location)
        XCTAssertLessThan(duration, 1.0, "Should not block for more than 1 second")
    }
}

// MARK: - Mock CLLocationManager

/// Mock location manager for testing
class MockCLLocationManager: LocationManagerProtocol {
    private let authStatus: CLAuthorizationStatus
    private let location: CLLocation?
    var didRequestPermission = false

    init(authorizationStatus: CLAuthorizationStatus, currentLocation: CLLocation? = nil) {
        self.authStatus = authorizationStatus
        self.location = currentLocation
    }

    func authorizationStatus() -> CLAuthorizationStatus {
        return authStatus
    }

    func requestWhenInUseAuthorization() {
        didRequestPermission = true
    }

    func location() -> CLLocation? {
        return location
    }
}
