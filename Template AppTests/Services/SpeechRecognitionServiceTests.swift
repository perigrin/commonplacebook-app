// ABOUTME: Tests for speech recognition service with permission and transcription handling
// ABOUTME: Covers permission flow, recording lifecycle, transcription updates, silence detection

import XCTest
import Speech
import Combine
@testable import CommonplaceBook

@MainActor
final class SpeechRecognitionServiceTests: XCTestCase {

    var service: SpeechRecognitionService!
    var mockRecognizer: MockSpeechRecognizer!
    var mockAudioEngine: MockAudioEngine!
    var mockAudioSession: MockAudioSession!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()

        mockRecognizer = MockSpeechRecognizer()
        mockAudioEngine = MockAudioEngine()
        mockAudioSession = MockAudioSession()
        cancellables = []

        service = SpeechRecognitionService(
            recognizer: mockRecognizer,
            audioEngine: mockAudioEngine,
            audioSession: mockAudioSession
        )
    }

    override func tearDown() async throws {
        cancellables = nil
        service = nil
        mockAudioSession = nil
        mockAudioEngine = nil
        mockRecognizer = nil
        try await super.tearDown()
    }

    // MARK: - Permission Tests

    func testRequestPermissionReturnsTrue_WhenAuthorized() async {
        // GIVEN speech recognition is authorized
        mockRecognizer.authStatus = .authorized

        // WHEN requesting permission
        let granted = await service.requestPermission()

        // THEN permission is granted
        XCTAssertTrue(granted)
    }

    func testRequestPermissionReturnsFalse_WhenDenied() async {
        // GIVEN speech recognition is denied
        mockRecognizer.authStatus = .denied

        // WHEN requesting permission
        let granted = await service.requestPermission()

        // THEN permission is denied
        XCTAssertFalse(granted)
    }

    func testRequestPermissionReturnsFalse_WhenRestricted() async {
        // GIVEN speech recognition is restricted
        mockRecognizer.authStatus = .restricted

        // WHEN requesting permission
        let granted = await service.requestPermission()

        // THEN permission is denied
        XCTAssertFalse(granted)
    }

    // MARK: - Recording Lifecycle Tests

    func testStartRecordingThrowsError_WhenPermissionDenied() async {
        // GIVEN permission is denied
        mockRecognizer.authStatus = .denied

        // WHEN starting recording
        // THEN it throws permission denied error
        do {
            try await service.startRecording()
            XCTFail("Expected permissionDenied error")
        } catch let error as SpeechRecognitionError {
            XCTAssertEqual(error, SpeechRecognitionError.permissionDenied)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testStartRecordingSetsIsRecordingTrue() async throws {
        // GIVEN permission is granted
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true

        // WHEN starting recording
        try await service.startRecording()

        // THEN isRecording is true
        XCTAssertTrue(service.isRecording)
    }

    func testStopRecordingSetsIsRecordingFalse() async throws {
        // GIVEN recording is in progress
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true
        try await service.startRecording()
        XCTAssertTrue(service.isRecording)

        // WHEN stopping recording
        _ = await service.stopRecording()

        // THEN isRecording is false
        XCTAssertFalse(service.isRecording)
    }

    func testStopRecordingReturnsTranscription() async throws {
        // GIVEN recording with transcription
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true
        try await service.startRecording()

        // Simulate transcription
        mockRecognizer.simulateTranscription("Hello world")

        // WHEN stopping recording
        let transcription = await service.stopRecording()

        // THEN transcription is returned
        XCTAssertEqual(transcription, "Hello world")
    }

    func testStartRecordingThrowsError_WhenAlreadyRecording() async throws {
        // GIVEN recording is already in progress
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true
        try await service.startRecording()

        // WHEN trying to start recording again
        // THEN it throws alreadyRecording error
        do {
            try await service.startRecording()
            XCTFail("Expected alreadyRecording error")
        } catch let error as SpeechRecognitionError {
            XCTAssertEqual(error, SpeechRecognitionError.alreadyRecording)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testStartRecordingThrowsError_WhenRecognizerUnavailable() async {
        // GIVEN recognizer is unavailable
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = false

        // WHEN starting recording
        // THEN it throws recognizerUnavailable error
        do {
            try await service.startRecording()
            XCTFail("Expected recognizerUnavailable error")
        } catch let error as SpeechRecognitionError {
            XCTAssertEqual(error, SpeechRecognitionError.recognizerUnavailable)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Transcription Publisher Tests

    func testTranscriptionPublisherEmitsUpdates() async throws {
        // GIVEN recording is in progress
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true

        var receivedTranscriptions: [String] = []
        let expectation = expectation(description: "Receive transcriptions")
        expectation.expectedFulfillmentCount = 3

        service.$transcription
            .sink { text in
                receivedTranscriptions.append(text)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await service.startRecording()

        // WHEN transcriptions are received
        mockRecognizer.simulateTranscription("Hello")
        mockRecognizer.simulateTranscription("Hello world")
        mockRecognizer.simulateTranscription("Hello world test")

        // THEN publisher emits updates
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTranscriptions.count, 3)
        XCTAssertEqual(receivedTranscriptions.last, "Hello world test")
    }

    // MARK: - Multiple Start/Stop Cycles Tests

    func testMultipleStartStopCyclesWorkCorrectly() async throws {
        // GIVEN permission is granted
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true

        // Cycle 1
        try await service.startRecording()
        XCTAssertTrue(service.isRecording)
        _ = await service.stopRecording()
        XCTAssertFalse(service.isRecording)

        // Cycle 2
        try await service.startRecording()
        XCTAssertTrue(service.isRecording)
        _ = await service.stopRecording()
        XCTAssertFalse(service.isRecording)

        // Cycle 3
        try await service.startRecording()
        XCTAssertTrue(service.isRecording)
        _ = await service.stopRecording()
        XCTAssertFalse(service.isRecording)
    }

    // MARK: - Silence Detection Tests

    func testSilenceDetectionTriggersAutoStop() async throws {
        // GIVEN recording is in progress with silence timeout of 1 second
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true

        let serviceWithShortTimeout = SpeechRecognitionService(
            recognizer: mockRecognizer,
            audioEngine: mockAudioEngine,
            audioSession: mockAudioSession,
            silenceTimeout: 0.5  // 0.5 seconds for test
        )

        try await serviceWithShortTimeout.startRecording()
        XCTAssertTrue(serviceWithShortTimeout.isRecording)

        // Simulate some transcription
        mockRecognizer.simulateTranscription("Test")

        // WHEN silence timeout elapses
        try await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds

        // THEN recording stops automatically
        XCTAssertFalse(serviceWithShortTimeout.isRecording)
    }

    // MARK: - Audio Engine Tests

    func testStartRecordingStartsAudioEngine() async throws {
        // GIVEN permission granted
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true

        // WHEN starting recording
        try await service.startRecording()

        // THEN audio engine is started
        XCTAssertTrue(mockAudioEngine.startCalled)
    }

    func testStopRecordingStopsAudioEngine() async throws {
        // GIVEN recording in progress
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true
        try await service.startRecording()

        // WHEN stopping recording
        _ = await service.stopRecording()

        // THEN audio engine is stopped
        XCTAssertTrue(mockAudioEngine.stopCalled)
    }

    func testStartRecordingThrowsError_WhenAudioEngineFailsToStart() async {
        // GIVEN audio engine will fail
        mockRecognizer.authStatus = .authorized
        mockRecognizer.available = true
        mockAudioEngine.shouldFailStart = true

        // WHEN starting recording
        // THEN it throws microphone unavailable error
        do {
            try await service.startRecording()
            XCTFail("Expected microphoneUnavailable error")
        } catch let error as SpeechRecognitionError {
            XCTAssertEqual(error, SpeechRecognitionError.microphoneUnavailable)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - Mock Implementations

class MockSpeechRecognizer: SpeechRecognizerProtocol {
    var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var available: Bool = true
    var authRequestHandler: ((SFSpeechRecognizerAuthorizationStatus) -> Void)?
    var resultHandler: ((SFSpeechRecognitionResult?, Error?) -> Void)?

    var isAvailable: Bool {
        return available
    }

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        return authStatus
    }

    func requestAuthorization(_ handler: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        self.authRequestHandler = handler
        // Immediately call with current status
        handler(authStatus)
    }

    func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest,
                        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask? {
        self.resultHandler = resultHandler
        return MockSpeechRecognitionTask()
    }

    func simulateTranscription(_ text: String) {
        let result = MockSpeechRecognitionResult(text: text)
        resultHandler?(result, nil)
    }
}

class MockSpeechRecognitionTask: SFSpeechRecognitionTask {
    private var _isCancelled = false

    override var state: SFSpeechRecognitionTaskState {
        return _isCancelled ? .canceling : .running
    }

    override func cancel() {
        _isCancelled = true
    }
}

class MockSpeechRecognitionResult: SFSpeechRecognitionResult {
    private let mockText: String

    init(text: String) {
        self.mockText = text
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var bestTranscription: SFTranscription {
        return MockTranscription(text: mockText)
    }

    override var isFinal: Bool {
        return false
    }
}

class MockTranscription: SFTranscription {
    private let mockText: String

    init(text: String) {
        self.mockText = text
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var formattedString: String {
        return mockText
    }
}

class MockAudioEngine: AudioEngineProtocol {
    var startCalled = false
    var stopCalled = false
    var prepareCalled = false
    var resetCalled = false
    var shouldFailStart = false
    private var _isRunning = false
    private let mockEngine = AVAudioEngine()

    var inputNode: AVAudioInputNode {
        return mockEngine.inputNode
    }

    var isRunning: Bool {
        return _isRunning
    }

    func prepare() {
        prepareCalled = true
    }

    func start() throws {
        startCalled = true
        if shouldFailStart {
            throw NSError(domain: "MockAudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start"])
        }
        _isRunning = true
    }

    func stop() {
        stopCalled = true
        _isRunning = false
    }

    func reset() {
        resetCalled = true
    }
}

class MockAudioSession: AudioSessionProtocol {
    var setCategoryCalled = false
    var setActiveCalled = false

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        setCategoryCalled = true
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        setActiveCalled = true
    }
}
