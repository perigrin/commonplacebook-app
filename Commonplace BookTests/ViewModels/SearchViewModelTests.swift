// ABOUTME: Tests for SearchViewModel that handles search query input and result management
// ABOUTME: Validates debouncing, search execution, result loading, and state management

import XCTest
import Combine
@testable import Commonplace_Book

@MainActor
final class SearchViewModelTests: XCTestCase {
    var viewModel: SearchViewModel!
    var mockSearchEngine: MockSearchVectorSearchEngine!
    var mockRepository: MockSearchNoteRepository!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        mockSearchEngine = MockSearchVectorSearchEngine()
        mockRepository = MockSearchNoteRepository()
        viewModel = SearchViewModel(
            searchEngine: mockSearchEngine,
            repository: mockRepository
        )
        cancellables = []
    }

    override func tearDownWithError() throws {
        cancellables = nil
        viewModel = nil
        mockSearchEngine = nil
        mockRepository = nil
    }

    // MARK: - Query Change Tests

    func testQueryChangeTriggersSearch() async throws {
        // GIVEN view model
        let expectation = XCTestExpectation(description: "Search triggered")

        // Set up mock to return results
        let noteId = UUID()
        await mockSearchEngine.setMockResults([SearchResult(noteId: noteId, relevance: 0.9)])

        // WHEN changing query
        viewModel.query = "test query"

        // Wait for debounce
        try await Task.sleep(nanoseconds: 600_000_000) // 600ms > 500ms debounce

        // THEN search executed
        let searchCount = await mockSearchEngine.searchCallCount
        XCTAssertGreaterThan(searchCount, 0, "Search should be triggered")
        XCTAssertEqual(viewModel.results.count, 1, "Results should be populated")
    }

    func testDebouncingPreventsExcessiveSearches() async throws {
        // GIVEN view model
        // WHEN rapidly changing query
        viewModel.query = "a"
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        viewModel.query = "ab"
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        viewModel.query = "abc"
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        viewModel.query = "abcd"

        // Wait for debounce
        try await Task.sleep(nanoseconds: 600_000_000) // 600ms

        // THEN only one search executed (after debounce)
        let searchCount = await mockSearchEngine.searchCallCount
        XCTAssertLessThanOrEqual(searchCount, 2, "Should not search for every character change")
    }

    func testEmptyQueryClearsResults() async throws {
        // GIVEN view model with results
        let noteId = UUID()
        await mockSearchEngine.setMockResults([SearchResult(noteId: noteId, relevance: 0.9)])

        viewModel.query = "test"
        try await Task.sleep(nanoseconds: 600_000_000) // Wait for search

        XCTAssertGreaterThan(viewModel.results.count, 0, "Should have results")

        // WHEN clearing query
        viewModel.query = ""

        // THEN results cleared immediately
        XCTAssertEqual(viewModel.results.count, 0, "Results should be cleared")
    }

    // MARK: - Search Method Tests

    func testSearchExecutesWithCurrentQuery() async throws {
        // GIVEN view model with query
        viewModel.query = "test query"

        let noteId = UUID()
        await mockSearchEngine.setMockResults([SearchResult(noteId: noteId, relevance: 0.9)])

        // WHEN calling search manually
        await viewModel.search()

        // THEN search executed
        XCTAssertGreaterThan(viewModel.results.count, 0, "Search should return results")
    }

    func testSearchWithEmptyQueryDoesNothing() async throws {
        // GIVEN view model with empty query
        viewModel.query = ""

        // WHEN calling search
        await viewModel.search()

        // THEN no search executed
        let searchCount = await mockSearchEngine.searchCallCount
        XCTAssertEqual(searchCount, 0, "Should not search with empty query")
    }

    // MARK: - Results Tests

    func testResultsSortedByRelevance() async throws {
        // GIVEN search results with different relevance
        let note1 = UUID()
        let note2 = UUID()
        let note3 = UUID()

        await mockSearchEngine.setMockResults([
            SearchResult(noteId: note1, relevance: 0.5),
            SearchResult(noteId: note2, relevance: 0.9),
            SearchResult(noteId: note3, relevance: 0.7)
        ])

        viewModel.query = "test"

        // WHEN search executes
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN results sorted by descending relevance
        XCTAssertEqual(viewModel.results.count, 3)
        XCTAssertEqual(viewModel.results[0].noteId, note2, "Highest relevance first")
        XCTAssertEqual(viewModel.results[1].noteId, note3, "Medium relevance second")
        XCTAssertEqual(viewModel.results[2].noteId, note1, "Lowest relevance last")
    }

    // MARK: - Threshold Tests

    func testThresholdFilteringWorks() async throws {
        // GIVEN view model with custom threshold
        viewModel.threshold = 0.8

        let noteId = UUID()
        await mockSearchEngine.setMockResults([SearchResult(noteId: noteId, relevance: 0.9)])

        viewModel.query = "test"

        // WHEN search executes
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN search engine called with correct threshold
        let usedThreshold = await mockSearchEngine.lastThreshold
        XCTAssertEqual(usedThreshold, 0.8, "Should use custom threshold")
    }

    func testDefaultThresholdIs07() throws {
        // GIVEN new view model
        // THEN threshold is 0.7
        XCTAssertEqual(viewModel.threshold, 0.7, "Default threshold should be 0.7")
    }

    // MARK: - Load Note Details Tests

    func testLoadNoteDetailsFetchesCorrectNotes() async throws {
        // GIVEN search results
        let note1Id = UUID()
        let note2Id = UUID()

        let results = [
            SearchResult(noteId: note1Id, relevance: 0.9),
            SearchResult(noteId: note2Id, relevance: 0.8)
        ]

        // Add notes to mock repository
        let note1 = Note(id: note1Id, created: Date(), device: "test", location: nil,
                        content: "Content 1", title: "Note 1", backlinks: [], unknownFrontmatterFields: [:])
        let note2 = Note(id: note2Id, created: Date(), device: "test", location: nil,
                        content: "Content 2", title: "Note 2", backlinks: [], unknownFrontmatterFields: [:])

        await mockRepository.addNote(note1)
        await mockRepository.addNote(note2)

        // WHEN loading note details
        let notes = await viewModel.loadNoteDetails(for: results)

        // THEN correct notes fetched
        XCTAssertEqual(notes.count, 2)
        XCTAssertTrue(notes.contains(where: { $0.id == note1Id }))
        XCTAssertTrue(notes.contains(where: { $0.id == note2Id }))
    }

    func testLoadNoteDetailsSkipsMissingNotes() async throws {
        // GIVEN search results with non-existent note
        let existingId = UUID()
        let missingId = UUID()

        let results = [
            SearchResult(noteId: existingId, relevance: 0.9),
            SearchResult(noteId: missingId, relevance: 0.8)
        ]

        // Only add one note
        let note = Note(id: existingId, created: Date(), device: "test", location: nil,
                       content: "Content", title: "Note", backlinks: [], unknownFrontmatterFields: [:])
        await mockRepository.addNote(note)

        // WHEN loading note details
        let notes = await viewModel.loadNoteDetails(for: results)

        // THEN only existing note returned
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].id, existingId)
    }

    // MARK: - isSearching State Tests

    func testIsSearchingTrueDuringSearch() async throws {
        // GIVEN view model
        await mockSearchEngine.setSearchDelay(nanoseconds: 200_000_000) // 200ms delay

        var isSearchingStates: [Bool] = []

        // Observe isSearching
        viewModel.$isSearching
            .sink { isSearchingStates.append($0) }
            .store(in: &cancellables)

        viewModel.query = "test"

        // Sample isSearching during search
        try await Task.sleep(nanoseconds: 100_000_000) // During debounce
        try await Task.sleep(nanoseconds: 500_000_000) // During search

        // Wait for completion
        try await Task.sleep(nanoseconds: 200_000_000)

        // THEN isSearching was true during search
        XCTAssertTrue(isSearchingStates.contains(true), "isSearching should be true during search")
    }

    func testIsSearchingFalseAfterSearch() async throws {
        // GIVEN view model
        viewModel.query = "test"

        // WHEN search completes
        try await Task.sleep(nanoseconds: 800_000_000) // Wait for debounce + search

        // THEN isSearching is false
        XCTAssertFalse(viewModel.isSearching, "isSearching should be false after search")
    }

    // MARK: - Clear Tests

    func testClearResetsQuery() throws {
        // GIVEN view model with query
        viewModel.query = "test query"

        // WHEN clearing
        viewModel.clear()

        // THEN query cleared
        XCTAssertEqual(viewModel.query, "", "Query should be cleared")
    }

    func testClearResetsResults() async throws {
        // GIVEN view model with results
        let noteId = UUID()
        await mockSearchEngine.setMockResults([SearchResult(noteId: noteId, relevance: 0.9)])

        viewModel.query = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertGreaterThan(viewModel.results.count, 0)

        // WHEN clearing
        viewModel.clear()

        // THEN results cleared
        XCTAssertEqual(viewModel.results.count, 0, "Results should be cleared")
    }

    // MARK: - Error Handling Tests

    func testSearchErrorHandledGracefully() async throws {
        // GIVEN search engine that throws error
        await mockSearchEngine.setShouldFail(true)

        viewModel.query = "test"

        // WHEN search executes
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN no crash, results empty
        XCTAssertEqual(viewModel.results.count, 0, "Results should be empty on error")
        XCTAssertFalse(viewModel.isSearching, "isSearching should be false after error")
    }
}

