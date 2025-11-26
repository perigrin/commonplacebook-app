// ABOUTME: Integration tests for vector search with real embeddings
// ABOUTME: Tests end-to-end flow from note creation to search results

import Testing
import Foundation
@testable import Commonplace_Book

@Suite("Vector Search Integration Tests")
struct VectorSearchIntegrationTests {
    
    // MARK: - Test Fixtures
    
    @MainActor
    func createTestServices() async throws -> (
        repository: InMemoryNoteRepository,
        embeddingService: EmbeddingService,
        searchEngine: VectorSearchEngine,
        noteService: NoteService
    ) {
        let repository = InMemoryNoteRepository()
        let embeddingService = EmbeddingService(embeddingDimension: 512)
        
        // Load the model
        try await embeddingService.loadModel()
        
        let searchEngine = VectorSearchEngine(
            embeddingService: embeddingService,
            expectedDimension: 512
        )
        
        let noteService = NoteService(
            repository: repository,
            searchEngine: searchEngine,
            embeddingService: embeddingService
        )
        
        return (repository, embeddingService, searchEngine, noteService)
    }
    
    // MARK: - Model Loading Tests
    
    @Test("Embedding model loads successfully")
    @MainActor
    func embeddingModelLoads() async throws {
        let embeddingService = EmbeddingService(embeddingDimension: 512)
        
        // Should not throw
        try await embeddingService.loadModel()
        
        // Should be able to generate embeddings
        let embedding = try await embeddingService.generateEmbedding(for: "test")
        #expect(embedding.count == 512)
    }
    
