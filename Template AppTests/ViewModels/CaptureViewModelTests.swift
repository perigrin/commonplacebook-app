// ABOUTME: Tests for capture view model coordinating speech recognition and note creation
// ABOUTME: Covers recording lifecycle, metadata collection, error handling, and repository integration

import XCTest
import Combine
@testable import CommonplaceBook

@MainActor
final class CaptureViewModelTests: XCTestCase {

    var viewModel: CaptureViewModel!
    var mockSpeechService: MockSpeechRecognitionService!
    var mockAudioMonitor: MockAudioLevelMonitor!
    var mockMetadataCollector: MockMetadataCollector!
    var mockRepository: InMemoryNoteRepository!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()

        mockSpeechService = MockSpeechRecognitionService()
        mockAudioMonitor = MockAudioLevelMonitor()
        mockMetadataCollector = MockMetadataCollector()
        mockRepository = InMemoryNoteRepository()
        cancellables = []

        viewModel = CaptureViewModel(
            speechService: mockSpeechService,
            audioMonitor: mockAudioMonitor,
            metadataCollector: mockMetadataCollector,
            repository: mockRepository
        )
    }

    override func tearDown() async throws {
        cancellables = nil
        viewModel = nil
        mockRepository = nil
        mockMetadataCollector = nil
        mockAudioMonitor = nil
        mockSpeechService = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialStateIsNotRecording() {
        XCTAssertFalse(viewModel.isRecording)
    }

    func testInitialTranscriptionIsEmpty() {
        XCTAssertEqual(viewModel.transcription, "")
    }

    func testInitialAudioLevelIsZero() {
        XCTAssertEqual(viewModel.audioLevel, 0.0, accuracy: 0.001)
    }

    func testInitialErrorIsNil() {
        XCTAssertNil(viewModel.error)
    }

    // MARK: - Start Recording Tests

    func testStartRecordingSetsIsRecordingTrue() async {
        // GIVEN permission is granted
        mockSpeechService.permissionGranted = true

        // WHEN starting recording
        await viewModel.startRecording()

        // THEN isRecording is true
        XCTAssertTrue(viewModel.isRecording)
    }

    func testStartRecordingRequestsPermission() async {
        // GIVEN permission is granted
        mockSpeechService.permissionGranted = true

        // WHEN starting recording
        await viewModel.startRecording()

        // THEN permission was requested
        XCTAssertTrue(mockSpeechService.requestPermissionCalled)
    }

    func testStartRecordingStartsSpeechRecognition() async {
        // GIVEN permission is granted
        mockSpeechService.permissionGranted = true

        // WHEN starting recording
        await viewModel.startRecording()

        // THEN speech recognition is started
        XCTAssertTrue(mockSpeechService.startRecordingCalled)
    }

    func testStartRecordingStartsAudioMonitoring() async throws {
        // GIVEN permission is granted
        mockSpeechService.permissionGranted = true

        // WHEN starting recording
        await viewModel.startRecording()

        // THEN audio monitoring is started
        XCTAssertTrue(mockAudioMonitor.startMonitoringCalled)
    }

    func testStartRecordingHandlesPermissionDenied() async {
        // GIVEN permission is denied
        mockSpeechService.permissionGranted = false

        // WHEN starting recording
        await viewModel.startRecording()

        // THEN isRecording remains false
        XCTAssertFalse(viewModel.isRecording)

        // AND error is set
        XCTAssertNotNil(viewModel.error)
    }

    // MARK: - Transcription Updates Tests

    func testTranscriptionUpdatesFromSpeechService() async {
        // GIVEN recording is active
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()

        // WHEN transcription updates
        mockSpeechService.simulateTranscription("Hello world")

        // Wait for async update
        try? await Task.sleep(nanoseconds: 100_000_000)

        // THEN viewModel transcription is updated
        XCTAssertEqual(viewModel.transcription, "Hello world")
    }

    // MARK: - Audio Level Updates Tests

    func testAudioLevelUpdatesFromMonitor() async {
        // GIVEN recording is active
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()

        // WHEN audio level updates
        mockAudioMonitor.simulateAudioLevel(0.75)

        // Wait for async update
        try? await Task.sleep(nanoseconds: 100_000_000)

        // THEN viewModel audio level is updated
        XCTAssertEqual(viewModel.audioLevel, 0.75, accuracy: 0.01)
    }

    // MARK: - Stop Recording Tests

    func testStopRecordingSetsIsRecordingFalse() async {
        // GIVEN recording is active
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        // WHEN stopping recording
        await viewModel.stopRecording()

        // THEN isRecording is false
        XCTAssertFalse(viewModel.isRecording)
    }

    func testStopRecordingStopsSpeechRecognition() async {
        // GIVEN recording is active
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()

        // WHEN stopping recording
        await viewModel.stopRecording()

        // THEN speech recognition is stopped
        XCTAssertTrue(mockSpeechService.stopRecordingCalled)
    }

    func testStopRecordingStopsAudioMonitoring() async {
        // GIVEN recording is active
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()

        // WHEN stopping recording
        await viewModel.stopRecording()

        // THEN audio monitoring is stopped
        XCTAssertTrue(mockAudioMonitor.stopMonitoringCalled)
    }

    func testStopRecordingReturnsTranscription() async {
        // GIVEN recording with transcription
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()
        mockSpeechService.simulateTranscription("Test transcription")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // WHEN stopping recording
        await viewModel.stopRecording()

        // THEN transcription is preserved
        XCTAssertEqual(viewModel.transcription, "Test transcription")
    }

    // MARK: - Cancel Recording Tests

    func testCancelRecordingDiscardsTranscription() async {
        // GIVEN recording with transcription
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()
        mockSpeechService.simulateTranscription("Test to discard")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // WHEN canceling recording
        await viewModel.cancelRecording()

        // THEN transcription is cleared
        XCTAssertEqual(viewModel.transcription, "")
    }

    func testCancelRecordingSetsIsRecordingFalse() async {
        // GIVEN recording is active
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()

        // WHEN canceling recording
        await viewModel.cancelRecording()

        // THEN isRecording is false
        XCTAssertFalse(viewModel.isRecording)
    }

    func testCancelRecordingStopsServices() async {
        // GIVEN recording is active
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()

        // WHEN canceling recording
        await viewModel.cancelRecording()

        // THEN both services are stopped
        XCTAssertTrue(mockSpeechService.stopRecordingCalled)
        XCTAssertTrue(mockAudioMonitor.stopMonitoringCalled)
    }

    // MARK: - Save Note Tests

    func testSaveNoteCreatesNoteWithTranscription() async {
        // GIVEN transcription is available
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()
        mockSpeechService.simulateTranscription("Note content")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await viewModel.stopRecording()

        // WHEN saving note
        let note = await viewModel.saveNote()

        // THEN note is created with transcription
        XCTAssertNotNil(note)
        XCTAssertTrue(note!.content.contains("Note content"))
    }

    func testSaveNoteAddsMetadata() async {
        // GIVEN transcription is available
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()
        mockSpeechService.simulateTranscription("Note content")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await viewModel.stopRecording()

        // WHEN saving note
        let note = await viewModel.saveNote()

        // THEN note has metadata
        XCTAssertNotNil(note)
        XCTAssertEqual(note!.device, "TestDevice")
        XCTAssertNotNil(note!.created)
    }

    func testSaveNoteSavesToRepository() async {
        // GIVEN transcription is available
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()
        mockSpeechService.simulateTranscription("Note content")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await viewModel.stopRecording()

        // WHEN saving note
        let note = await viewModel.saveNote()

        // THEN note is in repository
        let allNotes = try! await mockRepository.list()
        XCTAssertEqual(allNotes.count, 1)
        XCTAssertEqual(allNotes.first?.id, note?.id)
    }

    func testSaveNoteClearsTranscriptionAfterSave() async {
        // GIVEN transcription is available
        mockSpeechService.permissionGranted = true
        await viewModel.startRecording()
        mockSpeechService.simulateTranscription("Note content")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await viewModel.stopRecording()

        // WHEN saving note
        _ = await viewModel.saveNote()

        // THEN transcription is cleared
        XCTAssertEqual(viewModel.transcription, "")
    }

    func testSaveNoteWithEmptyTranscriptionReturnsNil() async {
        // GIVEN no transcription
        // WHEN saving note
        let note = await viewModel.saveNote()

        // THEN nil is returned
        XCTAssertNil(note)
    }

    // MARK: - Error Handling Tests

    func testErrorSetWhenSpeechRecognitionFails() async {
        // GIVEN speech recognition will fail
        mockSpeechService.permissionGranted = true
        mockSpeechService.shouldFailStart = true

        // WHEN starting recording
        await viewModel.startRecording()

        // THEN error is set
        XCTAssertNotNil(viewModel.error)
    }

    func testErrorSetWhenAudioMonitorFails() async {
        // GIVEN audio monitor will fail
        mockSpeechService.permissionGranted = true
        mockAudioMonitor.shouldFailStart = true

        // WHEN starting recording
        await viewModel.startRecording()

        // THEN error is set
        XCTAssertNotNil(viewModel.error)
    }

    // MARK: - Multiple Recording Cycles Tests

    func testMultipleRecordingCyclesWork() async {
        mockSpeechService.permissionGranted = true

        // Cycle 1
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)
        await viewModel.stopRecording()
        XCTAssertFalse(viewModel.isRecording)

        // Cycle 2
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)
        await viewModel.stopRecording()
        XCTAssertFalse(viewModel.isRecording)

        // Cycle 3
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)
        await viewModel.cancelRecording()
        XCTAssertFalse(viewModel.isRecording)
    }
}

