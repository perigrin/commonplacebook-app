// ABOUTME: Protocol definitions for search-related services
// ABOUTME: Enables dependency injection and testability for embedding and search engines

import Foundation

/// Protocol for embedding generation services
protocol EmbeddingServiceProtocol: Actor {
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

/// Protocol for vector search engines
protocol VectorSearchEngineProtocol: Actor {
    /// Index a note with its embedding
    /// - Parameters:
    ///   - id: Note UUID
    ///   - embedding: Embedding vector for the note
    /// - Throws: VectorSearchError if indexing fails
    func indexNote(id: UUID, embedding: [Float]) async throws
    
    /// Remove a note from the index
    /// - Parameter id: Note UUID to remove
    func removeNote(id: UUID) async
    
    /// Rebuild the index (clear all indexed notes)
    func rebuild() async
    
    /// Search for notes using query text
    /// - Parameters:
    ///   - query: Search query text
    ///   - threshold: Minimum relevance threshold (0.0 to 1.0)
    /// - Returns: Array of search results sorted by descending relevance
    /// - Throws: Error if search fails
    func search(query: String, threshold: Float) async throws -> [SearchResult]
}
