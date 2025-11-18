// ABOUTME: Integration tests for search functionality using real implementations
// ABOUTME: Validates end-to-end search pipeline from note creation to query results

import XCTest
@testable import Commonplace_Book

/// Integration tests for semantic search with real embeddings and indexing
@MainActor
final class SearchIntegrationTests: XCTestCase {

    var repository: InMemoryNoteRepository!
    var embeddingService: EmbeddingService!
    var searchEngine: VectorSearchEngine!
    var searchViewModel: SearchViewModel!
    var noteService: NoteService!

    override func setUpWithError() async throws {
        // Create real implementations (not mocks)
        repository = InMemoryNoteRepository()
        embeddingService = EmbeddingService(embeddingDimension: 384)

        // Load the embedding model
        try await embeddingService.loadModel()

        // Create search engine with real embedding service
        searchEngine = VectorSearchEngine(
            embeddingService: embeddingService,
            expectedDimension: 384
        )

        // Create note service with all dependencies
        noteService = NoteService(
            repository: repository,
            searchEngine: searchEngine,
            embeddingService: embeddingService
        )

        // Create search view model
        searchViewModel = SearchViewModel(
            searchEngine: searchEngine,
            noteService: noteService,
            repository: repository
        )
    }

    override func tearDownWithError() async throws {
        await repository.clear()
        await searchEngine.rebuild()
        repository = nil
        embeddingService = nil
        searchEngine = nil
        searchViewModel = nil
        noteService = nil
    }

    // MARK: - Automatic Indexing Tests

    func testNoteServiceAutomaticallyIndexesNewNotes() async throws {
        // GIVEN note service with automatic indexing
        // WHEN creating a note through the service
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Automatic indexing test for Swift programming",
            title: "Auto Index Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await noteService.create(note: note)

        // Wait a moment for async indexing to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // THEN note should be automatically indexed and searchable
        let results = try await searchEngine.search(query: "Swift programming", threshold: 0.3)

        XCTAssertGreaterThan(results.count, 0,
                           "NoteService should automatically index created notes")
        XCTAssertTrue(results.contains(where: { $0.noteId == note.id }),
                     "Search should find automatically indexed note")
    }

    func testNoteServiceReindexesUpdatedNotes() async throws {
        // GIVEN an existing note created through service
        var note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Original content about cats",
            title: "Cats",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await noteService.create(note: note)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Verify original search works
        let catResults = try await searchEngine.search(query: "cats", threshold: 0.3)
        XCTAssertTrue(catResults.contains(where: { $0.noteId == note.id }),
                     "Should find note with original content")

        // WHEN updating through service
        note.content = "Updated content about dogs"
        note.modified = Date()
        _ = try await noteService.update(note: note)

        // Wait for re-indexing
        try await Task.sleep(nanoseconds: 200_000_000)

        // THEN should automatically re-index with new content
        let dogResults = try await searchEngine.search(query: "dogs", threshold: 0.3)
        XCTAssertTrue(dogResults.contains(where: { $0.noteId == note.id }),
                     "NoteService should automatically re-index updated notes")
    }

    func testNoteServiceRemovesDeletedNotesFromIndex() async throws {
        // GIVEN indexed note created through service
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Content to be deleted",
            title: "To Delete",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await noteService.create(note: note)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Verify it's searchable
        let beforeResults = try await searchEngine.search(query: "deleted", threshold: 0.3)
        XCTAssertTrue(beforeResults.contains(where: { $0.noteId == note.id }),
                     "Should find note before deletion")

        // WHEN deleting through service
        try await noteService.delete(id: note.id)

        // THEN should automatically remove from index
        let afterResults = try await searchEngine.search(query: "deleted", threshold: 0.3)
        XCTAssertFalse(afterResults.contains(where: { $0.noteId == note.id }),
                      "NoteService should automatically remove deleted notes from index")
    }

    // MARK: - Basic Search Flow Tests

    func testSearchFindsNoteByContent() async throws {
        // GIVEN a note with specific content
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Swift programming language tutorial",
            title: "Swift Tutorial",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note)

        // Index the note manually (exposing that this doesn't happen automatically)
        let embedding = try await embeddingService.generateEmbedding(for: note.content)
        try await searchEngine.indexNote(id: note.id, embedding: embedding)

