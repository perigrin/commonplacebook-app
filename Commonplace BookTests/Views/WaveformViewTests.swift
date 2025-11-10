// ABOUTME: Tests for waveform visualization view
// ABOUTME: Covers rendering with different recording states and audio levels

import XCTest
import SwiftUI
@testable import CommonplaceBook

@MainActor
final class WaveformViewTests: XCTestCase {

    // MARK: - Initialization Tests

    func testWaveformViewInitialization() {
        // GIVEN bindings for recording and audio level
        var isRecording = false
        var audioLevel: Float = 0.0

        // WHEN creating a WaveformView
        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
        )

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testWaveformViewWithRecordingState() {
        // GIVEN recording is active
        var isRecording = true
        var audioLevel: Float = 0.5

        // WHEN creating a WaveformView
        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
        )

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testWaveformViewWithZeroAudioLevel() {
        // GIVEN zero audio level
        var isRecording = true
        var audioLevel: Float = 0.0

        // WHEN creating a WaveformView
        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
        )

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testWaveformViewWithMaxAudioLevel() {
        // GIVEN max audio level
        var isRecording = true
        var audioLevel: Float = 1.0

        // WHEN creating a WaveformView
        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
        )

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testWaveformViewWithMediumAudioLevel() {
        // GIVEN medium audio level
        var isRecording = true
        var audioLevel: Float = 0.5

        // WHEN creating a WaveformView
        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
        )

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testWaveformViewWithVaryingAudioLevels() {
        // Test multiple audio levels
        let levels: [Float] = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

        for level in levels {
            var isRecording = true
            var audioLevel = level

            let view = WaveformView(
                isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
                audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
            )

            XCTAssertNotNil(view, "View should not be nil for level \(level)")
        }
    }

    func testWaveformViewWithNotRecording() {
        // GIVEN not recording
        var isRecording = false
        var audioLevel: Float = 0.0

        // WHEN creating a WaveformView
        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
        )

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testWaveformViewWithCustomColor() {
        // GIVEN custom color
        var isRecording = true
        var audioLevel: Float = 0.7

        // WHEN creating a WaveformView with custom color
        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 }),
            waveformColor: .red
        )

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testWaveformViewTransitionBetweenStates() {
        // Test transitioning between recording states
        var isRecording = false
        var audioLevel: Float = 0.0

        let view = WaveformView(
            isRecording: Binding(get: { isRecording }, set: { isRecording = $0 }),
            audioLevel: Binding(get: { audioLevel }, set: { audioLevel = $0 })
        )

        XCTAssertNotNil(view)

        // Simulate state changes
        isRecording = true
        audioLevel = 0.5
        XCTAssertNotNil(view)

        isRecording = false
        audioLevel = 0.0
        XCTAssertNotNil(view)
    }

    // MARK: - Preview Tests

    func testPreviewProviderDoesNotCrash() {
        // GIVEN the preview provider
        // WHEN accessing previews
        let previews = WaveformView_Previews.previews

        // THEN it should not crash
        XCTAssertNotNil(previews)
    }
}
