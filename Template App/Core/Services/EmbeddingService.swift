// ABOUTME: Service for generating vector embeddings using deterministic text hashing
// ABOUTME: Provides caching, batch processing, and proper interface for Core ML integration

import Foundation

/// Errors that can occur during embedding generation
enum EmbeddingServiceError: Error, Equatable {
    case modelNotLoaded
    case invalidInput
    case modelLoadFailed(String)
}

/// Service for generating vector embeddings for semantic search
/// NOTE: This implementation uses word-based deterministic embeddings for testing.
/// TODO: Replace with actual Core ML sentence transformer model (e.g., all-MiniLM-L6-v2)
///       See loadModel() for integration points.
class EmbeddingService: EmbeddingServiceProtocol {

    // MARK: - Constants

    private static let defaultEmbeddingDimension = 384 // Common for MiniLM models
    private static let defaultCacheSize = 1000

    // MARK: - Properties

    /// Dimension of embedding vectors
    let embeddingDimension: Int

    private var isModelLoaded = false
    private let cache: EmbeddingCache
    private let processingQueue = DispatchQueue(label: "embedding.processing", qos: .userInitiated)

    // MARK: - Initialization

    init(embeddingDimension: Int = defaultEmbeddingDimension,
         cacheSize: Int = defaultCacheSize) {
        self.embeddingDimension = embeddingDimension
        self.cache = EmbeddingCache(maxSize: cacheSize)
    }

    // MARK: - Model Management

    /// Load the embedding model
    /// NOTE: Current implementation uses word-based deterministic embeddings for testing.
    /// TODO: Replace with actual Core ML model loading:
    /// ```
    /// guard let modelURL = Bundle.main.url(forResource: "SentenceTransformer",
    ///                                       withExtension: "mlmodelc") else {
    ///     throw EmbeddingServiceError.modelLoadFailed("Model file not found")
    /// }
    /// let config = MLModelConfiguration()
    /// self.model = try await MLModel.load(contentsOf: modelURL, configuration: config)
    /// ```
    func loadModel() async throws {
        // Simulate async model loading with short delay
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

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
        if let cachedEmbedding = await cache.get(text) {
            return cachedEmbedding
        }

        // Generate new embedding on background queue
        let embedding = await withCheckedContinuation { continuation in
            processingQueue.async {
                let result = self.generateWordBasedEmbedding(for: text)
                continuation.resume(returning: result)
            }
        }

        // Cache the result
        await cache.put(text, embedding)

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

        // Process each text (check cache, generate if needed)
        var embeddings: [[Float]] = []

        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            embeddings.append(embedding)
        }

        return embeddings
    }

    // MARK: - Word-Based Embedding Generation

    /// Generate word-based embedding for better semantic similarity
    /// NOTE: This is a placeholder that provides better similarity than pure hashing
    /// TODO: Replace with actual Core ML model inference
    private func generateWordBasedEmbedding(for text: String) -> [Float] {
        var embedding = [Float](repeating: 0.0, count: embeddingDimension)

        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract words for word-based features
        let words = normalizedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Use word-based features for better semantic similarity
        for (wordIndex, word) in words.enumerated() {
            let wordHash = hashString(word, seed: 0)

            // Distribute word contribution across embedding
            // Each word affects multiple dimensions for better overlap
            for i in 0..<embeddingDimension {
                let position = (Int(wordHash) + i * 7) % embeddingDimension
                let bit = (wordHash >> (i % 64)) & 1
                let contribution = bit == 1 ? 1.0 : -1.0

                // Weight by word position (earlier words matter more)
                let positionWeight = 1.0 / Float(wordIndex + 1)
                embedding[position] += contribution * positionWeight * 0.3
            }
        }

        // Add character-level features for exact match detection
        for char in normalizedText {
            let charValue = Int(char.unicodeScalars.first?.value ?? 0)
            let charPosition = charValue % embeddingDimension
            embedding[charPosition] += 0.1
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

        // Mix the hash thoroughly
        hash ^= hash >> 33
        hash = hash &* 0xff51afd7ed558ccd
        hash ^= hash >> 33
        hash = hash &* 0xc4ceb9fe1a85ec53
        hash ^= hash >> 33

        return hash
    }
}
