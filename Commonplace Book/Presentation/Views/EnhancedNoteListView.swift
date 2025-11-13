// ABOUTME: Enhanced note list view with integrated search functionality
// ABOUTME: Switches between default mode (all notes) and search mode (filtered results)

import SwiftUI

struct EnhancedNoteListView: View {
    @ObservedObject var listViewModel: NoteListViewModel
    @ObservedObject var searchViewModel: SearchViewModel
    @State private var showingCreateNote = false
    @State private var createNoteViewModel: NoteViewModel?

    /// Determines current display mode
    private var isSearchMode: Bool {
        !searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar at top
                SearchBar(query: $searchViewModel.query)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Content area
                ZStack {
                    if isSearchMode {
                        searchModeContent
                    } else {
                        defaultModeContent
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note, repository: listViewModel.repository)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewNote) {
                        Label("New Note", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateNote) {
                if let viewModel = createNoteViewModel {
                    NavigationStack {
                        NoteEditView(viewModel: viewModel, onSave: {
                            Task {
                                await listViewModel.loadNotes()
                            }
                        })
                    }
                }
            }
            .task {
                await listViewModel.loadNotes()
            }
        }
    }

    private func createNewNote() {
        Task { @MainActor in
            // Create new note ID
            let newNoteId = UUID()

            // Create view model for new note
            let viewModel = NoteViewModel(repository: listViewModel.repository, noteId: newNoteId)

            // Collect initial metadata
            let metadataCollector = MetadataCollector()
            let device = await metadataCollector.getCurrentDevice()
            let location = await metadataCollector.getCurrentLocation()
            let timestamp = await metadataCollector.generateTimestamp()

            // Set initial values
            viewModel.updateTitle("")
            viewModel.updateContent("")
            Task { @MainActor in
                viewModel.device = device
                viewModel.location = location
                viewModel.created = timestamp
            }

            createNoteViewModel = viewModel
            showingCreateNote = true
        }
    }

    // MARK: - Default Mode Content

    private var defaultModeContent: some View {
        Group {
            if listViewModel.notes.isEmpty && !listViewModel.isLoading {
                defaultEmptyStateView
            } else {
                defaultNotesList
            }

            if listViewModel.isLoading && listViewModel.notes.isEmpty {
                loadingView
            }
        }
    }

    private var defaultNotesList: some View {
        List {
            ForEach(listViewModel.notes) { note in
                NavigationLink(value: note) {
                    NoteRowView(note: note)
                }
            }

            if listViewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            // Clear search when refreshing
            searchViewModel.clear()
            await listViewModel.loadNotes()
        }
        .overlay {
            if let error = listViewModel.error {
                errorView(error: error, onDismiss: {
                    Task { @MainActor in
                        await listViewModel.dismissError()
                    }
                })
            }
        }
    }

    private var defaultEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .accessibilityLabel("No notes icon")

            Text("No Notes Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Pull down to refresh")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Search Mode Content

    private var searchModeContent: some View {
        Group {
            if searchViewModel.isSearching {
                searchLoadingView
            } else if searchViewModel.results.isEmpty {
                searchEmptyStateView
            } else {
                searchResultsList
            }
        }
    }

    private var searchResultsList: some View {
        SearchResultsListView(
            searchViewModel: searchViewModel
        )
    }

    private var searchEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .accessibilityLabel("No results icon")

            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Try a different search query")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var searchLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .accessibilityLabel("Searching")
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .accessibilityLabel("Loading notes")
            Text("Loading notes...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(error: Error, onDismiss: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error.localizedDescription)
                    .font(.subheadline)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Dismiss error")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.primary.opacity(0.3))
    }
}

// MARK: - Search Results List View

