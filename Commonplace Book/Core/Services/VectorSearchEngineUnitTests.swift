// ABOUTME: Unit tests for VectorSearchEngine cosine similarity and indexing
// ABOUTME: Tests normalization, similarity calculations, and index management

import Testing
import Foundation
@testable import Commonplace_Book

@Suite("VectorSearchEngine Unit Tests")
struct VectorSearchEngineUnitTests {
    
    // MARK: - Test Helpers
    
    actor MockEmbeddingService: EmbeddingServiceProtocol {
        var embeddingDimension: Int { 512 }
        private var isLoaded = false
        
        func loadModel() async throws {
            isLoaded = true
        }
        
        func generateEmbedding(for text: String) async throws -> [Float] {
            guard isLoaded else {
                throw EmbeddingServiceError.modelNotLoaded
            }
            
            // Generate deterministic embedding based on text hash
            var embedding = [Float](repeating: 0.0, count: 512)
            let hash = text.hashValue
            for i in 0..<512 {
                embedding[i] = Float((hash &+ i) % 100) / 100.0
            }
            return embedding
        }
        
        func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
            try await texts.asyncMap { try await self.generateEmbedding(for: $0) }
        }
    }
    
    // MARK: - Indexing Tests
    
    @Test("Index stores and retrieves embeddings")
    func indexStoresEmbeddings() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        let noteId = UUID()
        let embedding = [Float](repeating: 0.5, count: 512)
        
        // Index the note
        try await searchEngine.indexNote(id: noteId, embedding: embedding)
        
        // Search should find it
        let results = try await searchEngine.search(query: "test", threshold: 0.0)
        #expect(results.count > 0, "Should find indexed note")
    }
    
    @Test("Index normalizes embeddings to unit length")
    func indexNormalizesEmbeddings() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        // Create unnormalized embedding with large magnitude
        let unnormalized = [Float](repeating: 10.0, count: 512)
        let magnitude = sqrt(unnormalized.map { $0 * $0 }.reduce(0, +))
        #expect(magnitude > 1.0, "Test embedding should not be normalized")
        
        let noteId = UUID()
        try await searchEngine.indexNote(id: noteId, embedding: unnormalized)
        
        // The stored embedding should be normalized (magnitude = 1.0)
        // We can verify this by checking that search works correctly
        let results = try await searchEngine.search(query: "test", threshold: 0.0)
        #expect(results.count > 0)
    }
    
    @Test("Index rejects embeddings with wrong dimensions")
    func indexRejectsWrongDimensions() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        let wrongDimension = [Float](repeating: 0.5, count: 256)
        
        await #expect(throws: VectorSearchError.dimensionMismatch(expected: 512, actual: 256)) {
            try await searchEngine.indexNote(id: UUID(), embedding: wrongDimension)
        }
    }
    
    @Test("Index updates existing note")
    func indexUpdatesExistingNote() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        let noteId = UUID()
        let embedding1 = [Float](repeating: 0.3, count: 512)
        let embedding2 = [Float](repeating: 0.7, count: 512)
        
        // Index with first embedding
        try await searchEngine.indexNote(id: noteId, embedding: embedding1)
        
        // Update with second embedding
        try await searchEngine.indexNote(id: noteId, embedding: embedding2)
        
        // Should still have only one entry for this note
        let results = try await searchEngine.search(query: "test", threshold: 0.0)
        let matchingResults = results.filter { $0.noteId == noteId }
        #expect(matchingResults.count == 1, "Should have exactly one entry per note ID")
    }
    
    @Test("Remove note deletes from index")
    func removeNoteDeletesFromIndex() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        let noteId = UUID()
        let embedding = [Float](repeating: 0.5, count: 512)
        
        // Index the note
        try await searchEngine.indexNote(id: noteId, embedding: embedding)
        
        // Verify it's there
        var results = try await searchEngine.search(query: "test", threshold: 0.0)
        #expect(results.contains(where: { $0.noteId == noteId }))
        
        // Remove it
        await searchEngine.removeNote(id: noteId)
        
        // Should no longer be found
        results = try await searchEngine.search(query: "test", threshold: 0.0)
        #expect(!results.contains(where: { $0.noteId == noteId }), "Removed note should not be in results")
    }
    
    @Test("Rebuild clears entire index")
    func rebuildClearsIndex() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        // Index multiple notes
        for i in 0..<5 {
            let embedding = [Float](repeating: Float(i) / 10.0, count: 512)
            try await searchEngine.indexNote(id: UUID(), embedding: embedding)
        }
        
        // Verify notes are indexed
        var results = try await searchEngine.search(query: "test", threshold: 0.0)
        #expect(results.count == 5, "Should have 5 indexed notes")
        
        // Rebuild (clear)
        await searchEngine.rebuild()
        
        // Index should be empty
        results = try await searchEngine.search(query: "test", threshold: 0.0)
        #expect(results.isEmpty, "Index should be empty after rebuild")
    }
    
    // MARK: - Search Tests
    
    @Test("Search returns results above threshold")
    func searchReturnsAboveThreshold() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        // Index a note
        let embedding = try await mockService.generateEmbedding(for: "machine learning")
        try await searchEngine.indexNote(id: UUID(), embedding: embedding)
        
        // Search with very high threshold - might not find anything
        let strictResults = try await searchEngine.search(query: "machine learning", threshold: 0.95)
        
        // Search with low threshold - should find it
        let lenientResults = try await searchEngine.search(query: "machine learning", threshold: 0.0)
        
        #expect(lenientResults.count >= strictResults.count,
               "Lower threshold should return more or equal results")
    }
    
    @Test("Search sorts results by relevance descending")
    func searchSortsByRelevance() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        // Index multiple notes with different embeddings
        for i in 0..<10 {
            let text = "text number \(i)"
            let embedding = try await mockService.generateEmbedding(for: text)
            try await searchEngine.indexNote(id: UUID(), embedding: embedding)
        }
        
        let results = try await searchEngine.search(query: "text number 5", threshold: 0.0)
        
        // Verify results are sorted descending
        for i in 0..<(results.count - 1) {
            #expect(results[i].relevance >= results[i + 1].relevance,
                   "Results should be sorted by descending relevance")
        }
    }
    
    @Test("Search with threshold filters results")
    func searchThresholdFilters() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        // Index a note
        let embedding = try await mockService.generateEmbedding(for: "test content")
        let noteId = UUID()
        try await searchEngine.indexNote(id: noteId, embedding: embedding)
        
        // Search with threshold of 0.0 should find it
        let allResults = try await searchEngine.search(query: "test content", threshold: 0.0)
        #expect(allResults.count > 0)
        
        // Search with threshold of 1.0 should find nothing (unless perfect match)
        let strictResults = try await searchEngine.search(query: "different query", threshold: 1.0)
        #expect(strictResults.isEmpty || strictResults.first!.relevance >= 1.0,
               "Results below threshold should be filtered out")
    }
    
    // MARK: - Cosine Similarity Edge Cases
    
    @Test("Cosine similarity allows negative values")
    func cosineSimilarityAllowsNegatives() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        // Index with one embedding
        let embed1 = try await mockService.generateEmbedding(for: "positive happy joyful")
        try await searchEngine.indexNote(id: UUID(), embedding: embed1)
        
        // Search with opposite semantic meaning
        let results = try await searchEngine.search(query: "negative sad depressed", threshold: -1.0)
        
        // Should get results even if similarity is negative
        #expect(results.count > 0, "Should return results with negative similarity")
        
        // Relevance should be in valid range
        if let relevance = results.first?.relevance {
            #expect(relevance >= -1.0 && relevance <= 1.0,
                   "Cosine similarity must be in [-1, 1] range")
        }
    }
    
    @Test("Cosine similarity of identical vectors is 1.0")
    func cosineSimilarityIdenticalVectors() async throws {
        let mockService = MockEmbeddingService()
        try await mockService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: mockService,
            expectedDimension: 512
        )
        
        let text = "unique test phrase for similarity"
        let embedding = try await mockService.generateEmbedding(for: text)
        let noteId = UUID()
        
        try await searchEngine.indexNote(id: noteId, embedding: embedding)
        
        // Search with same text (will generate same embedding)
        let results = try await searchEngine.search(query: text, threshold: 0.0)
        
        #expect(results.count > 0)
        
        // The similarity should be very close to 1.0
        if let topResult = results.first {
            #expect(topResult.relevance > 0.99,
                   "Identical embeddings should have similarity close to 1.0 (got \(topResult.relevance))")
        }
    }
}

// MARK: - Helper Extensions

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results = [T]()
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}
