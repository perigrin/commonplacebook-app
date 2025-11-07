// ABOUTME: Vector search engine for semantic note search using cosine similarity
// ABOUTME: Provides indexing, searching with relevance threshold, and result ranking

import Foundation

/// Search result with note ID and relevance score
struct SearchResult: Equatable {
    let noteId: UUID
    let relevance: Float // Cosine similarity (0.0 to 1.0)
}

/// Vector search engine for semantic search using embeddings
actor VectorSearchEngine: VectorSearchEngineProtocol {

    // MARK: - Properties

    private let embeddingService: EmbeddingServiceProtocol
    private var index: [UUID: [Float]] = [:]
    private var indexOrder: [UUID] = [] // Track insertion order for LRU eviction
    private let expectedDimension: Int
    private let maxIndexSize: Int

    // MARK: - Initialization

    init(embeddingService: EmbeddingServiceProtocol,
         expectedDimension: Int = 384,
         maxIndexSize: Int = 10_000) {
        self.embeddingService = embeddingService
        self.expectedDimension = expectedDimension
        self.maxIndexSize = maxIndexSize
    }

    // MARK: - Indexing Operations

    /// Index a note with its embedding
    /// - Parameters:
    ///   - id: Note UUID
    ///   - embedding: Embedding vector for the note
    /// - Throws: VectorSearchError.dimensionMismatch if embedding dimension incorrect
    func indexNote(id: UUID, embedding: [Float]) throws {
        // Validate dimension
        guard embedding.count == expectedDimension else {
            throw VectorSearchError.dimensionMismatch(expected: expectedDimension, actual: embedding.count)
        }

        // Evict oldest if at capacity and this is a new note
        if index.count >= maxIndexSize && index[id] == nil {
            if let oldestId = indexOrder.first {
                index.removeValue(forKey: oldestId)
                indexOrder.removeFirst()
            }
        }

        // Store normalized embedding
        let normalized = normalizeEmbedding(embedding)
        index[id] = normalized

        // Update insertion order (remove if exists, add to end)
        if let existingIndex = indexOrder.firstIndex(of: id) {
            indexOrder.remove(at: existingIndex)
        }
        indexOrder.append(id)
    }

    /// Remove a note from the index
    /// - Parameter id: Note UUID to remove
    func removeNote(id: UUID) {
        index.removeValue(forKey: id)
        if let indexPos = indexOrder.firstIndex(of: id) {
            indexOrder.remove(at: indexPos)
        }
    }

    /// Rebuild the index (clear all indexed notes)
    func rebuild() {
        index.removeAll()
        indexOrder.removeAll()
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

        // Normalize query embedding
        let normalizedQuery = normalizeEmbedding(queryEmbedding)

        // Compute similarity with all indexed notes
        var results: [SearchResult] = []

        for (noteId, noteEmbedding) in index {
            let similarity = cosineSimilarity(normalizedQuery, noteEmbedding)

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

    /// Normalize an embedding vector to unit length
    /// - Parameter embedding: Input embedding vector
    /// - Returns: Normalized embedding with magnitude = 1.0
    private func normalizeEmbedding(_ embedding: [Float]) -> [Float] {
        let magnitude = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        guard magnitude > 0 else {
            return embedding // Return as-is if zero vector
        }
        return embedding.map { $0 / magnitude }
    }

    /// Compute cosine similarity between two embedding vectors
    /// Assumes both vectors are already normalized
    /// - Parameters:
    ///   - a: First embedding vector (normalized)
    ///   - b: Second embedding vector (normalized)
    /// - Returns: Cosine similarity (0.0 to 1.0)
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else {
            assertionFailure("Embedding dimension mismatch: \(a.count) vs \(b.count)")
            return 0.0
        }

        // For normalized vectors, cosine similarity is the dot product
        var dotProduct: Float = 0.0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
        }

        // Clamp to [0.0, 1.0] range to handle floating point errors
        return max(0.0, min(1.0, dotProduct))
    }
}
