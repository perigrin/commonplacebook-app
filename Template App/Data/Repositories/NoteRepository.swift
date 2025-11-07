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

    /// Delete a note by ID
    /// - Parameter id: The UUID of the note to delete
    /// - Throws: Never throws - deletion is idempotent
    func delete(id: UUID) async throws

    /// List all notes
    /// - Returns: Array of all notes in the repository
    /// - Throws: RepositoryError on storage failures
    func list() async throws -> [Note]

    /// Search notes by query string
    /// - Parameter query: The search query (case-insensitive)
    /// - Returns: Array of notes matching the query in title or content
    /// - Throws: RepositoryError on storage failures
    func search(query: String) async throws -> [Note]
}
