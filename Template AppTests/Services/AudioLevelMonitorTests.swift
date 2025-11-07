// ABOUTME: Tests for audio level monitoring service
// ABOUTME: Covers level monitoring, start/stop lifecycle, and memory management

import XCTest
import AVFoundation
import Combine
@testable import CommonplaceBook

@MainActor
final class AudioLevelMonitorTests: XCTestCase {

    var monitor: AudioLevelMonitor!
    var mockAudioEngine: MockAudioEngineForMonitor!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()

        mockAudioEngine = MockAudioEngineForMonitor()
        monitor = AudioLevelMonitor(audioEngine: mockAudioEngine)
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        monitor = nil
        mockAudioEngine = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialAudioLevelIsZero() {
        // GIVEN a new monitor
        // WHEN checking initial level
        // THEN it should be zero
        XCTAssertEqual(monitor.audioLevel, 0.0, accuracy: 0.001)
    }

    func testInitiallyNotMonitoring() {
        // GIVEN a new monitor
        // WHEN checking monitoring state
        // THEN it should not be monitoring
        XCTAssertFalse(monitor.isMonitoring)
    }

    // MARK: - Start Monitoring Tests

    func testStartMonitoringSetsIsMonitoringTrue() throws {
        // GIVEN a stopped monitor
        XCTAssertFalse(monitor.isMonitoring)

        // WHEN starting monitoring
        try monitor.startMonitoring()

        // THEN isMonitoring is true
        XCTAssertTrue(monitor.isMonitoring)
    }

    func testStartMonitoringInstallsTap() throws {
        // GIVEN a stopped monitor
        // WHEN starting monitoring
        try monitor.startMonitoring()

        // THEN tap is installed on audio engine
        XCTAssertTrue(mockAudioEngine.tapInstalled)
    }

    func testStartMonitoringThrowsWhenAlreadyMonitoring() throws {
        // GIVEN monitoring already started
        try monitor.startMonitoring()

        // WHEN trying to start again
        // THEN it throws
        XCTAssertThrowsError(try monitor.startMonitoring()) { error in
            XCTAssertTrue(error is AudioLevelMonitorError)
        }
    }

    // MARK: - Stop Monitoring Tests

    func testStopMonitoringSetsIsMonitoringFalse() throws {
        // GIVEN monitoring is active
        try monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)

        // WHEN stopping monitoring
        monitor.stopMonitoring()

        // THEN isMonitoring is false
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testStopMonitoringRemovesTap() throws {
        // GIVEN monitoring is active
        try monitor.startMonitoring()
        XCTAssertTrue(mockAudioEngine.tapInstalled)

        // WHEN stopping monitoring
        monitor.stopMonitoring()

        // THEN tap is removed
        XCTAssertFalse(mockAudioEngine.tapInstalled)
    }

    func testStopMonitoringWhenNotMonitoringDoesNotCrash() {
        // GIVEN monitor not started
        XCTAssertFalse(monitor.isMonitoring)

        // WHEN stopping monitoring
        monitor.stopMonitoring()

        // THEN it doesn't crash
        XCTAssertFalse(monitor.isMonitoring)
    }

    // MARK: - Audio Level Publisher Tests

    func testAudioLevelPublisherEmitsUpdates() throws {
        // GIVEN monitoring is active
        var receivedLevels: [Float] = []
        let expectation = expectation(description: "Receive audio levels")
        expectation.expectedFulfillmentCount = 3

        monitor.$audioLevel
            .sink { level in
                receivedLevels.append(level)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try monitor.startMonitoring()

        // WHEN simulating audio level changes
        mockAudioEngine.simulateAudioLevel(0.3)
        mockAudioEngine.simulateAudioLevel(0.6)
        mockAudioEngine.simulateAudioLevel(0.9)

        // THEN publisher emits updates
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedLevels.count, 3)
        XCTAssertEqual(receivedLevels[0], 0.3, accuracy: 0.01)
        XCTAssertEqual(receivedLevels[1], 0.6, accuracy: 0.01)
        XCTAssertEqual(receivedLevels[2], 0.9, accuracy: 0.01)
    }

    func testAudioLevelClampedBetweenZeroAndOne() throws {
        // GIVEN monitoring is active
        try monitor.startMonitoring()

        // WHEN receiving level above 1.0
        mockAudioEngine.simulateAudioLevel(1.5)

        // THEN level is clamped to 1.0
        XCTAssertLessThanOrEqual(monitor.audioLevel, 1.0)

        // WHEN receiving level below 0.0
        mockAudioEngine.simulateAudioLevel(-0.5)

        // THEN level is clamped to 0.0
        XCTAssertGreaterThanOrEqual(monitor.audioLevel, 0.0)
    }

    // MARK: - Multiple Start/Stop Cycles Tests

    func testMultipleStartStopCyclesWork() throws {
        // Cycle 1
        try monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)

        // Cycle 2
        try monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)

        // Cycle 3
        try monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }

    // MARK: - Audio Level Reset Tests

    func testAudioLevelResetsToZeroWhenStopped() throws {
        // GIVEN monitoring with non-zero level
        try monitor.startMonitoring()
        mockAudioEngine.simulateAudioLevel(0.8)
        XCTAssertGreaterThan(monitor.audioLevel, 0.0)

        // WHEN stopping monitoring
        monitor.stopMonitoring()

        // THEN level resets to zero
        XCTAssertEqual(monitor.audioLevel, 0.0, accuracy: 0.001)
    }
}

// MARK: - Mock Audio Engine for Monitoring

class MockAudioEngineForMonitor: AudioEngineProtocol {
    var tapInstalled = false
    private var _isRunning = false
    private let mockEngine = AVAudioEngine()
    private var tapBlock: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    var inputNode: AVAudioInputNode {
        return mockEngine.inputNode
    }

    var isRunning: Bool {
        return _isRunning
    }

    func prepare() {
        // No-op for mock
    }

    func start() throws {
        _isRunning = true
    }

    func stop() {
        _isRunning = false
    }

    func reset() {
        tapInstalled = false
        tapBlock = nil
    }

    // Custom methods for testing
    func installTapForMonitoring(onBus bus: Int, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        tapInstalled = true
        tapBlock = block
    }

    func removeTapForMonitoring(onBus bus: Int) {
        tapInstalled = false
        tapBlock = nil
    }

    func simulateAudioLevel(_ level: Float) {
        guard let tapBlock = tapBlock, let format = inputNode.outputFormat(forBus: 0) as? AVAudioFormat else {
            return
        }

        // Create a buffer with simulated audio data
        let bufferSize: AVAudioFrameCount = 1024
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            return
        }
        buffer.frameLength = bufferSize

        // Simulate audio level by setting channel data
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(bufferSize) {
                channelData[0][frame] = level
            }
        }

        let audioTime = AVAudioTime(hostTime: mach_absolute_time())
        tapBlock(buffer, audioTime)
    }
}

/// Errors that can occur during audio level monitoring
enum AudioLevelMonitorError: LocalizedError {
    case alreadyMonitoring

    var errorDescription: String? {
        switch self {
        case .alreadyMonitoring:
            return "Audio level monitoring is already active"
        }
    }
}
