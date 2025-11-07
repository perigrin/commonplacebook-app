// ABOUTME: In-memory implementation of NoteRepository for testing and development
// ABOUTME: Thread-safe actor-based storage using Dictionary for fast lookups

import Foundation

/// In-memory note repository with thread-safe access
actor InMemoryNoteRepository: NoteRepository {

    // Private storage keyed by note ID
    private var notes: [UUID: Note] = [:]

    init() {}

    // MARK: - NoteRepository Protocol

    func create(note: Note) async throws -> Note {
        // Check for duplicate
        if notes[note.id] != nil {
            throw RepositoryError.duplicateNote(note.id)
        }

        // Store a copy to ensure data isolation
        let noteCopy = note
        notes[note.id] = noteCopy

        return noteCopy
    }

    func read(id: UUID) async throws -> Note? {
        // Return a copy to ensure data isolation
        return notes[id]
    }

    func update(note: Note) async throws -> Note {
        // Check note exists
        guard notes[note.id] != nil else {
            throw RepositoryError.noteNotFound(note.id)
        }

        // Update with a copy
        let noteCopy = note
        notes[note.id] = noteCopy

        return noteCopy
    }

    func delete(id: UUID) async throws {
        // Deletion is idempotent - no error if note doesn't exist
        notes.removeValue(forKey: id)
    }

    func list() async throws -> [Note] {
        // Return copies of all notes
        return Array(notes.values)
    }

    func search(query: String) async throws -> [Note] {
        let lowercasedQuery = query.lowercased()

        return notes.values.filter { note in
            let titleMatch = note.title.lowercased().contains(lowercasedQuery)
            let contentMatch = note.content.lowercased().contains(lowercasedQuery)
            return titleMatch || contentMatch
        }
    }

    // MARK: - Additional Utilities

    /// Get the count of notes (useful for testing)
    func count() async -> Int {
        return notes.count
    }

    /// Clear all notes (useful for testing)
    func clear() async {
        notes.removeAll()
    }
}
