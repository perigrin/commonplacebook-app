// ABOUTME: Enhanced note list view with integrated search functionality
// ABOUTME: Switches between default mode (all notes) and search mode (filtered results)

import SwiftUI

struct EnhancedNoteListView: View {
    @ObservedObject var listViewModel: NoteListViewModel
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var appCoordinator: AppCoordinator
    @State private var selectedNote: Note?
    @State private var detailState: DetailPaneState = .empty

    /// Tracks what's displayed in the detail pane
    enum DetailPaneState: Equatable {
        case empty
        case viewing(Note)
        case editing(NoteViewModel)
        case creating(NoteViewModel)

        static func == (lhs: DetailPaneState, rhs: DetailPaneState) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty):
                return true
            case (.viewing(let lNote), .viewing(let rNote)):
                return lNote.id == rNote.id
            case (.editing(let lVM), .editing(let rVM)):
                return ObjectIdentifier(lVM) == ObjectIdentifier(rVM)
            case (.creating(let lVM), .creating(let rVM)):
                return ObjectIdentifier(lVM) == ObjectIdentifier(rVM)
            default:
                return false
            }
        }
    }

    /// Determines current display mode
    private var isSearchMode: Bool {
        !searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar: Note list with search at bottom
            ZStack {
                if isSearchMode {
                    searchModeContent
                } else {
                    defaultModeContent
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewNote) {
                        Label("New Note", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Search bar fixed at bottom
                SearchBar(query: $searchViewModel.query)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    #if os(iOS)
                    .background(Color(uiColor: .systemBackground))
                    #elseif os(macOS)
                    .background(Color(nsColor: .windowBackgroundColor))
                    #endif
            }
            .task {
                await listViewModel.loadNotes()
            }
            #if os(macOS)
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            #endif
        } detail: {
            // Detail pane: Note detail, editor, or empty state
            detailPane
        }
        #if os(macOS)
        .navigationSplitViewStyle(.balanced)
        #else
        .navigationSplitViewStyle(.automatic)
        #endif
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

            // Show in detail pane
            detailState = .creating(viewModel)
            selectedNote = nil
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        switch detailState {
        case .empty:
            emptyDetailPane
        case .viewing(let note):
            noteDetailPane(note: note)
        case .editing(let viewModel):
            noteEditPane(viewModel: viewModel, isNew: false)
        case .creating(let viewModel):
            noteEditPane(viewModel: viewModel, isNew: true)
        }
    }

    private var emptyDetailPane: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("Select a note")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private func noteDetailPane(note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(note.title)
                    .font(.title)
                    .fontWeight(.bold)

                // Content
                Text(contentWithoutTitle(note: note))
                    .font(.body)
                    .textSelection(.enabled)

                Spacer()
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    openEditView(for: note)
                }
            }
        }
    }

    private func noteEditPane(viewModel: NoteViewModel, isNew: Bool) -> some View {
        NoteEditView(viewModel: viewModel, onSave: {
            Task {
                // Index the note in the search engine
                await appCoordinator.indexNote(id: viewModel.id)

                await listViewModel.loadNotes()
                // Return to viewing the saved note
                if let savedNote = try? await listViewModel.repository.read(id: viewModel.id) {
                    await MainActor.run {
                        detailState = .viewing(savedNote)
                        selectedNote = savedNote
                    }
                }
            }
        }, onCancel: {
            // Return to previous state
            if isNew {
                detailState = .empty
                selectedNote = nil
            } else if let note = selectedNote {
                detailState = .viewing(note)
            }
        })
    }

    private func openEditView(for note: Note) {
        Task {
            let viewModel = NoteViewModel(repository: listViewModel.repository, noteId: note.id)
            await viewModel.load()

            await MainActor.run {
                detailState = .editing(viewModel)
            }
        }
    }

    private func contentWithoutTitle(note: Note) -> String {
        let titlePattern = "# \(note.title)"
        let cleaned = note.content
            .replacingOccurrences(of: titlePattern, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? note.content : cleaned
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
        List(selection: $selectedNote) {
            ForEach(listViewModel.notes) { note in
                Button(action: {
                    selectNote(note)
                }) {
                    NoteRowView(note: note)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                .listRowSeparator(.hidden)
                .tag(note)
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
        .scrollContentBackground(.hidden)
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

    private func selectNote(_ note: Note) {
        selectedNote = note
        detailState = .viewing(note)
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
            searchViewModel: searchViewModel,
            selectedNote: $selectedNote,
            onSelectNote: selectNote
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
    @Binding var selectedNote: Note?
    let onSelectNote: (Note) -> Void
    @State private var loadedNotes: [Note] = []
    @State private var loadTask: Task<Void, Never>?
    @State private var relevanceMap: [UUID: Float] = [:]
    @State private var loadGeneration: Int = 0

    var body: some View {
        List(selection: $selectedNote) {
            ForEach(loadedNotes) { note in
                Button(action: {
                    onSelectNote(note)
                }) {
                    SearchResultRowView(note: note, relevance: relevanceMap[note.id] ?? 0.0)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                .listRowSeparator(.hidden)
                .tag(note)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .onChange(of: searchViewModel.results) { _, newResults in
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .accessibilityLabel("Note title: \(note.title)")

                Spacer()

                // Relevance indicator
                Text("\(Int(relevance * 100))%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .opacity(0.6)
                    .accessibilityLabel("Relevance: \(Int(relevance * 100)) percent")
            }

            Text(previewText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .opacity(0.8)
                .lineLimit(2)
                .accessibilityLabel("Note content: \(previewText)")

            Text(note.created, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .opacity(0.6)
                .accessibilityLabel("Created \(note.created, style: .relative)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                searchViewModel: makeSearchViewModel(),
                appCoordinator: makeAppCoordinator()
            )
            .previewDisplayName("Default Mode")

            // Search mode with results
            EnhancedNoteListView(
                listViewModel: makeListViewModelWithNotes(),
                searchViewModel: makeSearchViewModelWithResults(),
                appCoordinator: makeAppCoordinator()
            )
            .previewDisplayName("Search Mode")

            // Empty search results
            EnhancedNoteListView(
                listViewModel: makeListViewModelWithNotes(),
                searchViewModel: makeSearchViewModelEmpty(),
                appCoordinator: makeAppCoordinator()
            )
            .previewDisplayName("No Results")
        }
    }

    @MainActor
    static func makeAppCoordinator() -> AppCoordinator {
        return AppCoordinator()
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
