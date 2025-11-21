// ABOUTME: Service for generating vector embeddings using Apple's Natural Language framework
// ABOUTME: Provides caching, batch processing, and native NLEmbedding integration

import Foundation
import NaturalLanguage

/// Errors that can occur during embedding generation
enum EmbeddingServiceError: Error, Equatable {
    case modelNotLoaded
    case invalidInput
    case modelLoadFailed(String)
    case embeddingGenerationFailed
}

/// Service for generating vector embeddings for semantic search using NLEmbedding
/// Uses Apple's native sentence embedding model from the Natural Language framework
class EmbeddingService: EmbeddingServiceProtocol {

    // MARK: - Constants

    private static let defaultEmbeddingDimension = 512 // NLEmbedding dimension
    private static let defaultCacheSize = 1000

    // MARK: - Properties

    /// Dimension of embedding vectors
    let embeddingDimension: Int

    private var sentenceEmbedding: NLEmbedding?
    private let cache: EmbeddingCache

    private var isModelLoaded: Bool {
        sentenceEmbedding != nil
    }

    // MARK: - Initialization

    init(embeddingDimension: Int = defaultEmbeddingDimension,
         cacheSize: Int = defaultCacheSize) {
        self.embeddingDimension = embeddingDimension
        self.cache = EmbeddingCache(maxSize: cacheSize)
    }

    // MARK: - Model Management

    /// Load the NLEmbedding sentence model
    /// Uses Apple's built-in English sentence embedding model
    func loadModel() async throws {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw EmbeddingServiceError.modelLoadFailed("Failed to load NLEmbedding sentence model for English")
        }
        sentenceEmbedding = embedding
    }

    // MARK: - Single Embedding Generation

    /// Generate embedding for a single text using NLEmbedding
    /// - Parameter text: Input text to embed
    /// - Returns: Normalized embedding vector (512 dimensions)
    /// - Throws: EmbeddingServiceError if model not loaded
    func generateEmbedding(for text: String) async throws -> [Float] {
        guard let embedding = sentenceEmbedding else {
            throw EmbeddingServiceError.modelNotLoaded
        }

        // Check cache first
        if let cachedEmbedding = await cache.get(text) {
            return cachedEmbedding
        }

        // Generate new embedding using NLEmbedding
        guard let vector = embedding.vector(for: text) else {
            // Return zero vector for empty or invalid input
            let zeroVector = [Float](repeating: 0.0, count: embeddingDimension)
            await cache.put(text, zeroVector)
            return zeroVector
        }

        // Convert [Double] to [Float]
        let floatVector = vector.map { Float($0) }

        // Cache the result
        await cache.put(text, floatVector)

        return floatVector
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
}