struct SearchResultsListView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @State private var loadedNotes: [Note] = []
    @State private var loadTask: Task<Void, Never>?
    @State private var relevanceMap: [UUID: Float] = [:]
    @State private var loadGeneration: Int = 0

    var body: some View {
        List {
            ForEach(loadedNotes) { note in
                NavigationLink(value: note) {
                    SearchResultRowView(note: note, relevance: relevanceMap[note.id] ?? 0.0)
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: searchViewModel.results) { newResults in
            // Cancel previous load task
            loadTask?.cancel()

            // Increment generation to track this load
            loadGeneration += 1
            let currentGeneration = loadGeneration

            // Pre-compute relevance map for O(1) lookups
            relevanceMap = Dictionary(uniqueKeysWithValues: newResults.map { ($0.noteId, $0.relevance) })

            // Start new load task
            loadTask = Task { @MainActor in
                do {
                    let notes = try await loadNotesPreservingOrder(for: newResults)
                    // Only update if this is still the latest load (not superseded by newer search)
                    if !Task.isCancelled && currentGeneration == loadGeneration {
                        loadedNotes = notes
                    }
                } catch {
                    // Log error and clear results
                    if !Task.isCancelled {
                        Logger.error("Failed to load search results: \(error.localizedDescription)", category: .database)
                    }
                    if !Task.isCancelled && currentGeneration == loadGeneration {
                        loadedNotes = []
                    }
                }
            }
        }
        .onDisappear {
            // Cancel task when view disappears
            loadTask?.cancel()
        }
    }

    /// Load notes while preserving search result order
    /// Uses batched loading with max 20 concurrent tasks to prevent memory exhaustion
    private func loadNotesPreservingOrder(for results: [SearchResult]) async throws -> [Note] {
        let noteIds = results.map { $0.noteId }

        // Load in batches of 20 concurrent tasks to prevent unbounded parallelism
        // This prevents memory exhaustion when loading large result sets (e.g., thousands of notes)
        let maxConcurrentTasks = 20
        let batches = stride(from: 0, to: results.count, by: maxConcurrentTasks).map {
            Array(results[$0..<min($0 + maxConcurrentTasks, results.count)])
        }

        // Load batches sequentially, with parallel loading within each batch
        var notesDict: [UUID: Note] = [:]
        for batch in batches {
            let batchNotes = await withTaskGroup(of: (UUID, Note?).self) { group in
                for result in batch {
                    group.addTask {
                        do {
                            let note = try await searchViewModel.repository.read(id: result.noteId)
                            return (result.noteId, note)
                        } catch {
                            Logger.error("Failed to load note \(result.noteId): \(error.localizedDescription)", category: .database)
                            return (result.noteId, nil)
                        }
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

            // Merge batch results into main dictionary
            notesDict.merge(batchNotes) { _, new in new }
        }

        // Return in original order, filtering out failures
        return noteIds.compactMap { notesDict[$0] }
    }
}

// MARK: - Search Result Row View

struct SearchResultRowView: View {
    private enum Constants {
        static let previewCharacterLimit = 100
    }

    private static let abstractGenerator = AbstractGenerator()

    let note: Note
    let relevance: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .accessibilityLabel("Note title: \(note.title)")

                Spacer()

                // Relevance indicator
                Text("\(Int(relevance * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Relevance: \(Int(relevance * 100)) percent")
            }

            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityLabel("Note content: \(previewText)")

            Text(note.created, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Created \(note.created, style: .relative)")
        }
        .padding(.vertical, 4)
    }

    private var previewText: String {
        // Use AbstractGenerator for smart truncation with markdown stripping
        return Self.abstractGenerator.generateAbstract(
            from: note.content,
            maxLength: Constants.previewCharacterLimit
        )
    }
}

// MARK: - Previews

struct EnhancedNoteListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default mode with notes
            EnhancedNoteListView(
                listViewModel: makeListViewModelWithNotes(),
                searchViewModel: makeSearchViewModel()
            )
            .previewDisplayName("Default Mode")

            // Search mode with results
            EnhancedNoteListView(
                listViewModel: makeListViewModelWithNotes(),
                searchViewModel: makeSearchViewModelWithResults()
            )
            .previewDisplayName("Search Mode")

            // Empty search results
            EnhancedNoteListView(
                listViewModel: makeListViewModelWithNotes(),
                searchViewModel: makeSearchViewModelEmpty()
            )
            .previewDisplayName("No Results")
        }
    }

    @MainActor
    static func makeListViewModelWithNotes() -> NoteListViewModel {
        let repository = InMemoryNoteRepository()
        let viewModel = NoteListViewModel(repository: repository, metadataCollector: nil)

        // Add notes synchronously for preview
        let note1 = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-3600),
            device: "iPhone 15",
            location: nil,
            content: "Sample note content",
            title: "Sample Note 1",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        Task { @MainActor in
            _ = try? await repository.create(note: note1)
            await viewModel.loadNotes()
        }

        return viewModel
    }

    static func makeSearchViewModel() -> SearchViewModel {
        let mockEngine = MockPreviewSearchEngine()
        let repository = InMemoryNoteRepository()
        return SearchViewModel(searchEngine: mockEngine, repository: repository)
    }

    @MainActor
    static func makeSearchViewModelWithResults() -> SearchViewModel {
        let mockEngine = MockPreviewSearchEngine()
        let repository = InMemoryNoteRepository()
        let viewModel = SearchViewModel(searchEngine: mockEngine, repository: repository)

        viewModel.query = "test"

        return viewModel
    }

    @MainActor
    static func makeSearchViewModelEmpty() -> SearchViewModel {
        let mockEngine = MockPreviewSearchEngine()
        let repository = InMemoryNoteRepository()
        let viewModel = SearchViewModel(searchEngine: mockEngine, repository: repository)

        viewModel.query = "nonexistent"

        return viewModel
    }
}

// MARK: - Mock for Previews

actor MockPreviewSearchEngine: VectorSearchEngineProtocol {
    func search(query: String, threshold: Float) async throws -> [SearchResult] {
        return []
    }

    func indexNote(id: UUID, embedding: [Float]) async throws {}
    func removeNote(id: UUID) async {}
    func rebuild() async {}
}
