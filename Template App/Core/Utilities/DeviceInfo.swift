// ABOUTME: Device information utilities for retrieving device name and model
// ABOUTME: Provides human-readable device names across iPhone, iPad, and Mac platforms

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Device information utilities
enum DeviceInfo {

    /// Get the current device name
    /// - Returns: Human-readable device name (e.g., "iPhone 15 Pro", "iPad Air", "Mac")
    static func getCurrentDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return getMacModelName()
        #else
        return "Unknown Device"
        #endif
    }

    #if os(macOS)
    /// Get Mac model name
    /// - Returns: Mac model name
    private static func getMacModelName() -> String {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        var modelIdentifier: String?

        if let modelData = IORegistryEntryCreateCFProperty(
            service,
            "model" as CFString,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as? Data {
            modelIdentifier = String(data: modelData, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters)
        }

        IOObjectRelease(service)

        return modelIdentifier ?? ProcessInfo.processInfo.hostName
    }
    #endif

    /// Get device model identifier
    /// - Returns: Device model identifier (e.g., "iPhone14,2")
    static func getDeviceModel() -> String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #elseif os(macOS)
        return getMacModelName()
        #else
        return "Unknown"
        #endif
    }
}
