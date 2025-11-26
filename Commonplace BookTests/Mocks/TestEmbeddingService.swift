// ABOUTME: Shared mock embedding service for testing
// ABOUTME: Returns predictable test embeddings without requiring ML model loading

import Foundation
@testable import Commonplace_Book

/// Test embedding service that returns mock embeddings for testing
actor TestEmbeddingService: EmbeddingServiceProtocol {
    var embeddingDimension: Int { 384 }

    func loadModel() async throws {
        // No-op for testing
    }

    func generateEmbedding(for text: String) async throws -> [Float] {
        // Return a simple mock embedding
        return Array(repeating: 0.1, count: embeddingDimension)
    }

    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        // Return mock embeddings for each text
        return texts.map { _ in Array(repeating: 0.1, count: embeddingDimension) }
    }
}
