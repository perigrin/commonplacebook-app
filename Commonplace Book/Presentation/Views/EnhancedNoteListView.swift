// ABOUTME: Enhanced note list view with integrated search functionality
// ABOUTME: Switches between default mode (all notes) and search mode (filtered results)

import SwiftUI

struct EnhancedNoteListView: View {
    @ObservedObject var listViewModel: NoteListViewModel
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var appCoordinator: AppCoordinator
    @State private var selectedNote: Note?
    @State private var detailState: DetailPaneState = .empty
    @State private var showingCaptureView = false

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
        let _ = print("🎯 EnhancedNoteListView - isSearchMode: \(isSearchMode), query: '\(searchViewModel.query)'")
        
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
                    Button(action: { showingCaptureView = true }) {
                        Label("Voice Note", systemImage: "mic.fill")
                    }
                }
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
                    .background(Theme.Colors.searchBarBackground)
            }
            .task {
                await listViewModel.loadNotes()
            }
            .sheet(isPresented: $showingCaptureView) {
                // Reload notes when capture view is dismissed
                Task {
                    await listViewModel.loadNotes()
                }
            } content: {
                CaptureView(
                    viewModel: CaptureViewModel(
                        speechService: SpeechRecognitionService(),
                        audioMonitor: AudioLevelMonitor(),
                        metadataCollector: MetadataCollector(),
                        noteService: listViewModel.noteService
                    ),
                    manualNoteCreator: ManualNoteCreator(
                        noteService: listViewModel.noteService,
                        metadataCollector: MetadataCollector()
                    )
                )
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

            // Create view model for new note using noteService from listViewModel
            let viewModel = NoteViewModel(noteService: listViewModel.noteService, noteId: newNoteId)

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
                .foregroundColor(Theme.Colors.secondaryText)
            Text("Select a note")
                .font(.title2)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.detailBackground)
    }

    private func noteDetailPane(note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(note.title)
                    .font(Theme.Typography.detailTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.primaryText)

                // Content
                Text(contentWithoutTitle(note: note))
                    .font(Theme.Typography.detailBody)
                    .foregroundColor(Theme.Colors.primaryText)
                    .textSelection(.enabled)

                Spacer()
            }
            .padding()
        }
        .background(Theme.Colors.detailBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    openEditView(for: note)
                }) {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .foregroundColor(Theme.Colors.accent)
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
            let viewModel = NoteViewModel(noteService: listViewModel.noteService, noteId: note.id)
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
                .listRowBackground(Color.clear)
                .tag(note)
            }

            if listViewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Theme.Colors.accent)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.noteListBackground)
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
                .foregroundColor(Theme.Colors.secondaryText)
                .accessibilityLabel("No notes icon")

            Text("No Notes Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)

            Text("Pull down to refresh")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.noteListBackground)
    }

    // MARK: - Search Mode Content

    private var searchModeContent: some View {
        let _ = print("🔍 Search mode - isSearching: \(searchViewModel.isSearching), results count: \(searchViewModel.results.count)")
        
        return Group {
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
                .foregroundColor(Theme.Colors.secondaryText)
                .accessibilityLabel("No results icon")

            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)

            Text("Try a different search query")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.noteListBackground)
    }

    private var searchLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Theme.Colors.accent)
                .accessibilityLabel("Searching")
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.noteListBackground)
    }

    // MARK: - Shared Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Theme.Colors.accent)
                .accessibilityLabel("Loading notes")
            Text("Loading notes...")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.noteListBackground)
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
                .listRowBackground(Color.clear)
                .tag(note)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.noteListBackground)
        .task(id: searchViewModel.results) {
            print("🔔 task(id:) triggered! Results count: \(searchViewModel.results.count)")

            // Cancel previous load task
            loadTask?.cancel()

            // Increment generation to track this load
            loadGeneration += 1
            let currentGeneration = loadGeneration

            let results = searchViewModel.results

            // Pre-compute relevance map for O(1) lookups
            relevanceMap = Dictionary(uniqueKeysWithValues: results.map { ($0.noteId, $0.relevance) })

            // Start new load task
            loadTask = Task { @MainActor in
                do {
                    print("📥 Loading \(results.count) notes for search results...")
                    let notes = try await loadNotesPreservingOrder(for: results)
                    print("📥 Loaded \(notes.count) notes successfully")
                    // Only update if this is still the latest load (not superseded by newer search)
                    if !Task.isCancelled && currentGeneration == loadGeneration {
                        loadedNotes = notes
                        print("📥 Updated loadedNotes with \(notes.count) notes")
                    }
                } catch {
                    // Log error and clear results
                    if !Task.isCancelled {
                        print("❌ Failed to load search results: \(error.localizedDescription)")
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
                    .font(Theme.Typography.noteTitle)
                    .foregroundColor(Theme.Colors.primaryText)
                    .accessibilityLabel("Note title: \(note.title)")

                Spacer()

                // Relevance indicator
                Text("\(Int(relevance * 100))%")
                    .font(Theme.Typography.noteDate)
                    .foregroundStyle(Theme.Colors.accent)
                    .accessibilityLabel("Relevance: \(Int(relevance * 100)) percent")
            }

            Text(previewText)
                .font(Theme.Typography.notePreview)
                .foregroundStyle(Theme.Colors.secondaryText)
                .lineLimit(2)
                .accessibilityLabel("Note content: \(previewText)")

            Text(note.created, style: .relative)
                .font(Theme.Typography.noteDate)
                .foregroundStyle(Theme.Colors.secondaryText)
                .opacity(0.7)
                .accessibilityLabel("Created \(note.created, style: .relative)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.noteRowBackground)
        .cornerRadius(Theme.CornerRadius.small)
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
        let embeddingService = EmbeddingService()
        let searchEngine = VectorSearchEngine(embeddingService: embeddingService)
        let noteService = NoteService(repository: repository, searchEngine: searchEngine, embeddingService: embeddingService)
        let viewModel = NoteListViewModel(noteService: noteService, repository: repository, metadataCollector: nil)

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
        let embeddingService = EmbeddingService()
        let noteService = NoteService(repository: repository, searchEngine: mockEngine, embeddingService: embeddingService)
        return SearchViewModel(searchEngine: mockEngine, noteService: noteService, repository: repository)
    }

    @MainActor
    static func makeSearchViewModelWithResults() -> SearchViewModel {
        let mockEngine = MockPreviewSearchEngine()
        let repository = InMemoryNoteRepository()
        let embeddingService = EmbeddingService()
        let noteService = NoteService(repository: repository, searchEngine: mockEngine, embeddingService: embeddingService)
        let viewModel = SearchViewModel(searchEngine: mockEngine, noteService: noteService, repository: repository)

        viewModel.query = "test"

        return viewModel
    }

    @MainActor
    static func makeSearchViewModelEmpty() -> SearchViewModel {
        let mockEngine = MockPreviewSearchEngine()
        let repository = InMemoryNoteRepository()
        let embeddingService = EmbeddingService()
        let noteService = NoteService(repository: repository, searchEngine: mockEngine, embeddingService: embeddingService)
        let viewModel = SearchViewModel(searchEngine: mockEngine, noteService: noteService, repository: repository)

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
