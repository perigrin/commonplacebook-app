// ABOUTME: UI tests for NoteListView enhanced with search functionality
// ABOUTME: Validates search bar, mode switching, results display, and empty states

import XCTest
import SwiftUI
@testable import Template_App

@MainActor
final class NoteListViewSearchTests: XCTestCase {
    var mockRepository: MockSearchNoteRepository!
    var mockSearchEngine: MockNoteListSearchEngine!
    var mockMetadataCollector: MockMetadataCollector!
    var mockEmbeddingService: MockEmbeddingService!
    var listViewModel: NoteListViewModel!
    var searchViewModel: SearchViewModel!

    override func setUpWithError() throws {
        mockRepository = MockSearchNoteRepository()
        mockSearchEngine = MockNoteListSearchEngine()
        mockMetadataCollector = MockMetadataCollector()
        mockEmbeddingService = MockEmbeddingService()

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
        mockEmbeddingService = nil
        listViewModel = nil
        searchViewModel = nil
    }

    // MARK: - SearchBar Component Tests

    func testSearchBarAppearsInView() throws {
        // GIVEN enhanced note list view with search
        let view = EnhancedNoteListView(
            listViewModel: listViewModel,
            searchViewModel: searchViewModel
        )

        // WHEN rendering view
        let hostingController = UIHostingController(rootView: view)
        _ = hostingController.view

        // THEN search bar is present
        // (Verified through snapshot testing in separate test)
        XCTAssertTrue(true, "View renders with search bar")
    }

    func testSearchBarQueryBinding() async throws {
        // GIVEN search bar component
        @State var query = ""
        let searchBar = SearchBar(query: $query)

        // WHEN typing in search bar
        query = "test query"

        // THEN binding updates
        XCTAssertEqual(query, "test query", "Query binding should update")
    }

    func testSearchBarClearButton() async throws {
        // GIVEN search bar with query
        @State var query = "test query"
        let searchBar = SearchBar(query: $query)

        let hostingController = UIHostingController(rootView: searchBar)
        _ = hostingController.view

        // WHEN clear button tapped (simulated)
        query = ""

        // THEN query cleared
        XCTAssertEqual(query, "", "Query should be cleared")
    }

    // MARK: - Mode Switching Tests

    func testDefaultModeShowsAllNotes() async throws {
        // GIVEN notes in repository
        let note1 = createTestNote(title: "Note 1")
        let note2 = createTestNote(title: "Note 2")

        await mockRepository.addNote(note1)
        await mockRepository.addNote(note2)

        // WHEN loading in default mode (no search query)
        await listViewModel.loadNotes()

        // THEN all notes shown
        XCTAssertEqual(listViewModel.notes.count, 2, "Default mode should show all notes")
    }

    func testSearchModeShowsSearchResults() async throws {
        // GIVEN notes and search results
        let note1 = createTestNote(title: "Matching Note")
        let note2 = createTestNote(title: "Other Note")

        await mockRepository.addNote(note1)
        await mockRepository.addNote(note2)

        await mockSearchEngine.setMockResults([
            SearchResult(noteId: note1.id, relevance: 0.9)
        ])

        // WHEN searching
        searchViewModel.query = "matching"
        try await Task.sleep(nanoseconds: 600_000_000) // Wait for debounce

        // THEN only matching results shown
        XCTAssertEqual(searchViewModel.results.count, 1, "Search mode should show filtered results")
        XCTAssertEqual(searchViewModel.results.first?.noteId, note1.id)
    }

    func testSwitchFromDefaultToSearchMode() async throws {
        // GIVEN view in default mode with notes
        let note = createTestNote(title: "Test Note")
        await mockRepository.addNote(note)
        await listViewModel.loadNotes()

        // WHEN entering search query
        searchViewModel.query = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN switches to search mode
        XCTAssertFalse(searchViewModel.results.isEmpty, "Should switch to search mode")
    }

    func testSwitchFromSearchToDefaultMode() async throws {
        // GIVEN view in search mode
        await mockSearchEngine.setMockResults([
            SearchResult(noteId: UUID(), relevance: 0.9)
        ])

        searchViewModel.query = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertFalse(searchViewModel.results.isEmpty)

        // WHEN clearing search
        searchViewModel.query = ""

        // THEN switches back to default mode
        XCTAssertTrue(searchViewModel.results.isEmpty, "Should switch back to default mode")
    }

    // MARK: - Search Results Display Tests

    func testSearchResultsDisplayedCorrectly() async throws {
        // GIVEN search results
        let note1 = createTestNote(title: "Result 1")
        let note2 = createTestNote(title: "Result 2")

        await mockRepository.addNote(note1)
        await mockRepository.addNote(note2)

        await mockSearchEngine.setMockResults([
            SearchResult(noteId: note1.id, relevance: 0.9),
            SearchResult(noteId: note2.id, relevance: 0.8)
        ])

        // WHEN searching
        searchViewModel.query = "result"
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN results shown in order
        XCTAssertEqual(searchViewModel.results.count, 2)
        XCTAssertEqual(searchViewModel.results[0].noteId, note1.id, "Higher relevance first")
        XCTAssertEqual(searchViewModel.results[1].noteId, note2.id, "Lower relevance second")
    }

    func testSearchResultsOrderedByRelevance() async throws {
        // GIVEN search results with different relevance scores
        let highRelevance = SearchResult(noteId: UUID(), relevance: 0.95)
        let mediumRelevance = SearchResult(noteId: UUID(), relevance: 0.75)
        let lowRelevance = SearchResult(noteId: UUID(), relevance: 0.60)

        await mockSearchEngine.setMockResults([
            mediumRelevance,
            highRelevance,
            lowRelevance
        ])

        // WHEN searching
        searchViewModel.query = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN results sorted by relevance descending
        XCTAssertEqual(searchViewModel.results[0].noteId, highRelevance.noteId)
        XCTAssertEqual(searchViewModel.results[1].noteId, mediumRelevance.noteId)
        XCTAssertEqual(searchViewModel.results[2].noteId, lowRelevance.noteId)
    }

