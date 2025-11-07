// ABOUTME: ViewModel for displaying and editing a single note
// ABOUTME: Handles loading, saving, validation, and state management following MVVM pattern

import Foundation
import Combine

/// ViewModel for note display and editing
@MainActor
class NoteViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var id: UUID
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var created: Date = Date()
    @Published var device: String = ""
    @Published var location: Location?
    @Published var backlinks: [UUID] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Private Properties

    private let repository: NoteRepository
    private let noteId: UUID

    // MARK: - Initialization

    /// Initialize view model with repository and note ID
    /// - Parameters:
    ///   - repository: Repository for note persistence
    ///   - noteId: ID of the note to display/edit
    init(repository: NoteRepository, noteId: UUID) {
        self.repository = repository
        self.noteId = noteId
        self.id = noteId
    }

    // MARK: - Public Methods

    /// Load note from repository
    func load() async {
        isLoading = true
        error = nil

        do {
            guard let note = try await repository.read(id: noteId) else {
                throw NoteViewModelError.noteNotFound
            }

            // Update all fields
            self.id = note.id
            self.title = note.title
            self.content = note.content
            self.created = note.created
            self.device = note.device
            self.location = note.location
            self.backlinks = Array(note.backlinks)

            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    /// Save current state to repository
    func save() async {
        // Validate fields
        do {
            try validate()
        } catch {
            self.error = error
            return
        }

        isLoading = true
        error = nil

        do {
            // Create updated note with current values
            let updatedNote = Note(
                id: id,
                created: created,
                device: device,
                location: location,
                content: content,
                title: title,
                backlinks: Set(backlinks),
                unknownFrontmatterFields: [:]
            )

            _ = try await repository.update(note: updatedNote)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    /// Update note content
    /// - Parameter content: New markdown content
    func updateContent(_ content: String) {
        self.content = content

        // Clear error if content is now valid
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = nil
        }
    }

    /// Update note title
    /// - Parameter title: New title
    func updateTitle(_ title: String) {
        self.title = title

        // Clear error if title is now valid
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = nil
        }
    }

    // MARK: - Private Methods

    /// Validate note fields
    /// - Throws: NoteViewModelError if validation fails
    private func validate() throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            throw NoteViewModelError.emptyTitle
        }

        if trimmedContent.isEmpty {
            throw NoteViewModelError.emptyContent
        }
    }
}

// MARK: - Errors

enum NoteViewModelError: LocalizedError {
    case noteNotFound
    case emptyTitle
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .noteNotFound:
            return "Note not found"
        case .emptyTitle:
            return "Title cannot be empty"
        case .emptyContent:
            return "Content cannot be empty"
        }
    }
}
