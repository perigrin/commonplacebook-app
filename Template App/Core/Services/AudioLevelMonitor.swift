// ABOUTME: Service for monitoring microphone audio levels in real-time
// ABOUTME: Publishes normalized audio level (0.0-1.0) for visualization and feedback

import Foundation
import AVFoundation
import Combine

/// Service for monitoring microphone audio input levels
@MainActor
class AudioLevelMonitor: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isMonitoring: Bool = false

    // MARK: - Private Properties

    private let audioEngine: AudioEngineProtocol
    private let audioLevelQueue = DispatchQueue(label: "audio.level.processing", qos: .userInteractive)

    // MARK: - Initialization

    init(audioEngine: AudioEngineProtocol? = nil) {
        self.audioEngine = audioEngine ?? ProductionAudioEngine()
    }

    // MARK: - Monitoring Control

    /// Start monitoring audio levels
    /// - Throws: AudioLevelMonitorError.alreadyMonitoring if already monitoring
    func startMonitoring() throws {
        guard !isMonitoring else {
            throw AudioLevelMonitorError.alreadyMonitoring
        }

        // Prepare and start the audio engine
        audioEngine.prepare()
        try audioEngine.start()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap to monitor audio levels
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Process on background queue to avoid blocking audio thread
            self.audioLevelQueue.async { [weak self] in
                guard let self = self else { return }
                let level = self.calculateAudioLevel(from: buffer)

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.audioLevel = level
                }
            }
        }

        isMonitoring = true
    }

    /// Stop monitoring audio levels
    func stopMonitoring() {
        guard isMonitoring else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isMonitoring = false
        audioLevel = 0.0
    }

    // MARK: - Audio Processing

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0.0
        }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        // Calculate RMS (Root Mean Square) for audio level
        var sum: Float = 0.0
        for frame in 0..<frameLength {
            let sample = channelDataValue[frame]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))

        // Convert to decibels and normalize to 0.0-1.0 range
        // -160 dB (silence) to 0 dB (max) mapped to 0.0-1.0
        let db = 20 * log10(max(rms, 0.00001)) // Avoid log(0)
        let normalized = max(0.0, min(1.0, (db + 160) / 160))

        return normalized
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
