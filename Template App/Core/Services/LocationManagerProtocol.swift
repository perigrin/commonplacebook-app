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
        return manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func location() -> CLLocation? {
        return manager.location
    }
}

// MARK: - CLLocationManagerDelegate

extension ProductionLocationManager: CLLocationManagerDelegate {
    // Implement delegate methods if needed for future enhancements
}
