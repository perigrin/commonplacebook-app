// ABOUTME: Protocol defining the interface for embedding generation services
// ABOUTME: Enables dependency injection and testing with mock implementations

import Foundation

/// Protocol for services that generate vector embeddings
protocol EmbeddingServiceProtocol {
    /// Dimension of embedding vectors
    var embeddingDimension: Int { get }

    /// Load the embedding model
    /// - Throws: EmbeddingServiceError if model loading fails
    func loadModel() async throws

    /// Generate embedding for a single text
    /// - Parameter text: Input text to embed
    /// - Returns: Normalized embedding vector
    /// - Throws: EmbeddingServiceError if model not loaded or generation fails
    func generateEmbedding(for text: String) async throws -> [Float]

    /// Generate embeddings for multiple texts
    /// - Parameter texts: Array of input texts
    /// - Returns: Array of embedding vectors
    /// - Throws: EmbeddingServiceError if model not loaded or generation fails
    func generateEmbeddings(for texts: [String]) async throws -> [[Float]]
}

/// Error type for vector search operations
enum VectorSearchError: Error, Equatable {
    case dimensionMismatch(expected: Int, actual: Int)
    case indexCapacityExceeded
}
