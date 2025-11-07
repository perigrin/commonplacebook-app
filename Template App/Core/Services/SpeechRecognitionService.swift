// ABOUTME: Service for speech-to-text transcription using Apple Speech framework
// ABOUTME: Handles permissions, real-time transcription, silence detection, and audio engine management

import Foundation
import Speech
import AVFoundation
import Combine

/// Service for managing speech recognition with real-time transcription
@MainActor
class SpeechRecognitionService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isRecording: Bool = false
    @Published var transcription: String = ""

    /// Publisher for transcription updates
    var transcriptionPublisher: Published<String>.Publisher {
        return $transcription
    }

    // MARK: - Private Properties

    private let recognizer: SpeechRecognizerProtocol
    private let audioEngine: AudioEngineProtocol
    private let audioSession: AudioSessionProtocol
    private let silenceTimeout: TimeInterval

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Task<Void, Never>?
    private var lastTranscriptionTime: Date?

    // MARK: - Initialization

    init(recognizer: SpeechRecognizerProtocol? = nil,
         audioEngine: AudioEngineProtocol? = nil,
         audioSession: AudioSessionProtocol? = nil,
         silenceTimeout: TimeInterval = 3.0) {
        self.recognizer = recognizer ?? ProductionSpeechRecognizer()
        self.audioEngine = audioEngine ?? ProductionAudioEngine()
        self.audioSession = audioSession ?? ProductionAudioSession()
        self.silenceTimeout = silenceTimeout
    }

    // MARK: - Permission

    /// Request speech recognition permission
    /// - Returns: true if permission granted, false otherwise
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            recognizer.requestAuthorization { status in
                Task { @MainActor in
                    let granted = status == .authorized
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Recording Control

    /// Start recording and speech recognition
    /// - Throws: SpeechRecognitionError on permission denied, recognizer unavailable, or audio failures
    func startRecording() async throws {
        // Check if already recording
        guard !isRecording else {
            throw SpeechRecognitionError.alreadyRecording
        }

        // Check permission
        guard recognizer.authorizationStatus == .authorized else {
            throw SpeechRecognitionError.permissionDenied
        }

        // Check recognizer availability
        guard recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        // Configure audio session
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        // Create and configure recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true  // On-device recognition
        self.recognitionRequest = request

        // Start audio engine
        do {
            audioEngine.prepare()
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            try audioEngine.start()
        } catch {
            // Clean up tap on failure
            audioEngine.inputNode.removeTap(onBus: 0)
            throw SpeechRecognitionError.microphoneUnavailable
        }

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    self.handleRecognitionError(error)
                    return
                }

                if let result = result {
                    self.transcription = result.bestTranscription.formattedString
                    self.lastTranscriptionTime = Date()

                    // Restart silence timer
                    self.restartSilenceTimer()
                }
            }
        }

        isRecording = true
        transcription = ""
        lastTranscriptionTime = Date()

        // Start silence detection (using one-shot timer approach)
        restartSilenceTimer()
    }

    /// Stop recording and return final transcription
    /// - Returns: Final transcribed text
    func stopRecording() async -> String {
        guard isRecording else {
            return transcription
        }

        // Stop silence detection
        silenceTimer?.cancel()
        silenceTimer = nil

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Deactivate audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        // Cancel recognition request and task
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isRecording = false

        return transcription
    }

    // MARK: - Silence Detection

    private func restartSilenceTimer() {
        // Cancel existing timer
        silenceTimer?.cancel()

        // Start new timer
        silenceTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(silenceTimeout * 1_000_000_000))

            guard !Task.isCancelled else { return }

            // Check if enough time has passed since last transcription
            if let lastTime = lastTranscriptionTime,
               Date().timeIntervalSince(lastTime) >= silenceTimeout {
                // Silence detected - stop recording
                _ = await self.stopRecording()
            }
        }
    }

    // MARK: - Error Handling

    private func handleRecognitionError(_ error: Error) {
        // Stop recording on error
        Task { @MainActor in
            _ = await self.stopRecording()
        }
    }
}
