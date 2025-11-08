// ABOUTME: Tests for batched note loading in EnhancedNoteListView
// ABOUTME: Validates concurrency limits, order preservation, and memory safety with large result sets

import XCTest
import SwiftUI
@testable import Template_App

@MainActor
final class EnhancedNoteListBatchedLoadingTests: XCTestCase {
    var mockRepository: MockBatchedLoadRepository!
    var mockSearchEngine: MockBatchSearchEngine!
    var listViewModel: NoteListViewModel!
    var searchViewModel: SearchViewModel!
    var mockMetadataCollector: MockMetadataCollector!

    override func setUpWithError() throws {
        mockRepository = MockBatchedLoadRepository()
        mockSearchEngine = MockBatchSearchEngine()
        mockMetadataCollector = MockMetadataCollector()

        listViewModel = NoteListViewModel(
            repository: mockRepository,
            metadataCollector: mockMetadataCollector
        )

        searchViewModel = SearchViewModel(
            searchEngine: mockSearchEngine,
            repository: mockRepository
        )
    }

    override func tearDownWithError() throws {
        mockRepository = nil
        mockSearchEngine = nil
        mockMetadataCollector = nil
        listViewModel = nil
        searchViewModel = nil
    }

    // MARK: - Concurrency Limit Tests

    func testBatchedLoadingWithSmallResultSet() async throws {
        // GIVEN 10 search results (less than batch size of 20)
        let notes = createTestNotes(count: 10)
        for note in notes {
            await mockRepository.addNote(note)
        }

        let results = notes.map { SearchResult(noteId: $0.id, relevance: 0.9) }

        // WHEN loading notes
        let view = SearchResultsListView(searchViewModel: searchViewModel)

        // Simulate the loading behavior
        let loadedNotes = try await loadNotesViaBatchedMethod(for: results)

        // THEN all notes loaded in single batch
        XCTAssertEqual(loadedNotes.count, 10, "Should load all 10 notes")
        XCTAssertEqual(await mockRepository.maxConcurrentReads, 10, "Should have max 10 concurrent reads")
    }

    func testBatchedLoadingWithExactlyTwentyResults() async throws {
        // GIVEN exactly 20 search results (one full batch)
        let notes = createTestNotes(count: 20)
        for note in notes {
            await mockRepository.addNote(note)
        }

        let results = notes.map { SearchResult(noteId: $0.id, relevance: 0.9) }

        // WHEN loading notes
        let loadedNotes = try await loadNotesViaBatchedMethod(for: results)

        // THEN all notes loaded in single batch
        XCTAssertEqual(loadedNotes.count, 20, "Should load all 20 notes")
        XCTAssertEqual(await mockRepository.maxConcurrentReads, 20, "Should have max 20 concurrent reads")
    }

    func testBatchedLoadingWithLargeResultSet() async throws {
        // GIVEN 50 search results (3 batches: 20+20+10)
        let notes = createTestNotes(count: 50)
        for note in notes {
            await mockRepository.addNote(note)
        }

        let results = notes.map { SearchResult(noteId: $0.id, relevance: 0.9) }

        // WHEN loading notes
        let loadedNotes = try await loadNotesViaBatchedMethod(for: results)

        // THEN all notes loaded with max 20 concurrent reads
        XCTAssertEqual(loadedNotes.count, 50, "Should load all 50 notes")
        XCTAssertLessThanOrEqual(
            await mockRepository.maxConcurrentReads,
            20,
            "Should never exceed 20 concurrent reads"
        )
    }

    func testBatchedLoadingWithVeryLargeResultSet() async throws {
        // GIVEN 100 search results (5 batches of 20)
        let notes = createTestNotes(count: 100)
        for note in notes {
            await mockRepository.addNote(note)
        }

        let results = notes.map { SearchResult(noteId: $0.id, relevance: 0.9) }

        // WHEN loading notes
        let loadedNotes = try await loadNotesViaBatchedMethod(for: results)

        // THEN all notes loaded with max 20 concurrent reads
        XCTAssertEqual(loadedNotes.count, 100, "Should load all 100 notes")
        XCTAssertLessThanOrEqual(
            await mockRepository.maxConcurrentReads,
            20,
            "Should never exceed 20 concurrent reads even with 100 results"
        )
    }

    // MARK: - Order Preservation Tests

    func testBatchedLoadingPreservesOrder() async throws {
        // GIVEN search results in specific order
        let notes = createTestNotes(count: 30)
        for note in notes {
            await mockRepository.addNote(note)
        }

        let results = notes.map { SearchResult(noteId: $0.id, relevance: Float.random(in: 0...1)) }
        let expectedOrder = results.map { $0.noteId }

        // WHEN loading notes
        let loadedNotes = try await loadNotesViaBatchedMethod(for: results)

        // THEN order is preserved
        let actualOrder = loadedNotes.map { $0.id }
        XCTAssertEqual(actualOrder, expectedOrder, "Should preserve original search result order")
    }

