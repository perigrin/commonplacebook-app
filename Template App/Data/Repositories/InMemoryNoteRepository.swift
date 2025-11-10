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
        // Soft delete - set deletedAt timestamp and update modified
        guard var note = notes[id] else {
            return  // Idempotent - no error if note doesn't exist
        }

        let now = Date()
        note.deletedAt = now
        note.modified = now
        notes[id] = note
    }

    func list() async throws -> [Note] {
        // Return only non-deleted notes
        return notes.values.filter { !$0.isDeleted }
    }

    func search(query: String) async throws -> [Note] {
        let lowercasedQuery = query.lowercased()

        return notes.values.filter { note in
            // Exclude deleted notes
            guard !note.isDeleted else { return false }

            let titleMatch = note.title.lowercased().contains(lowercasedQuery)
            let contentMatch = note.content.lowercased().contains(lowercasedQuery)
            return titleMatch || contentMatch
        }
    }

    // MARK: - Trash Management

    func listTrashed() async throws -> [Note] {
        // Return only deleted notes
        return notes.values.filter { $0.isDeleted }
    }

    func restore(id: UUID) async throws {
        // Restore a deleted note and update modified timestamp
        guard var note = notes[id] else {
            throw RepositoryError.noteNotFound(id)
        }

        note.deletedAt = nil
        note.modified = Date()
        notes[id] = note
    }

    func purge(id: UUID) async throws {
        // Hard delete - permanently remove
        notes.removeValue(forKey: id)
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
