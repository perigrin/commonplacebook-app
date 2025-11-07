// ABOUTME: ViewModel for displaying and managing a list of notes
// ABOUTME: Handles loading, sorting, creating, and deleting notes following MVVM pattern

import Foundation
import Combine

/// ViewModel for note list display and management
@MainActor
class NoteListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var notes: [Note] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Private Properties

    private let repository: NoteRepository
    private let metadataCollector: MetadataCollector

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
        isLoading = true
        error = nil

        do {
            let loadedNotes = try await repository.list()
            notes = sortNotes(loadedNotes)
            isLoading = false
        } catch {
            self.error = error
            notes = []
            isLoading = false
        }
    }

    /// Create a new note with metadata
    /// - Parameters:
    ///   - title: Note title
    ///   - content: Note content
    /// - Returns: Created note, or nil if creation failed
    @discardableResult
    func createNote(title: String, content: String) async -> Note? {
        isLoading = true
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

            // Add to notes array and resort
            notes.insert(createdNote, at: 0) // Insert at beginning (most recent)

            isLoading = false
            return createdNote
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }

    /// Delete a note
    /// - Parameter id: UUID of note to delete
    func deleteNote(id: UUID) async {
        isLoading = true
        error = nil

        do {
            try await repository.delete(id: id)

            // Remove from notes array
            notes.removeAll { $0.id == id }

            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    /// Refresh notes from repository
    func refresh() async {
        await loadNotes()
    }

    // MARK: - Private Methods

    /// Sort notes by created date (newest first)
    /// - Parameter notesToSort: Array of notes to sort
    /// - Returns: Sorted array
    private func sortNotes(_ notesToSort: [Note]) -> [Note] {
        return notesToSort.sorted { $0.created > $1.created }
    }
}
