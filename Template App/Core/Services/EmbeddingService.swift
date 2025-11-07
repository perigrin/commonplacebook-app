// ABOUTME: Service for generating vector embeddings using deterministic text hashing
// ABOUTME: Provides caching, batch processing, and proper interface for Core ML integration

import Foundation
import CommonCrypto

/// Errors that can occur during embedding generation
enum EmbeddingServiceError: Error, Equatable {
    case modelNotLoaded
    case invalidInput
    case modelLoadFailed(String)
}

/// Service for generating vector embeddings for semantic search
/// NOTE: This implementation uses deterministic hash-based embeddings for testing.
/// TODO: Replace with actual Core ML sentence transformer model (e.g., all-MiniLM-L6-v2)
@MainActor
class EmbeddingService {

    // MARK: - Constants

    private static let defaultEmbeddingDimension = 384 // Common for MiniLM models
    private static let defaultCacheSize = 1000

    // MARK: - Properties

    /// Dimension of embedding vectors
    private(set) var embeddingDimension: Int

    private var isModelLoaded = false
    private let cacheSize: Int

    // LRU Cache implementation
    private var cache: [String: [Float]] = [:]
    private var accessOrder: [String] = []

    // MARK: - Initialization

    init(embeddingDimension: Int = defaultEmbeddingDimension,
         cacheSize: Int = defaultCacheSize) {
        self.embeddingDimension = embeddingDimension
        self.cacheSize = cacheSize
    }

    // MARK: - Model Management

    /// Load the embedding model
    /// NOTE: Current implementation uses deterministic hash-based embeddings.
    /// TODO: Replace with actual Core ML model loading
    func loadModel() async throws {
        // Simulate async model loading
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // TODO: Load actual Core ML model here
        // Example:
        // let config = MLModelConfiguration()
        // self.model = try await MLModel.load(contentsOf: modelURL, configuration: config)

        isModelLoaded = true
    }

    // MARK: - Single Embedding Generation

    /// Generate embedding for a single text
    /// - Parameter text: Input text to embed
    /// - Returns: Normalized embedding vector
    /// - Throws: EmbeddingServiceError if model not loaded
    func generateEmbedding(for text: String) async throws -> [Float] {
        guard isModelLoaded else {
            throw EmbeddingServiceError.modelNotLoaded
        }

        // Check cache first
        if let cachedEmbedding = getFromCache(text) {
            return cachedEmbedding
        }

        // Generate new embedding
        let embedding = generateDeterministicEmbedding(for: text)

        // Cache the result
        putInCache(text, embedding)

        return embedding
    }

    // MARK: - Batch Embedding Generation

    /// Generate embeddings for multiple texts
    /// - Parameter texts: Array of input texts
    /// - Returns: Array of embedding vectors
    /// - Throws: EmbeddingServiceError if model not loaded
    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        guard isModelLoaded else {
            throw EmbeddingServiceError.modelNotLoaded
        }

        guard !texts.isEmpty else {
            return []
        }

        // Process in batch for efficiency
        var embeddings: [[Float]] = []

        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            embeddings.append(embedding)
        }

        return embeddings
    }

    // MARK: - Cache Management

    private func getFromCache(_ key: String) -> [Float]? {
        guard let embedding = cache[key] else {
            return nil
        }

        // Update access order (LRU)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)

        return embedding
    }

    private func putInCache(_ key: String, _ embedding: [Float]) {
        // Evict oldest if cache is full
        if cache.count >= cacheSize && cache[key] == nil {
            if let oldestKey = accessOrder.first {
                cache.removeValue(forKey: oldestKey)
                accessOrder.removeFirst()
            }
        }

        cache[key] = embedding

        // Update access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }

    // MARK: - Deterministic Embedding Generation

    /// Generate deterministic embedding using text hashing
    /// NOTE: This is a placeholder for actual Core ML model inference
    /// TODO: Replace with real sentence transformer model
    private func generateDeterministicEmbedding(for text: String) -> [Float] {
        // Use multiple hash functions to generate embedding components
        var embedding = [Float](repeating: 0.0, count: embeddingDimension)

        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Generate embedding using multiple hash seeds
        let segmentSize = embeddingDimension / 4
        for segment in 0..<4 {
            let seed = UInt32(segment)
            let hash = hashString(normalizedText, seed: seed)

            // Distribute hash bits across embedding segment
            for i in 0..<segmentSize {
                let bitIndex = i % 64
                let bit = (hash >> bitIndex) & 1
                let value = bit == 1 ? 1.0 : -1.0

                // Add some variation based on text features
                let charValue = Float((normalizedText.count + i) % 100) / 100.0
                embedding[segment * segmentSize + i] = value * (0.8 + 0.2 * charValue)
            }
        }

        // Normalize the embedding vector (magnitude = 1.0)
        let magnitude = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }

        return embedding
    }

    /// Hash string with seed for deterministic pseudo-random generation
    private func hashString(_ string: String, seed: UInt32) -> UInt64 {
        var hash: UInt64 = UInt64(seed)

        for char in string.utf8 {
            hash = hash &* 31 &+ UInt64(char)
        }

        // Mix the hash
        hash ^= hash >> 33
        hash = hash &* 0xff51afd7ed558ccd
        hash ^= hash >> 33
        hash = hash &* 0xc4ceb9fe1a85ec53
        hash ^= hash >> 33

        return hash
    }
}
