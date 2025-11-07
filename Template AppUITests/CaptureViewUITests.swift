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

    // MARK: - Mode Toggle Tests

    func testModeToggleExists() throws {
        // Navigate to capture view
        let captureTab = app.buttons["Capture"]
        XCTAssertTrue(captureTab.waitForExistence(timeout: 2))
        captureTab.tap()

        // THEN mode toggle exists
        let toggle = app.segmentedControls["modeToggle"]
        XCTAssertTrue(toggle.exists)
    }

    func testSwitchToTextModeHidesMicrophone() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // GIVEN speech mode is active
        let micButton = app.buttons["microphoneButton"]
        XCTAssertTrue(micButton.exists)

        // WHEN switching to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // THEN microphone button is hidden
        XCTAssertFalse(micButton.exists)
    }

    func testSwitchToTextModeShowsTextEditor() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // WHEN switching to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // THEN text editor appears
        let contentEditor = app.textViews["contentEditor"]
        XCTAssertTrue(contentEditor.exists)
    }

    func testSwitchToTextModeShowsTitleField() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // WHEN switching to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // THEN title field appears
        let titleField = app.textFields["titleField"]
        XCTAssertTrue(titleField.exists)
    }

    func testTextEditorAcceptsInput() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // Switch to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // WHEN typing in text editor
        let contentEditor = app.textViews["contentEditor"]
        contentEditor.tap()
        contentEditor.typeText("This is my test note content")

        // THEN text appears in editor
        XCTAssertTrue(contentEditor.value as? String == "This is my test note content")
    }

    func testSaveButtonEnabledWithContent() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // Switch to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // WHEN entering content
        let contentEditor = app.textViews["contentEditor"]
        contentEditor.tap()
        contentEditor.typeText("Test content")

        // THEN save button is enabled
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.isEnabled)
    }

    func testSaveButtonDisabledWithoutContent() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // Switch to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // GIVEN no content entered
        // THEN save button is disabled
        let saveButton = app.buttons["saveButton"]
        XCTAssertFalse(saveButton.isEnabled)
    }

    func testSaveWithTitleCreatesNote() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // Switch to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // Enter title and content
        let titleField = app.textFields["titleField"]
        titleField.tap()
        titleField.typeText("My Note")

        let contentEditor = app.textViews["contentEditor"]
        contentEditor.tap()
        contentEditor.typeText("Note content here")

        // WHEN tapping save
        let saveButton = app.buttons["saveButton"]
        saveButton.tap()

        // THEN fields are cleared (indicating note was created)
        XCTAssertEqual(titleField.value as? String, "")
        XCTAssertEqual(contentEditor.value as? String, "")
    }

    func testSaveWithoutTitleCreatesNote() throws {
        // Navigate to capture view
        app.buttons["Capture"].tap()

        // Switch to text mode
        let toggle = app.segmentedControls["modeToggle"]
        toggle.buttons["Text"].tap()

        // Enter only content (no title)
        let contentEditor = app.textViews["contentEditor"]
        contentEditor.tap()
        contentEditor.typeText("First line is title\nSecond line content")

        // WHEN tapping save
        let saveButton = app.buttons["saveButton"]
        saveButton.tap()

        // THEN note is created (fields cleared)
        XCTAssertEqual(contentEditor.value as? String, "")
    }
}
