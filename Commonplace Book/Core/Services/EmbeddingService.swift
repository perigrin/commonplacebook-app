// ABOUTME: Service for generating vector embeddings using BERT sentence transformers
// ABOUTME: Provides caching, batch processing, and BERT model integration via swift-embeddings

import Foundation
import Embeddings

/// Errors that can occur during embedding generation
enum EmbeddingServiceError: Error, Equatable {
    case modelNotLoaded
    case invalidInput
    case modelLoadFailed(String)
}

/// Service for generating vector embeddings for semantic search using BERT
/// Uses all-MiniLM-L6-v2 sentence transformer model from Hugging Face
class EmbeddingService: EmbeddingServiceProtocol {

    // MARK: - Constants

    private static let defaultEmbeddingDimension = 384 // all-MiniLM-L6-v2 dimension
    private static let defaultCacheSize = 1000
    private static let modelID = "sentence-transformers/all-MiniLM-L6-v2"

    // MARK: - Properties

    /// Dimension of embedding vectors
    let embeddingDimension: Int

    private var modelBundle: Bert.ModelBundle?
    private let cache: EmbeddingCache

    private var isModelLoaded: Bool {
        modelBundle != nil
    }

    // MARK: - Initialization

    init(embeddingDimension: Int = defaultEmbeddingDimension,
         cacheSize: Int = defaultCacheSize) {
        self.embeddingDimension = embeddingDimension
        self.cache = EmbeddingCache(maxSize: cacheSize)
    }

    // MARK: - Model Management

    /// Load the BERT embedding model from Hugging Face
    /// Downloads and initializes all-MiniLM-L6-v2 sentence transformer
    func loadModel() async throws {
        do {
            // Load BERT model bundle from Hugging Face
            // This downloads the model on first use and caches it locally
            modelBundle = try await Bert.loadModelBundle(from: Self.modelID)
        } catch {
            throw EmbeddingServiceError.modelLoadFailed("Failed to load BERT model: \(error.localizedDescription)")
        }
    }

    // MARK: - Single Embedding Generation

    /// Generate embedding for a single text using BERT
    /// - Parameter text: Input text to embed
    /// - Returns: Normalized embedding vector (384 dimensions)
    /// - Throws: EmbeddingServiceError if model not loaded
    func generateEmbedding(for text: String) async throws -> [Float] {
        guard let modelBundle = modelBundle else {
            throw EmbeddingServiceError.modelNotLoaded
        }

        // Check cache first
        if let cachedEmbedding = await cache.get(text) {
            return cachedEmbedding
        }

        // Generate new embedding using BERT model
        let embedding = await generateBERTEmbedding(for: text, using: modelBundle)

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

    // MARK: - BERT Embedding Generation

    /// Generate embedding using BERT sentence transformer model
    /// - Parameters:
    ///   - text: Input text to encode
    ///   - modelBundle: Loaded BERT model bundle
    /// - Returns: Normalized 384-dimensional embedding vector
    private func generateBERTEmbedding(for text: String, using modelBundle: Bert.ModelBundle) async -> [Float] {
        // Encode text using BERT model
        let encoded = modelBundle.encode(text)

        // Convert to Float array
        let result = await encoded.cast(to: Float.self)
            .shapedArray(of: Float.self).scalars

        return result
    }
}
