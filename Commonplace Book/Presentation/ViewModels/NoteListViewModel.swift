// ABOUTME: ViewModel for displaying and managing a list of notes
// ABOUTME: Handles loading, sorting, creating, and deleting notes following MVVM pattern

import Foundation
import Combine

/// ViewModel for note list display and management
@MainActor
class NoteListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var notes: [Note] = []
    @Published private(set) var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Private Properties

    private let repository: NoteRepository
    private let metadataCollector: MetadataCollector
    private var loadingOperations: Int = 0

    // MARK: - Initialization

    /// Initialize view model with repository
    /// - Parameter repository: Repository for note persistence
    init(repository: NoteRepository, metadataCollector: MetadataCollector? = nil) {
        self.repository = repository
        self.metadataCollector = metadataCollector ?? MetadataCollector()
    }

    // MARK: - Public Methods

    /// Load all notes from repository
    func loadNotes() async {
        startLoading()
        error = nil

        do {
            let loadedNotes = try await repository.list()
            notes = sortNotes(loadedNotes)
            endLoading()
        } catch {
            self.error = error
            // Don't clear notes on error - preserve existing UI data
            endLoading()
        }
    }

    /// Create a new note with metadata
    /// - Parameters:
    ///   - title: Note title
    ///   - content: Note content
    /// - Returns: Created note, or nil if creation failed
    @discardableResult
    func createNote(title: String, content: String) async -> Note? {
        // Validate input
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.error = NoteListViewModelError.emptyTitle
            return nil
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.error = NoteListViewModelError.emptyContent
            return nil
        }

        startLoading()
        error = nil

        do {
            // Collect metadata
            let device = await metadataCollector.getCurrentDevice()
            let location = await metadataCollector.getCurrentLocation()
            let timestamp = await metadataCollector.generateTimestamp()

            // Create note with metadata
            let newNote = Note(
                id: UUID(),
                created: timestamp,
                device: device,
                location: location,
                content: content,
                title: title,
                backlinks: [],
                unknownFrontmatterFields: [:]
            )

            // Save to repository
            let createdNote = try await repository.create(note: newNote)

            // Add to notes array and resort to maintain sort order
            notes.append(createdNote)
            notes = sortNotes(notes)

            endLoading()
            return createdNote
        } catch {
            self.error = error
            endLoading()
            return nil
        }
    }

    /// Delete a note
    /// - Parameter id: UUID of note to delete
    func deleteNote(id: UUID) async {
        startLoading()
        error = nil

        do {
            try await repository.delete(id: id)

            // Remove from notes array
            notes.removeAll { $0.id == id }

            endLoading()
        } catch {
            self.error = error
            endLoading()
        }
    }

    /// Refresh notes from repository
    func refresh() async {
        await loadNotes()
    }

    /// Dismiss current error
    func dismissError() async {
        error = nil
    }

    // MARK: - Private Methods

    /// Start a loading operation
    private func startLoading() {
        loadingOperations += 1
        isLoading = true
    }

    /// End a loading operation
    private func endLoading() {
        loadingOperations = max(0, loadingOperations - 1)
        isLoading = loadingOperations > 0
    }

    /// Sort notes by created date (newest first)
    /// - Parameter notesToSort: Array of notes to sort
    /// - Returns: Sorted array
    private func sortNotes(_ notesToSort: [Note]) -> [Note] {
        return notesToSort.sorted { $0.created > $1.created }
    }
}

// MARK: - Errors

enum NoteListViewModelError: LocalizedError {
    case emptyTitle
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Title cannot be empty"
        case .emptyContent:
            return "Content cannot be empty"
        }
    }
}