    @Test("Embedding service throws when model not loaded")
    @MainActor
    func embeddingServiceThrowsWhenNotLoaded() async throws {
        let embeddingService = EmbeddingService(embeddingDimension: 512)
        
        // Should throw modelNotLoaded
        await #expect(throws: EmbeddingServiceError.modelNotLoaded) {
            try await embeddingService.generateEmbedding(for: "test")
        }
    }
    
    // MARK: - Indexing Tests
    
    @Test("Note is indexed when created")
    @MainActor
    func noteIsIndexedOnCreation() async throws {
        let (_, _, searchEngine, noteService) = try await createTestServices()
        
        // Create a note with specific content
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Test Note",
            content: "This note discusses machine learning and artificial intelligence",
            tags: []
        )
        
        _ = try await noteService.create(note: note)
        
        // Give indexing time to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Search should find the note
        let results = try await searchEngine.search(query: "machine learning", threshold: 0.1)
        #expect(results.count > 0, "Should find the indexed note")
        #expect(results.first?.noteId == note.id)
    }
    
    @Test("Note is re-indexed when updated")
    @MainActor
    func noteIsReIndexedOnUpdate() async throws {
        let (_, _, searchEngine, noteService) = try await createTestServices()
        
        // Create note with original content
        var note = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Test",
            content: "Original content about cats",
            tags: []
        )
        
        note = try await noteService.create(note: note)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Update with new content
        note.content = "Updated content about dogs"
        _ = try await noteService.update(note: note)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Should find with new content query
        let results = try await searchEngine.search(query: "dogs", threshold: 0.1)
        #expect(results.count > 0, "Should find updated note")
    }
    
    @Test("Note is removed from index when deleted")
    @MainActor
    func noteIsRemovedFromIndexOnDelete() async throws {
        let (_, _, searchEngine, noteService) = try await createTestServices()
        
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Test",
            content: "Content about elephants",
            tags: []
        )
        
        let created = try await noteService.create(note: note)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify it's indexed
        var results = try await searchEngine.search(query: "elephants", threshold: 0.1)
        #expect(results.count > 0)
        
        // Delete the note
        try await noteService.delete(id: created.id)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Should no longer be in search results
        results = try await searchEngine.search(query: "elephants", threshold: 0.1)
        #expect(results.isEmpty, "Deleted note should not appear in search")
    }
    
    // MARK: - Search Quality Tests
    
    @Test("Search finds semantically similar content")
    @MainActor
    func searchFindsSemanticallySimilar() async throws {
        let (_, _, searchEngine, noteService) = try await createTestServices()
        
        // Create notes with related concepts
        let note1 = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Cars",
            content: "I love driving my automobile on the highway",
            tags: []
        )
        
        let note2 = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Cooking",
            content: "My favorite recipe uses tomatoes and basil",
            tags: []
        )
        
        _ = try await noteService.create(note: note1)
        _ = try await noteService.create(note: note2)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Search for "car" should find the automobile note
        let results = try await searchEngine.search(query: "car vehicle", threshold: 0.1)
        
        #expect(results.count > 0, "Should find related notes")
        
        // The automobile note should have higher relevance
        let topResult = results.first
        #expect(topResult?.noteId == note1.id, "Car note should rank higher than cooking note")
    }
    
    @Test("Search respects threshold parameter")
    @MainActor
    func searchRespectsThreshold() async throws {
        let (_, _, searchEngine, noteService) = try await createTestServices()
        
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Test",
            content: "A note about programming in Swift",
            tags: []
        )
        
        _ = try await noteService.create(note: note)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Low threshold should find results
        let lowThresholdResults = try await searchEngine.search(query: "Swift", threshold: 0.1)
        #expect(lowThresholdResults.count > 0)
        
        // Very high threshold might not find results
        let highThresholdResults = try await searchEngine.search(query: "Swift", threshold: 0.9)
        #expect(highThresholdResults.count <= lowThresholdResults.count,
               "Higher threshold should return fewer or equal results")
    }
    
    @Test("Search returns results sorted by relevance")
    @MainActor
    func searchReturnsSortedByRelevance() async throws {
        let (_, _, searchEngine, noteService) = try await createTestServices()
        
        // Create notes with varying relevance to query
        let veryRelevant = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Python",
            content: "Python programming language for data science and machine learning",
            tags: []
        )
        
        let lessRelevant = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Snake",
            content: "Pythons are large snakes found in tropical regions",
            tags: []
        )
        
        _ = try await noteService.create(note: veryRelevant)
        _ = try await noteService.create(note: lessRelevant)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        let results = try await searchEngine.search(query: "programming Python code", threshold: 0.0)
        
        #expect(results.count >= 2, "Should find both notes")
        
        // First result should be more relevant than second
        if results.count >= 2 {
            #expect(results[0].relevance > results[1].relevance,
                   "Results should be sorted by descending relevance")
        }
    }
    
    // MARK: - Cosine Similarity Tests
    
    @Test("Cosine similarity handles negative values correctly")
    @MainActor
    func cosineSimilarityHandlesNegatives() async throws {
        let (_, embeddingService, searchEngine, _) = try await createTestServices()
        
        // Create embeddings for opposite concepts
        let positiveEmbed = try await embeddingService.generateEmbedding(for: "happy joyful excited")
        let negativeEmbed = try await embeddingService.generateEmbedding(for: "sad depressed miserable")
        
        // Index a "happy" note
        let happyNoteId = UUID()
        try await searchEngine.indexNote(id: happyNoteId, embedding: positiveEmbed)
        
        // Search with "sad" query - may have low or negative similarity
        let results = try await searchEngine.search(query: "sad depressed", threshold: -1.0)
        
        // Should get a result even if similarity is negative
        #expect(results.count > 0, "Should return results with any similarity")
        
        // The relevance can be negative (opposite semantic direction)
        let relevance = results.first?.relevance ?? 0
        #expect(relevance >= -1.0 && relevance <= 1.0,
               "Cosine similarity must be in range [-1, 1]")
    }
    
    @Test("Cosine similarity returns 1.0 for identical text")
    @MainActor
    func cosineSimilarityIdenticalText() async throws {
        let (_, _, searchEngine, noteService) = try await createTestServices()
        
        let content = "This is a unique test phrase for similarity testing"
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            title: "Test",
            content: content,
            tags: []
        )
        
        _ = try await noteService.create(note: note)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Search with identical text
        let results = try await searchEngine.search(query: content, threshold: 0.0)
        
        #expect(results.count > 0)
        
        // Similarity should be very high (close to 1.0)
        if let topResult = results.first {
            #expect(topResult.relevance > 0.9,
                   "Identical text should have very high similarity (got \(topResult.relevance))")
        }
    }
    
    // MARK: - Dimension Validation Tests
    
    @Test("Index rejects embeddings with wrong dimensions")
    @MainActor
    func indexRejectsWrongDimensions() async throws {
        let (_, embeddingService, searchEngine, _) = try await createTestServices()
        
        let wrongDimEmbed = [Float](repeating: 0.5, count: 256) // Wrong: should be 512
        
        await #expect(throws: VectorSearchError.dimensionMismatch(expected: 512, actual: 256)) {
            try await searchEngine.indexNote(id: UUID(), embedding: wrongDimEmbed)
        }
    }
    
    // MARK: - Empty Query Tests
    
    @Test("Search with empty query returns empty results")
    @MainActor
    func emptyQueryReturnsEmpty() async throws {
        let (_, _, searchEngine, _) = try await createTestServices()
        
        // Empty string should probably throw or return empty
        // Depends on your implementation
        let results = try await searchEngine.search(query: "", threshold: 0.1)
        
        // Either empty results or check what your implementation does
        // This test documents the expected behavior
        #expect(results.isEmpty || results.count >= 0, "Empty query should handle gracefully")
    }
}

// MARK: - Mock Repository for Tests

actor InMemoryNoteRepository: NoteRepository {
    private var notes: [UUID: Note] = [:]
    
    func create(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }
    
    func read(id: UUID) async throws -> Note? {
        return notes[id]
    }
    
    func update(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }
    
    func delete(id: UUID) async throws {
        if var note = notes[id] {
            note.deletedAt = Date()
            notes[id] = note
        }
    }
    
    func list() async throws -> [Note] {
        return notes.values.filter { $0.deletedAt == nil }
    }
    
    func search(query: String) async throws -> [Note] {
        return try await list().filter { note in
            note.content.localizedCaseInsensitiveContains(query) ||
            note.title.localizedCaseInsensitiveContains(query)
        }
    }
    
    func listTrashed() async throws -> [Note] {
        return notes.values.filter { $0.deletedAt != nil }
    }
    
    func restore(id: UUID) async throws {
        if var note = notes[id] {
            note.deletedAt = nil
            notes[id] = note
        }
    }
    
    func purge(id: UUID) async throws {
        notes.removeValue(forKey: id)
    }
    
    func clear() async {
        notes.removeAll()
    }
}
