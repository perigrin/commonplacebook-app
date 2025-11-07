// ABOUTME: Mock implementation of MetadataCollector for testing
// ABOUTME: Returns predictable test data instead of real device/location information

import Foundation
@testable import CommonplaceBook

/// Mock metadata collector for testing and previews
actor MockMetadataCollector {
    private let deviceName: String
    private let location: Location?

    init(deviceName: String = "TestDevice", location: Location? = nil) {
        self.deviceName = deviceName
        self.location = location
    }

    func getCurrentDevice() -> String {
        return deviceName
    }

    func generateTimestamp() -> Date {
        return Date()
    }

    func getCurrentLocation() async -> Location? {
        return location
    }
}
