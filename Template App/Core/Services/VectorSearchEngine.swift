// ABOUTME: Vector search engine for semantic note search using cosine similarity
// ABOUTME: Provides indexing, searching with relevance threshold, and result ranking

import Foundation

/// Search result with note ID and relevance score
struct SearchResult: Equatable {
    let noteId: UUID
    let relevance: Float // Cosine similarity (0.0 to 1.0)
}

/// Vector search engine for semantic search using embeddings
actor VectorSearchEngine {

    // MARK: - Properties

    private let embeddingService: EmbeddingService
    private var index: [UUID: [Float]] = [:]

    // MARK: - Initialization

    init(embeddingService: EmbeddingService) {
        self.embeddingService = embeddingService
    }

    // MARK: - Indexing Operations

    /// Index a note with its embedding
    /// - Parameters:
    ///   - id: Note UUID
    ///   - embedding: Embedding vector for the note
    func indexNote(id: UUID, embedding: [Float]) {
        index[id] = embedding
    }

    /// Remove a note from the index
    /// - Parameter id: Note UUID to remove
    func removeNote(id: UUID) {
        index.removeValue(forKey: id)
    }

    /// Rebuild the index (clear all indexed notes)
    func rebuild() {
        index.removeAll()
    }

    // MARK: - Search Operations

    /// Search for notes using query text
    /// - Parameters:
    ///   - query: Search query text
    ///   - threshold: Minimum relevance threshold (0.0 to 1.0, default 0.7)
    /// - Returns: Array of search results sorted by descending relevance
    /// - Throws: Error if embedding generation fails
    func search(query: String, threshold: Float = 0.7) async throws -> [SearchResult] {
        // Generate embedding for query
        let queryEmbedding = try await embeddingService.generateEmbedding(for: query)

        // Compute similarity with all indexed notes
        var results: [SearchResult] = []

        for (noteId, noteEmbedding) in index {
            let similarity = cosineSimilarity(queryEmbedding, noteEmbedding)

            // Filter by threshold
            if similarity >= threshold {
                results.append(SearchResult(noteId: noteId, relevance: similarity))
            }
        }

        // Sort by descending relevance (highest first)
        results.sort { $0.relevance > $1.relevance }

        return results
    }

    // MARK: - Private Helpers

    /// Compute cosine similarity between two embedding vectors
    /// - Parameters:
    ///   - a: First embedding vector
    ///   - b: Second embedding vector
    /// - Returns: Cosine similarity (0.0 to 1.0)
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }

        var dotProduct: Float = 0.0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
        }

        // Since embeddings are normalized (magnitude = 1.0),
        // cosine similarity is just the dot product
        // Clamp to [0.0, 1.0] range to handle floating point errors
        return max(0.0, min(1.0, dotProduct))
    }
}