// MARK: - Mock Classes

actor MockSearchVectorSearchEngine: VectorSearchEngineProtocol {
    var searchCallCount: Int = 0
    var lastThreshold: Float?
    private var mockResults: [SearchResult] = []
    private var shouldFail: Bool = false
    private var searchDelay: UInt64 = 0

    func setMockResults(_ results: [SearchResult]) {
        self.mockResults = results
    }

    func setShouldFail(_ fail: Bool) {
        self.shouldFail = fail
    }

    func setSearchDelay(nanoseconds: UInt64) {
        self.searchDelay = nanoseconds
    }

    func search(query: String, threshold: Float) async throws -> [SearchResult] {
        searchCallCount += 1
        lastThreshold = threshold

        if searchDelay > 0 {
            try await Task.sleep(nanoseconds: searchDelay)
        }

        if shouldFail {
            throw NSError(domain: "test", code: -1)
        }

        // Sort by relevance descending, matching VectorSearchEngine behavior
        return mockResults.sorted { $0.relevance > $1.relevance }
    }

    func indexNote(id: UUID, embedding: [Float]) async throws {
        // No-op for search tests
    }

    func removeNote(id: UUID) async {
        // No-op for search tests
    }

    func rebuild() async {
        // No-op for search tests
    }
}

actor MockSearchNoteRepository: NoteRepository {
    private var notes: [UUID: Note] = [:]

    func addNote(_ note: Note) {
        notes[note.id] = note
    }

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
        notes.removeValue(forKey: id)
    }

    func list(sortedBy: NoteSortOrder) async throws -> [Note] {
        return Array(notes.values)
    }
}
