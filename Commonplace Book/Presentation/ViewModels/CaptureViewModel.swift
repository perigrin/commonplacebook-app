// ABOUTME: View model coordinating speech recognition, audio monitoring, and note creation
// ABOUTME: Manages recording lifecycle and integrates metadata collection with repository

import Foundation
import Combine

/// View model for note capture via speech recognition
@MainActor
class CaptureViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isRecording: Bool = false
    @Published private(set) var transcription: String = ""
    @Published private(set) var audioLevel: Float = 0.0
    @Published var error: Error?

    // MARK: - Private Properties

    private let speechService: SpeechRecognitionService
    private let audioMonitor: AudioLevelMonitor
    private let metadataCollector: MetadataCollector
    private let repository: NoteRepository
    private let titleGenerator: TitleGenerator
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(speechService: SpeechRecognitionService? = nil,
         audioMonitor: AudioLevelMonitor? = nil,
         metadataCollector: MetadataCollector? = nil,
         repository: NoteRepository,
         titleGenerator: TitleGenerator? = nil) {
        self.speechService = speechService ?? SpeechRecognitionService()
        self.audioMonitor = audioMonitor ?? AudioLevelMonitor()
        self.metadataCollector = metadataCollector ?? MetadataCollector()
        self.repository = repository
        self.titleGenerator = titleGenerator ?? TitleGenerator()

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind transcription from speech service with thread safety
        speechService.$transcription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcription = text
            }
            .store(in: &cancellables)

        // Bind audio level from monitor with thread safety
        audioMonitor.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }

    // MARK: - Recording Control

    /// Start recording with speech recognition and audio monitoring
    func startRecording() async {
        // Guard against duplicate calls
        guard !isRecording else { return }

        error = nil

        // Request permission
        let permissionGranted = await speechService.requestPermission()
        guard permissionGranted else {
            error = CaptureViewModelError.permissionDenied
            return
        }

        // Start speech recognition
        do {
            try await speechService.startRecording()
        } catch {
            self.error = error
            return
        }

        // Start audio monitoring
        do {
            try audioMonitor.startMonitoring()
        } catch {
            self.error = error
            // Clean up: stop speech recognition
            do {
                _ = try await speechService.stopRecording()
            } catch {
                // Ignore cleanup errors, original error already set
            }
            return
        }

        isRecording = true
    }

    /// Stop recording and return note with transcription (without saving)
    /// - Returns: Note with transcription and metadata, or nil if empty
    func stopRecording() async -> Note? {
        guard isRecording else { return nil }

        // Stop audio monitoring
        audioMonitor.stopMonitoring()

        // Stop speech recognition
        let finalTranscription = await speechService.stopRecording()
        transcription = finalTranscription

        isRecording = false

        // Create note from transcription without saving
        let content = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }

        // Collect metadata
        let device = await metadataCollector.getCurrentDevice()
        let timestamp = await metadataCollector.generateTimestamp()
        let location = await metadataCollector.getCurrentLocation()

        // Extract title
        let title = extractTitle(from: content)

        // Return note without saving to repository
        return Note(
            id: UUID(),
            created: timestamp,
            device: device,
            location: location,
            content: content,
            title: title,
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
    }

    /// Cancel recording and discard transcription
    func cancelRecording() {
        guard isRecording else { return }

        // Stop audio monitoring
        audioMonitor.stopMonitoring()

        // Stop speech recognition
        Task {
            _ = await speechService.stopRecording()
        }

        // Clear transcription
        transcription = ""

        isRecording = false
    }

    /// Save note with transcription and metadata
    /// - Returns: Created note, or nil if transcription is empty
    func saveNote() async -> Note? {
        // Validate transcription
        let content = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return nil
        }

        // Collect metadata
        let device = await metadataCollector.getCurrentDevice()
        let timestamp = await metadataCollector.generateTimestamp()
        let location = await metadataCollector.getCurrentLocation()

        // Extract title from first line or use first few words
        let title = extractTitle(from: content)

        // Create note
        let note = Note(
            id: UUID(),
            created: timestamp,
            device: device,
            location: location,
            content: content,
            title: title,
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // Save to repository
        do {
            let savedNote = try await repository.create(note: note)

            // Clear transcription after successful save
            transcription = ""

            return savedNote
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Private Helpers

    private func extractTitle(from content: String) -> String {
        // Use TitleGenerator for smart title extraction
        return titleGenerator.generateTitle(from: content)
    }
}

/// Errors specific to capture view model
enum CaptureViewModelError: LocalizedError {
    case permissionDenied
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone and speech recognition permissions are required"
        case .emptyTranscription:
            return "No audio was captured. Please try recording again."
        }
    }
}