// MARK: - Mock Services

class MockSpeechRecognitionService: SpeechRecognitionService {
    var permissionGranted = true
    var requestPermissionCalled = false
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var shouldFailStart = false

    override func requestPermission() async -> Bool {
        requestPermissionCalled = true
        return permissionGranted
    }

    override func startRecording() async throws {
        startRecordingCalled = true
        if shouldFailStart {
            throw SpeechRecognitionError.microphoneUnavailable
        }
        await MainActor.run {
            isRecording = true
        }
    }

    override func stopRecording() async -> String {
        stopRecordingCalled = true
        let result = await MainActor.run { transcription }
        await MainActor.run {
            isRecording = false
        }
        return result
    }

    func simulateTranscription(_ text: String) {
        Task { @MainActor in
            self.transcription = text
        }
    }
}

class MockAudioLevelMonitor: AudioLevelMonitor {
    var startMonitoringCalled = false
    var stopMonitoringCalled = false
    var shouldFailStart = false

    override func startMonitoring() throws {
        startMonitoringCalled = true
        if shouldFailStart {
            throw AudioLevelMonitorError.alreadyMonitoring
        }
    }

    override func stopMonitoring() {
        stopMonitoringCalled = true
    }

    func simulateAudioLevel(_ level: Float) {
        Task { @MainActor in
            self.audioLevel = level
        }
    }
}
