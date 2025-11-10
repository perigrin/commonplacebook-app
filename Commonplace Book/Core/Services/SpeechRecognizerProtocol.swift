// ABOUTME: Protocol wrapper for SFSpeechRecognizer for dependency injection
// ABOUTME: Enables mocking Speech framework in tests

import Foundation
import Speech

/// Protocol abstracting SFSpeechRecognizer for testing
protocol SpeechRecognizerProtocol {
    var isAvailable: Bool { get }
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus { get }

    func requestAuthorization(_ handler: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void)
    func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest,
                        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask?
}

/// Production implementation wrapping SFSpeechRecognizer
class ProductionSpeechRecognizer: SpeechRecognizerProtocol {
    private let recognizer: SFSpeechRecognizer

    init(locale: Locale = Locale.current) {
        // Try requested locale first, fall back to en-US if unsupported
        if let recognizer = SFSpeechRecognizer(locale: locale) {
            self.recognizer = recognizer
        } else if let fallbackRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            self.recognizer = fallbackRecognizer
        } else {
            // Last resort: try device locale
            self.recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()!
        }
    }

    var isAvailable: Bool {
        return recognizer.isAvailable
    }

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        return SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization(_ handler: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        SFSpeechRecognizer.requestAuthorization(handler)
    }

    func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest,
                        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask? {
        return recognizer.recognitionTask(with: request, resultHandler: resultHandler)
    }
}
