// ABOUTME: Location data structure for note metadata
// ABOUTME: Represents geographic coordinates with accuracy information

import Foundation

/// Geographic location with accuracy
struct Location: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double  // Horizontal accuracy in meters

    /// Check if location is valid
    var isValid: Bool {
        // Valid latitude: -90 to 90
        // Valid longitude: -180 to 180
        // Valid accuracy: >= 0
        return latitude >= -90.0 && latitude <= 90.0 &&
               longitude >= -180.0 && longitude <= 180.0 &&
               accuracy >= 0.0
    }

    init(latitude: Double, longitude: Double, accuracy: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
    }
}
