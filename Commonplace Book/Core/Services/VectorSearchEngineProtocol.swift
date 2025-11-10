// ABOUTME: Protocol for vector search engine to enable dependency injection and testing
// ABOUTME: Defines interface for indexing notes and performing semantic search operations

import Foundation

/// Protocol for vector search engine implementations
protocol VectorSearchEngineProtocol {
    /// Index a note with its embedding
    /// - Parameters:
    ///   - id: Note UUID
    ///   - embedding: Embedding vector for the note
    /// - Throws: VectorSearchError if operation fails
    func indexNote(id: UUID, embedding: [Float]) async throws

    /// Remove a note from the index
    /// - Parameter id: Note UUID to remove
    func removeNote(id: UUID) async

    /// Search for notes using query text
    /// - Parameters:
    ///   - query: Search query text
    ///   - threshold: Minimum relevance threshold (0.0 to 1.0)
    /// - Returns: Array of search results sorted by descending relevance
    /// - Throws: Error if operation fails
    func search(query: String, threshold: Float) async throws -> [SearchResult]

    /// Rebuild the index (clear all indexed notes)
    func rebuild() async
}