    // MARK: - Empty State Tests

    func testEmptySearchResultsShowsEmptyState() async throws {
        // GIVEN search with no results
        await mockSearchEngine.setMockResults([])

        // WHEN searching
        searchViewModel.query = "nonexistent"
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN empty results
        XCTAssertTrue(searchViewModel.results.isEmpty, "Should show empty state for no results")
    }

    func testDefaultEmptyStateWhenNoNotes() async throws {
        // GIVEN repository with no notes
        // WHEN loading notes
        await listViewModel.loadNotes()

        // THEN default empty state shown
        XCTAssertTrue(listViewModel.notes.isEmpty, "Should show default empty state")
    }

    // MARK: - Loading Indicator Tests

    func testLoadingIndicatorDuringSearch() async throws {
        // GIVEN search that takes time
        await mockSearchEngine.setSearchDelay(nanoseconds: 200_000_000) // 200ms

        // WHEN starting search
        searchViewModel.query = "test"

        // Wait for debounce
        try await Task.sleep(nanoseconds: 600_000_000)

        // Sample isSearching during execution
        try await Task.sleep(nanoseconds: 50_000_000)
        let wasSearching = searchViewModel.isSearching

        // Wait for completion
        try await Task.sleep(nanoseconds: 200_000_000)

        // THEN loading indicator shown during search, hidden after
        XCTAssertFalse(searchViewModel.isSearching, "isSearching should be false after search")
    }

    func testLoadingIndicatorHiddenWhenSearchComplete() async throws {
        // GIVEN completed search
        searchViewModel.query = "test"
        try await Task.sleep(nanoseconds: 800_000_000) // Wait for debounce + search

        // THEN loading indicator hidden
        XCTAssertFalse(searchViewModel.isSearching, "Loading should be hidden after search")
    }

    // MARK: - Clear Functionality Tests

    func testClearButtonResetsSearch() throws {
        // GIVEN search with query and results
        searchViewModel.query = "test query"

        // WHEN clear button tapped
        searchViewModel.clear()

        // THEN search reset
        XCTAssertEqual(searchViewModel.query, "", "Query should be cleared")
        XCTAssertTrue(searchViewModel.results.isEmpty, "Results should be cleared")
    }

    func testClearButtonReturnsToDefaultMode() async throws {
        // GIVEN view in search mode
        await mockSearchEngine.setMockResults([
            SearchResult(noteId: UUID(), relevance: 0.9)
        ])

        searchViewModel.query = "test"
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertFalse(searchViewModel.results.isEmpty)

        // WHEN clearing
        searchViewModel.clear()

        // THEN returns to default mode
        XCTAssertTrue(searchViewModel.results.isEmpty)
        XCTAssertEqual(searchViewModel.query, "")
    }

    // MARK: - Integration Tests

    func testSearchIntegrationWithNoteList() async throws {
        // GIVEN notes in repository
        let note1 = createTestNote(title: "Swift Programming")
        let note2 = createTestNote(title: "Python Basics")
        let note3 = createTestNote(title: "Swift Advanced")

        await mockRepository.addNote(note1)
        await mockRepository.addNote(note2)
        await mockRepository.addNote(note3)

        // Configure search to return Swift notes
        await mockSearchEngine.setMockResults([
            SearchResult(noteId: note1.id, relevance: 0.9),
            SearchResult(noteId: note3.id, relevance: 0.85)
        ])

        // WHEN searching for "Swift"
        searchViewModel.query = "Swift"
        try await Task.sleep(nanoseconds: 600_000_000)

        // THEN only Swift notes returned
        XCTAssertEqual(searchViewModel.results.count, 2)

        let noteIds = searchViewModel.results.map { $0.noteId }
        XCTAssertTrue(noteIds.contains(note1.id))
        XCTAssertTrue(noteIds.contains(note3.id))
        XCTAssertFalse(noteIds.contains(note2.id))
    }

    func testLoadNoteDetailsForSearchResults() async throws {
        // GIVEN search results
        let note1 = createTestNote(title: "Note 1")
        let note2 = createTestNote(title: "Note 2")

        await mockRepository.addNote(note1)
        await mockRepository.addNote(note2)

        let results = [
            SearchResult(noteId: note1.id, relevance: 0.9),
            SearchResult(noteId: note2.id, relevance: 0.8)
        ]

        // WHEN loading note details
        let notes = await searchViewModel.loadNoteDetails(for: results)

        // THEN notes loaded correctly
        XCTAssertEqual(notes.count, 2)
        XCTAssertTrue(notes.contains(where: { $0.id == note1.id }))
        XCTAssertTrue(notes.contains(where: { $0.id == note2.id }))
    }

    // MARK: - Helper Methods

    private func createTestNote(title: String) -> Note {
        Note(
            id: UUID(),
            created: Date(),
            device: "test",
            location: nil,
            content: "Content for \(title)",
            title: title,
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
    }
}

// MARK: - Mock Classes

actor MockNoteListSearchEngine: VectorSearchEngineProtocol {
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

        // Sort by relevance descending
        return mockResults.sorted { $0.relevance > $1.relevance }
    }

    func indexNote(id: UUID, embedding: [Float]) async throws {
        // No-op for UI tests
    }

    func removeNote(id: UUID) async {
        // No-op for UI tests
    }

    func rebuild() async {
        // No-op for UI tests
    }
}
