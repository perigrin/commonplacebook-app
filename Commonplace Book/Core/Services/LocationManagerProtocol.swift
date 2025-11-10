// ABOUTME: Protocol abstraction for CLLocationManager to enable testing
// ABOUTME: Allows mocking of location services without depending on actual device location

import CoreLocation

/// Protocol for location manager to enable dependency injection and testing
protocol LocationManagerProtocol {
    /// Get current authorization status for location services
    func authorizationStatus() -> CLAuthorizationStatus

    /// Request "when in use" location authorization
    func requestWhenInUseAuthorization()

    /// Get current location if available
    func location() -> CLLocation?
}

/// Production implementation wrapping CLLocationManager
class ProductionLocationManager: NSObject, LocationManagerProtocol {
    private let manager: CLLocationManager

    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
    }

    func authorizationStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, macOS 11.0, *) {
            return manager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func location() -> CLLocation? {
        guard let loc = manager.location else {
            return nil
        }

        // Reject locations older than 60 seconds to avoid stale data
        // Note: This returns cached location only. For fresh location,
        // caller should implement requestLocation() or startUpdatingLocation()
        if abs(loc.timestamp.timeIntervalSinceNow) > 60 {
            return nil
        }

        return loc
    }
}

// MARK: - CLLocationManagerDelegate

extension ProductionLocationManager: CLLocationManagerDelegate {
    // Implement delegate methods if needed for future enhancements
}