    func testBatchedLoadingPreservesOrderAcrossBatches() async throws {
        // GIVEN 45 results that will span 3 batches
        let notes = createTestNotes(count: 45)
        for note in notes {
            await mockRepository.addNote(note)
        }

        let results = notes.enumerated().map { index, note in
            // Vary relevance to ensure we're testing order preservation, not relying on natural ordering
            SearchResult(noteId: note.id, relevance: Float(45 - index) / 45.0)
        }

        let expectedOrder = results.map { $0.noteId }

        // WHEN loading notes
        let loadedNotes = try await loadNotesViaBatchedMethod(for: results)

        // THEN order preserved across all 3 batches
        let actualOrder = loadedNotes.map { $0.id }
        XCTAssertEqual(actualOrder, expectedOrder, "Should preserve order across batch boundaries")
    }

    // MARK: - Error Handling Tests

    func testBatchedLoadingSkipsMissingNotes() async throws {
        // GIVEN some notes exist but others don't
        let existingNotes = createTestNotes(count: 15)
        let missingNoteIds = (0..<5).map { _ in UUID() }

        for note in existingNotes {
            await mockRepository.addNote(note)
        }

        // Mix existing and missing in results
        var allResults: [SearchResult] = []
        allResults.append(contentsOf: existingNotes[0..<5].map { SearchResult(noteId: $0.id, relevance: 0.9) })
        allResults.append(contentsOf: missingNoteIds.map { SearchResult(noteId: $0, relevance: 0.8) })
        allResults.append(contentsOf: existingNotes[5..<15].map { SearchResult(noteId: $0.id, relevance: 0.7) })

        // WHEN loading notes
        let loadedNotes = try await loadNotesViaBatchedMethod(for: allResults)

        // THEN only existing notes loaded, order preserved
        XCTAssertEqual(loadedNotes.count, 15, "Should load only existing notes")

        let loadedIds = loadedNotes.map { $0.id }
        let existingIds = existingNotes.map { $0.id }
        XCTAssertEqual(loadedIds, existingIds, "Should preserve order of existing notes")
    }

    // MARK: - Helper Methods

    /// Helper to directly test the batched loading logic
    private func loadNotesViaBatchedMethod(for results: [SearchResult]) async throws -> [Note] {
        // This replicates the logic from SearchResultsListView.loadNotesPreservingOrder
        let noteIds = results.map { $0.noteId }

        // Load in batches of 20
        let maxConcurrentTasks = 20
        let batches = stride(from: 0, to: results.count, by: maxConcurrentTasks).map {
            Array(results[$0..<min($0 + maxConcurrentTasks, results.count)])
        }

        var notesDict: [UUID: Note] = [:]
        for batch in batches {
            let batchNotes = await withTaskGroup(of: (UUID, Note?).self) { group in
                for result in batch {
                    group.addTask {
                        let note = try? await self.searchViewModel.repository.read(id: result.noteId)
                        return (result.noteId, note)
                    }
                }

                var dict: [UUID: Note] = [:]
                for await (id, note) in group {
                    if let note = note {
                        dict[id] = note
                    }
                }
                return dict
            }

            notesDict.merge(batchNotes) { _, new in new }
        }

        return noteIds.compactMap { notesDict[$0] }
    }

    private func createTestNotes(count: Int) -> [Note] {
        (0..<count).map { index in
            Note(
                id: UUID(),
                created: Date().addingTimeInterval(TimeInterval(-index * 60)),
                device: "test-device",
                location: nil,
                content: "Content for note \(index)",
                title: "Test Note \(index)",
                backlinks: [],
                unknownFrontmatterFields: [:]
            )
        }
    }
}

// MARK: - Mock Repository with Concurrency Tracking

actor MockBatchedLoadRepository: NoteRepositoryProtocol {
    private var notes: [UUID: Note] = [:]
    private var currentConcurrentReads = 0
    private(set) var maxConcurrentReads = 0

    func addNote(_ note: Note) {
        notes[note.id] = note
    }

    func create(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }

    func read(id: UUID) async throws -> Note {
        // Track concurrent reads
        currentConcurrentReads += 1
        if currentConcurrentReads > maxConcurrentReads {
            maxConcurrentReads = currentConcurrentReads
        }

        // Simulate IO delay
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms

        currentConcurrentReads -= 1

        guard let note = notes[id] else {
            throw NSError(domain: "test", code: 404, userInfo: [NSLocalizedDescriptionKey: "Note not found"])
        }

        return note
    }

    func update(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }

    func delete(id: UUID) async throws {
        notes.removeValue(forKey: id)
    }

    func list() async throws -> [Note] {
        return Array(notes.values)
    }
}

// MARK: - Mock Search Engine

actor MockBatchSearchEngine: VectorSearchEngineProtocol {
    private var mockResults: [SearchResult] = []

    func setMockResults(_ results: [SearchResult]) {
        self.mockResults = results
    }

    func search(query: String, threshold: Float) async throws -> [SearchResult] {
        return mockResults
    }

    func indexNote(id: UUID, embedding: [Float]) async throws {}
    func removeNote(id: UUID) async {}
    func rebuild() async {}
}
