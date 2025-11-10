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

/// Protocol abstracting AVAudioSession for testing
protocol AudioSessionProtocol {
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

/// Production implementation wrapping AVAudioSession
class ProductionAudioSession: AudioSessionProtocol {
    private let session: AVAudioSession

    init() {
        self.session = AVAudioSession.sharedInstance()
    }

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        try session.setCategory(category, mode: mode, options: options)
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        try session.setActive(active, options: options)
    }
}
