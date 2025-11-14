// ABOUTME: Service layer for note operations with automatic search indexing
// ABOUTME: Coordinates repository persistence and vector search index updates

import Foundation

/// Protocol for note service operations
protocol NoteServiceProtocol {
    /// Create a new note and index it for search
    func create(note: Note) async throws -> Note

    /// Update an existing note and re-index it
    func update(note: Note) async throws -> Note

    /// Delete a note and remove from search index
    func delete(id: UUID) async throws

    /// Read a note by ID
    func read(id: UUID) async throws -> Note?

    /// List all non-deleted notes
    func list() async throws -> [Note]

    /// Search notes using text query
    func search(query: String) async throws -> [Note]

    /// List trashed notes
    func listTrashed() async throws -> [Note]

    /// Restore a trashed note
    func restore(id: UUID) async throws

    /// Permanently delete a note
    func purge(id: UUID) async throws
}

/// Service for managing notes with automatic search indexing
actor NoteService: NoteServiceProtocol {

    // MARK: - Dependencies

    private let repository: NoteRepository
    private let searchEngine: VectorSearchEngineProtocol
    private let embeddingService: EmbeddingServiceProtocol

    // MARK: - Initialization

    init(repository: NoteRepository,
         searchEngine: VectorSearchEngineProtocol,
         embeddingService: EmbeddingServiceProtocol) {
        self.repository = repository
        self.searchEngine = searchEngine
        self.embeddingService = embeddingService
    }

    // MARK: - NoteServiceProtocol Implementation

    func create(note: Note) async throws -> Note {
        // Save to repository first
        let createdNote = try await repository.create(note: note)

        // Index for search (non-blocking - log errors but don't fail creation)
        await indexNote(createdNote)

        return createdNote
    }

    func update(note: Note) async throws -> Note {
        // Update in repository first
        let updatedNote = try await repository.update(note: note)

        // Re-index for search (non-blocking)
        await indexNote(updatedNote)

        return updatedNote
    }

    func delete(id: UUID) async throws {
        // Soft delete in repository
        try await repository.delete(id: id)

        // Remove from search index
        await searchEngine.removeNote(id: id)
    }

    func read(id: UUID) async throws -> Note? {
        return try await repository.read(id: id)
    }

    func list() async throws -> [Note] {
        return try await repository.list()
    }

    func search(query: String) async throws -> [Note] {
        return try await repository.search(query: query)
    }

    func listTrashed() async throws -> [Note] {
        return try await repository.listTrashed()
    }

    func restore(id: UUID) async throws {
        try await repository.restore(id: id)

        // Re-index the restored note
        if let note = try await repository.read(id: id) {
            await indexNote(note)
        }
    }

    func purge(id: UUID) async throws {
        // Hard delete from repository
        try await repository.purge(id: id)

        // Remove from search index
        await searchEngine.removeNote(id: id)
    }

    // MARK: - Private Helpers

    /// Index a note for vector search
    private func indexNote(_ note: Note) async {
        do {
            // Generate embedding for note content
            let embedding = try await embeddingService.generateEmbedding(for: note.content)

            // Index in search engine
            try await searchEngine.indexNote(id: note.id, embedding: embedding)

            Logger.info("Indexed note \(note.id)", category: .database)
        } catch {
            // Log but don't fail the operation
            Logger.error("Failed to index note \(note.id): \(error.localizedDescription)", category: .database)
        }
    }
}
