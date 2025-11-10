// ABOUTME: Protocol wrapper for AVAudioEngine for dependency injection
// ABOUTME: Enables mocking audio engine in tests

import Foundation
import AVFoundation

/// Protocol abstracting AVAudioEngine for testing
protocol AudioEngineProtocol {
    var inputNode: AVAudioInputNode { get }
    var isRunning: Bool { get }

    func prepare()
    func start() throws
    func stop()
    func reset()
}

/// Production implementation wrapping AVAudioEngine
class ProductionAudioEngine: AudioEngineProtocol {
    private let engine: AVAudioEngine

    init() {
        self.engine = AVAudioEngine()
    }

    var inputNode: AVAudioInputNode {
        return engine.inputNode
    }

    var isRunning: Bool {
        return engine.isRunning
    }

    func prepare() {
        engine.prepare()
    }

    func start() throws {
        try engine.start()
    }

    func stop() {
        engine.stop()
    }

    func reset() {
        engine.reset()
    }
}

/// Protocol abstracting audio session management for testing
/// Note: macOS doesn't require explicit audio session management like iOS
protocol AudioSessionProtocol {
    func configure() throws
    func activate() throws
    func deactivate() throws
}

/// macOS implementation of audio session (no-op since macOS doesn't need session management)
class ProductionAudioSession: AudioSessionProtocol {
    init() {
        // macOS doesn't require audio session initialization
    }

    func configure() throws {
        // macOS doesn't require audio session configuration
        // Audio permissions are handled at the system level
    }

    func activate() throws {
        // macOS doesn't require explicit activation
    }

    func deactivate() throws {
        // macOS doesn't require explicit deactivation
    }
}
