// ABOUTME: Protocol defining repository pattern for note management
// ABOUTME: Provides interface for CRUD operations and search functionality

import Foundation

/// Repository protocol for managing notes
protocol NoteRepository {
    /// Create a new note
    /// - Parameter note: The note to create
    /// - Returns: The created note
    /// - Throws: RepositoryError.duplicateNote if note with same ID already exists
    func create(note: Note) async throws -> Note

    /// Read a note by ID
    /// - Parameter id: The UUID of the note to read
    /// - Returns: The note if found, nil otherwise
    /// - Throws: RepositoryError on storage failures
    func read(id: UUID) async throws -> Note?

    /// Update an existing note
    /// - Parameter note: The note with updated values
    /// - Returns: The updated note
    /// - Throws: RepositoryError.noteNotFound if note doesn't exist
    func update(note: Note) async throws -> Note

    /// Soft delete a note by ID (sets deletedAt timestamp)
    /// - Parameter id: The UUID of the note to delete
    /// - Throws: Never throws - deletion is idempotent
    func delete(id: UUID) async throws

    /// List all non-deleted notes
    /// - Returns: Array of all notes where deletedAt is nil
    /// - Throws: RepositoryError on storage failures
    func list() async throws -> [Note]

    /// Search notes by query string (excludes deleted notes)
    /// - Parameter query: The search query (case-insensitive)
    /// - Returns: Array of notes matching the query in title or content
    /// - Throws: RepositoryError on storage failures
    func search(query: String) async throws -> [Note]

    // MARK: - Trash Management

    /// List all deleted notes (soft-deleted with deletedAt set)
    /// - Returns: Array of notes where deletedAt is not nil
    /// - Throws: RepositoryError on storage failures
    func listTrashed() async throws -> [Note]

    /// Restore a soft-deleted note (clears deletedAt)
    /// - Parameter id: The UUID of the note to restore
    /// - Throws: RepositoryError.noteNotFound if note doesn't exist
    func restore(id: UUID) async throws

    /// Permanently delete a note (hard delete)
    /// - Parameter id: The UUID of the note to purge
    /// - Throws: Never throws - purge is idempotent
    func purge(id: UUID) async throws
}
