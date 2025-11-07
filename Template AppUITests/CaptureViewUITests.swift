// ABOUTME: UI tests for CaptureView interface components and user interactions
// ABOUTME: Tests microphone button, waveform display, transcription, and save/cancel actions

import XCTest

final class CaptureViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Microphone Button Tests

    func testMicrophoneButtonExists() throws {
        // Navigate to capture view
        let captureTab = app.buttons["Capture"]
        XCTAssertTrue(captureTab.waitForExistence(timeout: 2))
        captureTab.tap()

        // THEN microphone button exists
        let micButton = app.buttons["microphoneButton"]
        XCTAssertTrue(micButton.exists)
    }

    func testTapMicrophoneStartsRecording() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // WHEN tapping microphone button
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // THEN recording state is shown (button color changes)
        XCTAssertTrue(micButton.isSelected)
    }

    func testWaveformAppearsDuringRecording() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // WHEN starting recording
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // THEN waveform view appears
        let waveform = app.otherElements["waveformView"]
        XCTAssertTrue(waveform.waitForExistence(timeout: 1))
    }

    func testTapMicrophoneAgainStopsRecording() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // GIVEN recording is active
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // WHEN tapping microphone button again
        micButton.tap()

        // THEN recording state is stopped
        XCTAssertFalse(micButton.isSelected)
    }

    // MARK: - Transcription Tests

    func testTranscriptionAppearsAfterStopping() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // GIVEN recording is active
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // WHEN stopping recording (wait for waveform to appear first)
        let waveform = app.otherElements["waveformView"]
        XCTAssertTrue(waveform.waitForExistence(timeout: 2))
        micButton.tap()

        // THEN transcription area exists
        let transcriptionText = app.staticTexts["transcriptionText"]
        XCTAssertTrue(transcriptionText.waitForExistence(timeout: 5))
    }

    // MARK: - Save/Cancel Button Tests

    func testSaveButtonAppearsAfterRecording() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // GIVEN recording is complete
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // Wait for recording to start
        let waveform = app.otherElements["waveformView"]
        XCTAssertTrue(waveform.waitForExistence(timeout: 2))

        micButton.tap()

        // THEN save button appears
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
    }

    func testCancelButtonAppearsAfterRecording() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // GIVEN recording is complete
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // Wait for recording to start
        let waveform = app.otherElements["waveformView"]
        XCTAssertTrue(waveform.waitForExistence(timeout: 2))

        micButton.tap()

        // THEN cancel button appears
        let cancelButton = app.buttons["cancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
    }

    func testSaveButtonCreatesNote() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // GIVEN transcription exists
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // Wait for recording to start
        let waveform = app.otherElements["waveformView"]
        XCTAssertTrue(waveform.waitForExistence(timeout: 2))

        micButton.tap()

        // WHEN tapping save button
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // THEN view returns to initial state (save button no longer visible)
        XCTAssertFalse(saveButton.exists)
    }

    func testCancelButtonDiscardsTranscription() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // GIVEN transcription exists
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // Wait for recording to start
        let waveform = app.otherElements["waveformView"]
        XCTAssertTrue(waveform.waitForExistence(timeout: 2))

        micButton.tap()

        // WHEN tapping cancel button
        let cancelButton = app.buttons["cancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // THEN view returns to initial state (cancel button no longer visible)
        XCTAssertFalse(cancelButton.exists)
    }

    // MARK: - Permission Tests

    func testPermissionAlertShowsWhenDenied() throws {
        // This test requires permission to be denied
        // Launch with permission denied flag
        app.launchArguments.append("--speech-permission-denied")
        app.launch()

        // Navigate to capture view
        app.buttons["Capture"].tap()

        // WHEN tapping microphone button
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // THEN permission alert appears
        let alert = app.alerts["Permission Required"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
    }

    // MARK: - Error Alert Tests

    func testErrorAlertDisplaysCorrectly() throws {
        // This test requires an error condition
        // Launch with error flag
        app.launchArguments.append("--trigger-recording-error")
        app.launch()

        // Navigate to capture view
        app.buttons["Capture"].tap()

        // WHEN tapping microphone button
        let micButton = app.buttons["microphoneButton"]
        micButton.tap()

        // THEN error alert appears
        let alert = app.alerts.element
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
    }
}
