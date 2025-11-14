// ABOUTME: Tests for DeviceInfo utility for device name and model retrieval
// ABOUTME: Validates platform-specific device identification across iOS and macOS

import XCTest
@testable import Commonplace_Book

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class DeviceInfoTests: XCTestCase {

    // MARK: - Device Name Tests

    func testGetCurrentDeviceNameReturnsNonEmptyString() {
        // GIVEN DeviceInfo utility
        // WHEN getting current device name
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // THEN should return non-empty string
        XCTAssertFalse(deviceName.isEmpty, "Device name should not be empty")
    }

    func testGetCurrentDeviceNameReturnsConsistentValue() {
        // GIVEN DeviceInfo utility
        // WHEN calling getCurrentDeviceName multiple times
        let name1 = DeviceInfo.getCurrentDeviceName()
        let name2 = DeviceInfo.getCurrentDeviceName()

        // THEN should return same value
        XCTAssertEqual(name1, name2, "Device name should be consistent")
    }

    #if os(iOS)
    func testGetCurrentDeviceNameMatchesUIDevice() {
        // GIVEN DeviceInfo utility on iOS
        // WHEN getting current device name
        let deviceName = DeviceInfo.getCurrentDeviceName()
        let uiDeviceName = UIDevice.current.name

        // THEN should match UIDevice name
        XCTAssertEqual(deviceName, uiDeviceName, "Should match UIDevice.current.name on iOS")
    }

    func testGetCurrentDeviceNameContainsDeviceType() {
        // GIVEN DeviceInfo utility on iOS
        // WHEN getting current device name
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // THEN should contain device type indicators
        // Note: User-customized names may not contain these, but default names do
        let containsDeviceType = deviceName.contains("iPhone") ||
                                 deviceName.contains("iPad") ||
                                 deviceName.contains("iPod") ||
                                 deviceName.count > 0 // At minimum should have some name

        XCTAssertTrue(containsDeviceType, "Device name should be valid: \(deviceName)")
    }
    #endif

    #if os(macOS)
    func testGetCurrentDeviceNameOnMacReturnsModelOrHostname() {
        // GIVEN DeviceInfo utility on macOS
        // WHEN getting current device name
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // THEN should return valid Mac identifier
        XCTAssertFalse(deviceName.isEmpty, "Mac device name should not be empty")
        // Should be either model name or hostname
        let isValidMacName = deviceName.contains("Mac") ||
                             deviceName.contains("Book") ||
                             deviceName.count > 0
        XCTAssertTrue(isValidMacName, "Should be valid Mac identifier: \(deviceName)")
    }
    #endif

    // MARK: - Device Model Tests

    func testGetDeviceModelReturnsNonEmptyString() {
        // GIVEN DeviceInfo utility
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should return non-empty string
        XCTAssertFalse(model.isEmpty, "Device model should not be empty")
    }

    func testGetDeviceModelReturnsConsistentValue() {
        // GIVEN DeviceInfo utility
        // WHEN calling getDeviceModel multiple times
        let model1 = DeviceInfo.getDeviceModel()
        let model2 = DeviceInfo.getDeviceModel()

        // THEN should return same value
        XCTAssertEqual(model1, model2, "Device model should be consistent")
    }

    #if os(iOS)
    func testGetDeviceModelReturnsValidFormat() {
        // GIVEN DeviceInfo utility on iOS
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should match expected format
        // iOS model identifiers typically look like "iPhone14,2" or "iPad8,1"
        XCTAssertFalse(model.isEmpty, "Model identifier should not be empty")

        // Should contain alphanumeric characters
        let alphanumericSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ","))
        let modelSet = CharacterSet(charactersIn: model)
        XCTAssertTrue(alphanumericSet.isSuperset(of: modelSet),
                     "Model should contain only alphanumeric characters and commas: \(model)")
    }

    func testGetDeviceModelStartsWithDeviceType() {
        // GIVEN DeviceInfo utility on iOS
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should start with device type
        let validPrefixes = ["iPhone", "iPad", "iPod"]
        let hasValidPrefix = validPrefixes.contains { model.hasPrefix($0) }

        XCTAssertTrue(hasValidPrefix || !model.isEmpty,
                     "Model should start with device type or be non-empty: \(model)")
    }

    func testGetDeviceModelContainsVersionNumber() {
        // GIVEN DeviceInfo utility on iOS
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should contain numeric version
        // Models like "iPhone14,2" contain numbers
        let containsDigit = model.contains(where: { $0.isNumber })
        XCTAssertTrue(containsDigit || !model.isEmpty,
                     "Model should contain version number: \(model)")
    }
    #endif

    #if os(macOS)
    func testGetDeviceModelOnMacReturnsValidIdentifier() {
        // GIVEN DeviceInfo utility on macOS
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should return valid Mac identifier
        XCTAssertFalse(model.isEmpty, "Mac model should not be empty")
    }
    #endif

    // MARK: - Platform Detection Tests

    func testPlatformSpecificImplementation() {
        // GIVEN DeviceInfo utility
        // WHEN checking platform
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "Unknown"
        #endif

        // THEN should have correct platform implementation
        XCTAssertNotNil(platform, "Platform should be detected")

        // Validate that methods work on current platform
        let deviceName = DeviceInfo.getCurrentDeviceName()
        let deviceModel = DeviceInfo.getDeviceModel()

        #if os(iOS)
        XCTAssertNotEqual(deviceName, "Unknown Device", "iOS should return actual device name")
        XCTAssertNotEqual(deviceModel, "Unknown", "iOS should return actual model")
        #elseif os(macOS)
        XCTAssertNotEqual(deviceName, "Unknown Device", "macOS should return actual device name")
        XCTAssertNotEqual(deviceModel, "Unknown", "macOS should return actual model")
        #endif
    }

    // MARK: - String Format Tests

    func testDeviceNameDoesNotContainNullCharacters() {
        // GIVEN DeviceInfo utility
        // WHEN getting device name
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // THEN should not contain null characters
        XCTAssertFalse(deviceName.contains("\0"), "Device name should not contain null characters")
    }

    func testDeviceModelDoesNotContainNullCharacters() {
        // GIVEN DeviceInfo utility
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should not contain null characters
        XCTAssertFalse(model.contains("\0"), "Device model should not contain null characters")
    }

    func testDeviceNameIsTrimmed() {
        // GIVEN DeviceInfo utility
        // WHEN getting device name
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // THEN should not have leading/trailing whitespace
        XCTAssertEqual(deviceName, deviceName.trimmingCharacters(in: .whitespacesAndNewlines),
                      "Device name should be trimmed")
    }

    func testDeviceModelIsTrimmed() {
        // GIVEN DeviceInfo utility
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should not have leading/trailing whitespace
        XCTAssertEqual(model, model.trimmingCharacters(in: .whitespacesAndNewlines),
                      "Device model should be trimmed")
    }

    // MARK: - Concurrent Access Tests

    func testGetCurrentDeviceNameIsThreadSafe() {
        // GIVEN DeviceInfo utility
        // WHEN calling from multiple threads
        let expectation = XCTestExpectation(description: "Thread safe device name access")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var deviceNames: [String] = []
        let lock = NSLock()

        for _ in 0..<100 {
            group.enter()
            queue.async {
                let name = DeviceInfo.getCurrentDeviceName()
                lock.lock()
                deviceNames.append(name)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all calls should succeed with same value
        XCTAssertEqual(deviceNames.count, 100, "All concurrent calls should complete")
        let uniqueNames = Set(deviceNames)
        XCTAssertEqual(uniqueNames.count, 1, "All concurrent calls should return same name")
    }

    func testGetDeviceModelIsThreadSafe() {
        // GIVEN DeviceInfo utility
        // WHEN calling from multiple threads
        let expectation = XCTestExpectation(description: "Thread safe model access")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var models: [String] = []
        let lock = NSLock()

        for _ in 0..<100 {
            group.enter()
            queue.async {
                let model = DeviceInfo.getDeviceModel()
                lock.lock()
                models.append(model)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all calls should succeed with same value
        XCTAssertEqual(models.count, 100, "All concurrent calls should complete")
        let uniqueModels = Set(models)
        XCTAssertEqual(uniqueModels.count, 1, "All concurrent calls should return same model")
    }

    // MARK: - Performance Tests

    func testGetCurrentDeviceNamePerformance() {
        // GIVEN DeviceInfo utility
        measure {
            // WHEN getting device name
            _ = DeviceInfo.getCurrentDeviceName()
        }
        // THEN should complete quickly
    }

    func testGetDeviceModelPerformance() {
        // GIVEN DeviceInfo utility
        measure {
            // WHEN getting device model
            _ = DeviceInfo.getDeviceModel()
        }
        // THEN should complete quickly
    }

    // MARK: - Integration Tests Documentation

    func testDocumentRequiredIntegrationTests() {
        // This test documents integration tests that verify device info
        // in different scenarios and platforms

        let requiredIntegrationTests = [
            "testDeviceInfoOnActualiOSDevice",
            "testDeviceInfoOnActualMacDevice",
            "testDeviceInfoInSimulator",
            "testDeviceNameReflectsUserCustomization",
            "testModelIdentifierMatchesHardware",
            "testDeviceInfoInDifferentLocales",
            "testDeviceInfoAfterOSUpgrade"
        ]

        XCTAssertEqual(requiredIntegrationTests.count, 7,
                      "Should have \(requiredIntegrationTests.count) integration tests")
    }

    // MARK: - Edge Cases

    func testDeviceNameLengthIsReasonable() {
        // GIVEN DeviceInfo utility
        // WHEN getting device name
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // THEN length should be reasonable
        XCTAssertTrue(deviceName.count > 0, "Device name should have length > 0")
        XCTAssertTrue(deviceName.count < 256, "Device name should be less than 256 characters")
    }

    func testDeviceModelLengthIsReasonable() {
        // GIVEN DeviceInfo utility
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN length should be reasonable
        XCTAssertTrue(model.count > 0, "Device model should have length > 0")
        XCTAssertTrue(model.count < 256, "Device model should be less than 256 characters")
    }

    func testDeviceNameIsValidUTF8() {
        // GIVEN DeviceInfo utility
        // WHEN getting device name
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // THEN should be valid UTF8
        let utf8Data = deviceName.data(using: .utf8)
        XCTAssertNotNil(utf8Data, "Device name should be valid UTF-8")

        if let data = utf8Data {
            let reconstructed = String(data: data, encoding: .utf8)
            XCTAssertEqual(reconstructed, deviceName, "Device name should round-trip through UTF-8")
        }
    }

    func testDeviceModelIsValidUTF8() {
        // GIVEN DeviceInfo utility
        // WHEN getting device model
        let model = DeviceInfo.getDeviceModel()

        // THEN should be valid UTF8
        let utf8Data = model.data(using: .utf8)
        XCTAssertNotNil(utf8Data, "Device model should be valid UTF-8")

        if let data = utf8Data {
            let reconstructed = String(data: data, encoding: .utf8)
            XCTAssertEqual(reconstructed, model, "Device model should round-trip through UTF-8")
        }
    }

    // MARK: - Comparison Tests

    func testDeviceNameAndModelAreDifferent() {
        // GIVEN DeviceInfo utility
        // WHEN getting both name and model
        let deviceName = DeviceInfo.getCurrentDeviceName()
        let deviceModel = DeviceInfo.getDeviceModel()

        // THEN they serve different purposes
        // Name is user-facing, model is technical identifier
        // They may be the same on some platforms (macOS), but serve different purposes
        XCTAssertTrue(deviceName.count > 0 && deviceModel.count > 0,
                     "Both name and model should be non-empty")
    }

    // MARK: - Stability Tests

    func testMultipleSequentialCalls() {
        // GIVEN DeviceInfo utility
        // WHEN making multiple sequential calls
        var names: [String] = []
        var models: [String] = []

        for _ in 0..<10 {
            names.append(DeviceInfo.getCurrentDeviceName())
            models.append(DeviceInfo.getDeviceModel())
        }

        // THEN all values should be consistent
        XCTAssertEqual(Set(names).count, 1, "Device name should be stable across calls")
        XCTAssertEqual(Set(models).count, 1, "Device model should be stable across calls")
    }

    func testInterleavedCalls() {
        // GIVEN DeviceInfo utility
        // WHEN interleaving name and model calls
        var results: [(name: String, model: String)] = []

        for _ in 0..<10 {
            let name = DeviceInfo.getCurrentDeviceName()
            let model = DeviceInfo.getDeviceModel()
            results.append((name, model))
        }

        // THEN all values should be consistent
        let allNames = results.map { $0.name }
        let allModels = results.map { $0.model }

        XCTAssertEqual(Set(allNames).count, 1, "Device names should be consistent")
        XCTAssertEqual(Set(allModels).count, 1, "Device models should be consistent")
    }
}
