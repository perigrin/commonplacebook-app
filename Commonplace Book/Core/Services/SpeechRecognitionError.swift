// ABOUTME: Error types for speech recognition service
// ABOUTME: Defines specific errors for permission, recognition, and hardware failures

import Foundation

/// Errors that can occur during speech recognition
enum SpeechRecognitionError: LocalizedError, Equatable {
    case permissionDenied
    case recognitionFailed(String)
    case microphoneUnavailable
    case alreadyRecording
    case notRecording
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .recognitionFailed(let reason):
            return "Speech recognition failed: \(reason)"
        case .microphoneUnavailable:
            return "Microphone is unavailable"
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording in progress"
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable for this locale"
        }
    }
}