        // WHEN searching for related content
        let results = try await searchEngine.search(query: "Swift programming", threshold: 0.3)

        // THEN should find the note
        XCTAssertGreaterThan(results.count, 0, "Search should return results for matching content")
        XCTAssertTrue(results.contains(where: { $0.noteId == note.id }),
                     "Search results should include the created note")

        // Verify relevance score is reasonable
        if let result = results.first(where: { $0.noteId == note.id }) {
            XCTAssertGreaterThan(result.relevance, 0.3,
                               "Relevance score should be above threshold")
        }
    }

    func testSearchDistinguishesBetweenDifferentTopics() async throws {
        // GIVEN notes about different topics
        let swiftNote = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Swift is a programming language developed by Apple for iOS development",
            title: "Swift Programming",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let pythonNote = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Python is a versatile programming language popular for data science and web development",
            title: "Python Programming",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let cookingNote = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Recipe for chocolate chip cookies with butter and vanilla extract",
            title: "Cookie Recipe",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: swiftNote)
        _ = try await repository.create(note: pythonNote)
        _ = try await repository.create(note: cookingNote)

        // Index all notes
        for note in [swiftNote, pythonNote, cookingNote] {
            let embedding = try await embeddingService.generateEmbedding(for: note.content)
            try await searchEngine.indexNote(id: note.id, embedding: embedding)
        }

        // WHEN searching for iOS development
        let iOSResults = try await searchEngine.search(query: "iOS development Apple", threshold: 0.2)

        // THEN should rank Swift note highest
        XCTAssertGreaterThan(iOSResults.count, 0, "Should find results for iOS development")

        let swiftRelevance = iOSResults.first(where: { $0.noteId == swiftNote.id })?.relevance ?? 0.0
        let pythonRelevance = iOSResults.first(where: { $0.noteId == pythonNote.id })?.relevance ?? 0.0
        let cookingRelevance = iOSResults.first(where: { $0.noteId == cookingNote.id })?.relevance ?? 0.0

        XCTAssertGreaterThan(swiftRelevance, pythonRelevance,
                           "Swift note should be more relevant for iOS query than Python note")
        XCTAssertGreaterThan(swiftRelevance, cookingRelevance,
                           "Swift note should be more relevant for iOS query than cooking note")
    }

    func testSearchWithThresholdFiltering() async throws {
        // GIVEN a note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Machine learning algorithms for natural language processing",
            title: "ML and NLP",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note)
        let embedding = try await embeddingService.generateEmbedding(for: note.content)
        try await searchEngine.indexNote(id: note.id, embedding: embedding)

        // WHEN searching with low threshold
        let lowThresholdResults = try await searchEngine.search(
            query: "machine learning",
            threshold: 0.2
        )

        // AND searching with high threshold
        let highThresholdResults = try await searchEngine.search(
            query: "completely unrelated cooking recipes",
            threshold: 0.8
        )

        // THEN low threshold should find the note
        XCTAssertGreaterThan(lowThresholdResults.count, 0,
                           "Low threshold should find related content")

        // AND high threshold with unrelated query should not
        XCTAssertEqual(highThresholdResults.count, 0,
                      "High threshold should filter out unrelated content")
    }

    // MARK: - Multi-Note Search Tests

    func testSearchRanksResultsByRelevance() async throws {
        // GIVEN multiple notes with varying relevance
        let exactMatch = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Quantum computing uses qubits for quantum computation",
            title: "Quantum Computing",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let relatedMatch = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Computer science covers algorithms and data structures",
            title: "Computer Science",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let distantMatch = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Classical physics explains motion and forces",
            title: "Classical Physics",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        for note in [exactMatch, relatedMatch, distantMatch] {
            _ = try await repository.create(note: note)
            let embedding = try await embeddingService.generateEmbedding(for: note.content)
            try await searchEngine.indexNote(id: note.id, embedding: embedding)
        }

        // WHEN searching for quantum computing
        let results = try await searchEngine.search(query: "quantum computing", threshold: 0.1)

        // THEN results should be sorted by relevance
        XCTAssertGreaterThanOrEqual(results.count, 2, "Should find multiple related notes")

        // Verify descending order
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(results[i].relevance, results[i + 1].relevance,
                                       "Results should be sorted by descending relevance")
        }

        // Verify exact match is most relevant
        if let topResult = results.first {
            XCTAssertEqual(topResult.noteId, exactMatch.id,
                          "Most relevant result should be the exact match")
        }
    }

    func testSearchWithMultipleNotes() async throws {
        // GIVEN a collection of diverse notes
        let noteContents = [
            ("Swift", "Swift is Apple's programming language for iOS"),
            ("Python", "Python is great for data analysis and machine learning"),
            ("JavaScript", "JavaScript powers modern web applications"),
            ("Rust", "Rust provides memory safety without garbage collection"),
            ("Go", "Go is designed for concurrent programming and cloud services")
        ]

        var createdNotes: [Note] = []
        for (title, content) in noteContents {
            let note = Note(
                id: UUID(),
                created: Date(),
                device: "test-device",
                location: nil,
                content: content,
                title: title,
                backlinks: [],
                unknownFrontmatterFields: [:]
            )
            _ = try await repository.create(note: note)

            let embedding = try await embeddingService.generateEmbedding(for: note.content)
            try await searchEngine.indexNote(id: note.id, embedding: embedding)

            createdNotes.append(note)
        }

        // WHEN searching for "programming language"
        let results = try await searchEngine.search(query: "programming language", threshold: 0.2)

        // THEN should find programming-related notes
        XCTAssertGreaterThan(results.count, 0, "Should find programming-related notes")

        // Verify we can retrieve actual note details
        let notes = await searchViewModel.loadNoteDetails(for: results)
        XCTAssertGreaterThan(notes.count, 0, "Should load note details from search results")

        // All returned notes should be from our created set
        for note in notes {
            XCTAssertTrue(createdNotes.contains(where: { $0.id == note.id }),
                         "Returned note should be from our created set")
        }
    }

    // MARK: - Search View Model Integration Tests

    func testSearchViewModelEndToEnd() async throws {
        // GIVEN notes in repository
        let swiftNote = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Swift programming language tutorial for beginners",
            title: "Swift Tutorial",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: swiftNote)

        // Index the note
        let embedding = try await embeddingService.generateEmbedding(for: swiftNote.content)
        try await searchEngine.indexNote(id: swiftNote.id, embedding: embedding)

        // WHEN using search view model
        searchViewModel.query = "Swift programming"

        // Wait for debounce and search execution
        try await Task.sleep(nanoseconds: 700_000_000) // 700ms (500ms debounce + buffer)

        // THEN should have results
        XCTAssertGreaterThan(searchViewModel.results.count, 0,
                           "Search view model should return results")
        XCTAssertTrue(searchViewModel.results.contains(where: { $0.noteId == swiftNote.id }),
                     "Results should include the Swift note")
    }

    func testSearchViewModelClearsResultsOnEmptyQuery() async throws {
        // GIVEN search with results
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Test content for clearing",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note)
        let embedding = try await embeddingService.generateEmbedding(for: note.content)
        try await searchEngine.indexNote(id: note.id, embedding: embedding)

        searchViewModel.query = "test"
        try await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertGreaterThan(searchViewModel.results.count, 0, "Should have results initially")

        // WHEN clearing query
        searchViewModel.query = ""

        // Wait for update
        try await Task.sleep(nanoseconds: 100_000_000)

        // THEN results should be cleared
        XCTAssertEqual(searchViewModel.results.count, 0,
                      "Results should be cleared when query is empty")
    }

    // MARK: - Edge Cases

    func testSearchWithNoIndexedNotes() async throws {
        // GIVEN empty search index (notes exist but not indexed)
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "This note is not indexed",
            title: "Unindexed",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note)
        // NOTE: Not indexing the note - this simulates the current problem

        // WHEN searching
        let results = try await searchEngine.search(query: "indexed", threshold: 0.5)

        // THEN should return empty results
        XCTAssertEqual(results.count, 0,
                      "Search should return no results when notes are not indexed")
    }

    func testSearchWithEmptyQuery() async throws {
        // GIVEN indexed note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Test content",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note)
        let embedding = try await embeddingService.generateEmbedding(for: note.content)
        try await searchEngine.indexNote(id: note.id, embedding: embedding)

        // WHEN searching with empty query
        let results = try await searchEngine.search(query: "", threshold: 0.5)

        // THEN should handle gracefully (empty string has an embedding)
        // This is implementation-specific - empty string will get an embedding
        XCTAssertGreaterThanOrEqual(results.count, 0,
                                   "Should handle empty query without crashing")
    }

    func testSearchAfterNoteUpdate() async throws {
        // GIVEN an indexed note
        var note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Original content about cats",
            title: "Cats",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note)
        let originalEmbedding = try await embeddingService.generateEmbedding(for: note.content)
        try await searchEngine.indexNote(id: note.id, embedding: originalEmbedding)

        // Verify original search works
        let originalResults = try await searchEngine.search(query: "cats", threshold: 0.3)
        XCTAssertTrue(originalResults.contains(where: { $0.noteId == note.id }),
                     "Should find note with original content")

        // WHEN updating note content
        note.content = "Updated content about dogs"
        note.modified = Date()
        _ = try await repository.update(note: note)

        // Re-index with new content (exposing that this doesn't happen automatically)
        let updatedEmbedding = try await embeddingService.generateEmbedding(for: note.content)
        try await searchEngine.indexNote(id: note.id, embedding: updatedEmbedding)

        // THEN search should reflect updated content
        let dogResults = try await searchEngine.search(query: "dogs", threshold: 0.3)
        XCTAssertTrue(dogResults.contains(where: { $0.noteId == note.id }),
                     "Should find note with updated content about dogs")

        let catResults = try await searchEngine.search(query: "cats", threshold: 0.3)
        let catRelevance = catResults.first(where: { $0.noteId == note.id })?.relevance ?? 0.0
        let dogRelevance = dogResults.first(where: { $0.noteId == note.id })?.relevance ?? 0.0

        XCTAssertGreaterThan(dogRelevance, catRelevance,
                           "Updated note should be more relevant for new content than old")
    }

    func testSearchAfterNoteDeleted() async throws {
        // GIVEN indexed note
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test-device",
            location: nil,
            content: "Content to be deleted",
            title: "To Delete",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note)
        let embedding = try await embeddingService.generateEmbedding(for: note.content)
        try await searchEngine.indexNote(id: note.id, embedding: embedding)

        // Verify it's searchable
        let beforeResults = try await searchEngine.search(query: "deleted", threshold: 0.3)
        XCTAssertTrue(beforeResults.contains(where: { $0.noteId == note.id }),
                     "Should find note before deletion")

        // WHEN deleting note
        try await repository.delete(id: note.id)

        // Remove from search index (exposing that this doesn't happen automatically)
        await searchEngine.removeNote(id: note.id)

        // THEN should not appear in search
        let afterResults = try await searchEngine.search(query: "deleted", threshold: 0.3)
        XCTAssertFalse(afterResults.contains(where: { $0.noteId == note.id }),
                      "Should not find deleted note in search results")
    }

    // MARK: - Performance Tests

    func testSearchPerformanceWithManyNotes() async throws {
        // GIVEN many indexed notes
        let noteCount = 100
        var noteIds: [UUID] = []

        for i in 0..<noteCount {
            let note = Note(
                id: UUID(),
                created: Date(),
                device: "test-device",
                location: nil,
                content: "This is test note number \(i) with unique content about topic \(i % 10)",
                title: "Note \(i)",
                backlinks: [],
                unknownFrontmatterFields: [:]
            )

            _ = try await repository.create(note: note)
            noteIds.append(note.id)

            let embedding = try await embeddingService.generateEmbedding(for: note.content)
            try await searchEngine.indexNote(id: note.id, embedding: embedding)
        }

        // WHEN performing search
        let startTime = Date()
        let results = try await searchEngine.search(query: "test note topic", threshold: 0.2)
        let duration = Date().timeIntervalSince(startTime)

        // THEN should complete quickly
        XCTAssertLessThan(duration, 1.0, "Search should complete in under 1 second even with 100 notes")
        XCTAssertGreaterThan(results.count, 0, "Should find relevant notes")

        // Verify results are sorted
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(results[i].relevance, results[i + 1].relevance,
                                       "Results should maintain sorted order")
        }
    }
}
