// ABOUTME: View model for search interface with query debouncing and result management
// ABOUTME: Coordinates VectorSearchEngine and NoteRepository for semantic search

import Foundation
import Combine

/// View model for search functionality
@MainActor
class SearchViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var query: String = ""
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var isSearching: Bool = false
    @Published var threshold: Float = 0.15 // Semantic search threshold (NLEmbedding typically produces 0.1-0.3 for related content)

    // MARK: - Private Properties

    private let searchEngine: any VectorSearchEngineProtocol
    let noteService: NoteService // Internal access for SearchResultsListView
    let repository: NoteRepository // Internal access for reading notes
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.5 // 500ms
    private var currentSearchTask: Task<Void, Never>?
    private var searchGeneration: Int = 0

    // MARK: - Initialization

    init(searchEngine: any VectorSearchEngineProtocol, noteService: NoteService, repository: NoteRepository) {
        self.searchEngine = searchEngine
        self.noteService = noteService
        self.repository = repository

        setupQueryObserver()
    }

    // MARK: - Setup

    private func setupQueryObserver() {
        // Observe query changes with debouncing
        $query
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newQuery in
                guard let self = self else { return }

                // Cancel previous search task
                self.currentSearchTask?.cancel()

                // Start new search task
                self.currentSearchTask = Task { @MainActor in
                    await self.handleQueryChange(newQuery)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Execute search with current query
    func search() async {
        await handleQueryChange(query)
    }

    /// Clear search query and results
    func clear() {
        query = ""
        results = []
    }

    /// Load full note details for search results
    /// - Parameter results: Array of search results
    /// - Returns: Array of notes with full details (parallel loading)
    func loadNoteDetails(for results: [SearchResult]) async -> [Note] {
        // Load notes in parallel using TaskGroup
        await withTaskGroup(of: Note?.self) { group in
            for result in results {
                group.addTask {
                    do {
                        return try await self.noteService.read(id: result.noteId)
                    } catch {
                        print("Error loading note \(result.noteId): \(error)")
                        return nil
                    }
                }
            }

            // Collect results, filtering out failures
            var notes: [Note] = []
            for await note in group {
                if let note = note {
                    notes.append(note)
                }
            }
            return notes
        }
    }

    // MARK: - Private Methods

    private func handleQueryChange(_ newQuery: String) async {
        print("🔍 SearchViewModel.handleQueryChange called with query: '\(newQuery)'")

        // Clear results if query is empty
        guard !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 Query is empty, clearing results")
            isSearching = false
            results = []
            return
        }

        // Increment generation to track this search
        searchGeneration += 1
        let currentGeneration = searchGeneration
        print("🔍 Starting search generation \(currentGeneration)")

        // Execute search
        isSearching = true

        do {
            print("🔍 Calling searchEngine.search with query: '\(newQuery)', threshold: \(threshold)")
            let searchResults = try await searchEngine.search(query: newQuery, threshold: threshold)
            print("🔍 Search returned \(searchResults.count) results")

            // Check if cancelled or superseded by newer search
            guard !Task.isCancelled && currentGeneration == searchGeneration else {
                print("🔍 Search cancelled or superseded (current: \(currentGeneration), latest: \(searchGeneration))")
                return
            }

            // Results are already sorted by relevance from search engine
            print("🔍 Setting results to \(searchResults.count) items")
            results = searchResults
            print("🔍 Results published: \(results.count) items")

        } catch {
            // Check if cancelled before updating state
            guard !Task.isCancelled && currentGeneration == searchGeneration else {
                print("🔍 Search error handling cancelled (current: \(currentGeneration), latest: \(searchGeneration))")
                return
            }

            print("❌ Search error: \(error)")
            results = []
        }

        isSearching = false
        print("🔍 Search complete, isSearching = false")
    }
}
