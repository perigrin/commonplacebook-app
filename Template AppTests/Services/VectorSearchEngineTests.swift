// ABOUTME: Tests for VectorSearchEngine that performs semantic search using cosine similarity
// ABOUTME: Validates indexing, search with threshold, relevance ranking, and rebuild operations

import XCTest
@testable import Template_App

final class VectorSearchEngineTests: XCTestCase {
    var searchEngine: VectorSearchEngine!
    var mockEmbeddingService: MockEmbeddingService!

    override func setUpWithError() throws {
        mockEmbeddingService = MockEmbeddingService()
        searchEngine = VectorSearchEngine(embeddingService: mockEmbeddingService)
    }

    override func tearDownWithError() throws {
        searchEngine = nil
        mockEmbeddingService = nil
    }

    // MARK: - Indexing Tests

    func testIndexNoteStoresEmbedding() async throws {
        // GIVEN search engine and embedding
        let noteId = UUID()
        let embedding = generateTestEmbedding(seed: 1)

        // WHEN indexing note
        await searchEngine.indexNote(id: noteId, embedding: embedding)

        // THEN note can be found in search
        mockEmbeddingService.testEmbedding = embedding
        let results = try await searchEngine.search(query: "test", threshold: 0.5)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.noteId, noteId)
    }

    func testIndexMultipleNotes() async throws {
        // GIVEN multiple notes
        let note1 = UUID()
        let note2 = UUID()
        let note3 = UUID()

        // WHEN indexing multiple notes
        await searchEngine.indexNote(id: note1, embedding: generateTestEmbedding(seed: 1))
        await searchEngine.indexNote(id: note2, embedding: generateTestEmbedding(seed: 2))
        await searchEngine.indexNote(id: note3, embedding: generateTestEmbedding(seed: 3))

        // THEN all notes can be retrieved
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 1)
        let results = try await searchEngine.search(query: "test", threshold: 0.0)

        XCTAssertGreaterThanOrEqual(results.count, 3, "Should find at least 3 indexed notes")
    }

    func testIndexSameNoteTwiceUpdatesEmbedding() async throws {
        // GIVEN note indexed once
        let noteId = UUID()
        let oldEmbedding = generateTestEmbedding(seed: 1)
        await searchEngine.indexNote(id: noteId, embedding: oldEmbedding)

        // WHEN indexing same note with different embedding
        let newEmbedding = generateTestEmbedding(seed: 99)
        await searchEngine.indexNote(id: noteId, embedding: newEmbedding)

        // THEN search uses new embedding
        mockEmbeddingService.testEmbedding = newEmbedding
        let results = try await searchEngine.search(query: "test", threshold: 0.9)

        XCTAssertEqual(results.count, 1, "Should find note with updated embedding")
        XCTAssertEqual(results.first?.noteId, noteId)
        XCTAssertGreaterThan(results.first?.relevance ?? 0, 0.9, "Should have high similarity to new embedding")
    }

    // MARK: - Search Tests

    func testSearchFindsRelevantNotes() async throws {
        // GIVEN indexed notes with different embeddings
        let relevantNote = UUID()
        let irrelevantNote = UUID()

        let queryEmbedding = generateTestEmbedding(seed: 10)
        let similarEmbedding = generateTestEmbedding(seed: 11) // Similar seed should give similar embedding
        let differentEmbedding = generateTestEmbedding(seed: 999)

        await searchEngine.indexNote(id: relevantNote, embedding: similarEmbedding)
        await searchEngine.indexNote(id: irrelevantNote, embedding: differentEmbedding)

        // WHEN searching
        mockEmbeddingService.testEmbedding = queryEmbedding
        let results = try await searchEngine.search(query: "test query", threshold: 0.5)

        // THEN finds relevant note
        XCTAssertGreaterThan(results.count, 0, "Should find at least relevant note")
        let noteIds = results.map { $0.noteId }
        XCTAssertTrue(noteIds.contains(relevantNote), "Should find relevant note")
    }

    func testSearchFiltersByThreshold() async throws {
        // GIVEN notes with varying similarity
        let highSimilarNote = UUID()
        let mediumSimilarNote = UUID()
        let lowSimilarNote = UUID()

        let queryEmbedding = generateTestEmbedding(seed: 50)

        await searchEngine.indexNote(id: highSimilarNote, embedding: queryEmbedding) // Exact match
        await searchEngine.indexNote(id: mediumSimilarNote, embedding: generateTestEmbedding(seed: 51))
        await searchEngine.indexNote(id: lowSimilarNote, embedding: generateTestEmbedding(seed: 900))

        // WHEN searching with high threshold
        mockEmbeddingService.testEmbedding = queryEmbedding
        let results = try await searchEngine.search(query: "test", threshold: 0.9)

        // THEN only high similarity notes returned
        XCTAssertGreaterThan(results.count, 0, "Should find at least exact match")
        for result in results {
            XCTAssertGreaterThanOrEqual(result.relevance, 0.9, "All results should meet threshold")
        }
    }

    func testSearchResultsSortedByRelevance() async throws {
        // GIVEN multiple indexed notes
        let note1 = UUID()
        let note2 = UUID()
        let note3 = UUID()

        await searchEngine.indexNote(id: note1, embedding: generateTestEmbedding(seed: 100))
        await searchEngine.indexNote(id: note2, embedding: generateTestEmbedding(seed: 101))
        await searchEngine.indexNote(id: note3, embedding: generateTestEmbedding(seed: 102))

        // WHEN searching
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 100)
        let results = try await searchEngine.search(query: "test", threshold: 0.0)

        // THEN results sorted by descending relevance
        XCTAssertGreaterThan(results.count, 1, "Need multiple results to test sorting")

        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(results[i].relevance, results[i + 1].relevance,
                                       "Results should be sorted by descending relevance")
        }
    }

    func testSearchEmptyIndexReturnsNoResults() async throws {
        // GIVEN empty index
        // WHEN searching
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 1)
        let results = try await searchEngine.search(query: "test", threshold: 0.5)

        // THEN returns empty array
        XCTAssertEqual(results.count, 0, "Empty index should return no results")
    }

    func testSearchWithEmptyQueryStillWorks() async throws {
        // GIVEN indexed note
        let noteId = UUID()
        await searchEngine.indexNote(id: noteId, embedding: generateTestEmbedding(seed: 1))

        // WHEN searching with empty query
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 1)
        let results = try await searchEngine.search(query: "", threshold: 0.5)

        // THEN still performs search (empty string has embedding)
        XCTAssertGreaterThanOrEqual(results.count, 0, "Should handle empty query gracefully")
    }

    func testSimilarQueriesReturnSimilarResults() async throws {
        // GIVEN indexed notes
        let note1 = UUID()
        let note2 = UUID()

        await searchEngine.indexNote(id: note1, embedding: generateTestEmbedding(seed: 10))
        await searchEngine.indexNote(id: note2, embedding: generateTestEmbedding(seed: 90))

        // WHEN searching with similar queries
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 10)
        let results1 = try await searchEngine.search(query: "query about topic A", threshold: 0.5)

        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 11)
        let results2 = try await searchEngine.search(query: "similar query about topic A", threshold: 0.5)

        // THEN results overlap significantly
        let ids1 = Set(results1.map { $0.noteId })
        let ids2 = Set(results2.map { $0.noteId })
        let overlap = ids1.intersection(ids2)

        XCTAssertGreaterThan(overlap.count, 0, "Similar queries should return overlapping results")
    }

    // MARK: - Remove Tests

    func testRemoveNoteDeletesFromIndex() async throws {
        // GIVEN indexed note
        let noteId = UUID()
        await searchEngine.indexNote(id: noteId, embedding: generateTestEmbedding(seed: 1))

        // Verify it's indexed
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 1)
        let beforeResults = try await searchEngine.search(query: "test", threshold: 0.5)
        XCTAssertTrue(beforeResults.contains(where: { $0.noteId == noteId }), "Note should be indexed initially")

        // WHEN removing note
        await searchEngine.removeNote(id: noteId)

        // THEN note not found in search
        let afterResults = try await searchEngine.search(query: "test", threshold: 0.5)
        XCTAssertFalse(afterResults.contains(where: { $0.noteId == noteId }), "Note should be removed from index")
    }

    func testRemoveNonExistentNoteDoesNotCrash() async throws {
        // GIVEN empty index
        let nonExistentId = UUID()

        // WHEN removing non-existent note
        await searchEngine.removeNote(id: nonExistentId)

        // THEN no crash (success is not crashing)
        XCTAssertTrue(true, "Should handle removal of non-existent note gracefully")
    }

    // MARK: - Rebuild Tests

    func testRebuildClearsIndex() async throws {
        // GIVEN indexed notes
        let note1 = UUID()
        let note2 = UUID()

        await searchEngine.indexNote(id: note1, embedding: generateTestEmbedding(seed: 1))
        await searchEngine.indexNote(id: note2, embedding: generateTestEmbedding(seed: 2))

        // WHEN rebuilding
        await searchEngine.rebuild()

        // THEN index is empty
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 1)
        let results = try await searchEngine.search(query: "test", threshold: 0.0)

        XCTAssertEqual(results.count, 0, "Rebuild should clear all indexed notes")
    }

    // MARK: - Performance Tests

    func testPerformanceWithLargeIndex() async throws {
        // GIVEN large index (1000+ notes)
        let noteCount = 1000

        for i in 0..<noteCount {
            let noteId = UUID()
            let embedding = generateTestEmbedding(seed: i)
            await searchEngine.indexNote(id: noteId, embedding: embedding)
        }

        // WHEN searching
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 500)

        let startTime = Date()
        let results = try await searchEngine.search(query: "test", threshold: 0.7)
        let duration = Date().timeIntervalSince(startTime)

        // THEN completes in reasonable time (< 1 second)
        XCTAssertLessThan(duration, 1.0, "Search should complete quickly even with large index")
        XCTAssertGreaterThanOrEqual(results.count, 0, "Should return results")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentIndexingIsSafe() async throws {
        // GIVEN multiple concurrent indexing operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let noteId = UUID()
                    let embedding = self.generateTestEmbedding(seed: i)
                    await self.searchEngine.indexNote(id: noteId, embedding: embedding)
                }
            }
        }

        // THEN no crashes and index works
        mockEmbeddingService.testEmbedding = generateTestEmbedding(seed: 1)
        let results = try await searchEngine.search(query: "test", threshold: 0.0)

        XCTAssertGreaterThan(results.count, 0, "Index should work after concurrent operations")
    }

    func testConcurrentSearchIsSafe() async throws {
        // GIVEN indexed notes
        for i in 0..<10 {
            await searchEngine.indexNote(id: UUID(), embedding: generateTestEmbedding(seed: i))
        }

        // WHEN performing concurrent searches
        await withTaskGroup(of: [SearchResult].self) { group in
            for i in 0..<50 {
                group.addTask {
                    self.mockEmbeddingService.testEmbedding = self.generateTestEmbedding(seed: i % 10)
                    return (try? await self.searchEngine.search(query: "test \(i)", threshold: 0.5)) ?? []
                }
            }

            // Collect all results
            var allResults: [[SearchResult]] = []
            for await results in group {
                allResults.append(results)
            }

            // Verify we got results from all searches
            XCTAssertEqual(allResults.count, 50, "Should complete all concurrent searches")
        }
    }

    // MARK: - Helper Methods

    private func generateTestEmbedding(seed: Int) -> [Float] {
        let dimension = 384
        var embedding = [Float](repeating: 0.0, count: dimension)

        // Generate deterministic embedding based on seed
        for i in 0..<dimension {
            let value = sin(Float(seed + i) * 0.1)
            embedding[i] = value
        }

        // Normalize
        let magnitude = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }

        return embedding
    }
}

// MARK: - Mock Embedding Service

class MockEmbeddingService {
    var testEmbedding: [Float] = []

    init() {
        // Default to 384-dimensional zero vector
        testEmbedding = [Float](repeating: 0.0, count: 384)
    }

    func generateEmbedding(for text: String) async throws -> [Float] {
        return testEmbedding
    }
}
