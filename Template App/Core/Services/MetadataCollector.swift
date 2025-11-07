// ABOUTME: Service for automatic metadata collection (device, timestamp, location)
// ABOUTME: Provides device name, current timestamp, and optional location with permission handling

import Foundation
import CoreLocation

/// Service for collecting note metadata automatically
actor MetadataCollector {

    private let locationManager: LocationManagerProtocol

    /// Initialize with optional custom location manager (for testing)
    init(locationManager: LocationManagerProtocol? = nil) {
        self.locationManager = locationManager ?? ProductionLocationManager()
    }

    // MARK: - Device Detection

    /// Get the current device name
    /// - Returns: Human-readable device name (e.g., "iPhone 15 Pro", "iPad Air", "Mac")
    func getCurrentDevice() -> String {
        return DeviceInfo.getCurrentDeviceName()
    }

    // MARK: - Timestamp Generation

    /// Generate current timestamp
    /// - Returns: Current date and time
    func generateTimestamp() -> Date {
        return Date()
    }

    // MARK: - Location Services

    /// Get current location if permission granted
    /// - Returns: Location with coordinates and accuracy, or nil if unavailable/denied
    func getCurrentLocation() async -> Location? {
        let authStatus = locationManager.authorizationStatus()

        // Handle authorization states
        switch authStatus {
        case .notDetermined:
            // Request permission but don't wait - return nil for this call
            locationManager.requestWhenInUseAuthorization()
            return nil

        case .denied, .restricted:
            // Permission explicitly denied or restricted
            return nil

        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted - get location
            guard let clLocation = locationManager.location() else {
                // Location not available (GPS off, indoors, etc.)
                return nil
            }

            // Convert CLLocation to our Location model
            return Location(
                latitude: clLocation.coordinate.latitude,
                longitude: clLocation.coordinate.longitude,
                accuracy: clLocation.horizontalAccuracy
            )

        @unknown default:
            // Future authorization states - default to denying
            return nil
        }
    }
}
