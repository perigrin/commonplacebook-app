// ABOUTME: Shared mock note service for testing
// ABOUTME: Wraps a note repository and provides NoteServiceProtocol interface for tests

import Foundation
@testable import Commonplace_Book

actor MockNoteService: NoteServiceProtocol {
    private let repository: NoteRepository

    init(repository: NoteRepository) {
        self.repository = repository
    }

    func create(note: Note) async throws -> Note {
        return try await repository.create(note: note)
    }

    func read(id: UUID) async throws -> Note? {
        return try await repository.read(id: id)
    }

    func update(note: Note) async throws -> Note {
        return try await repository.update(note: note)
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
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
    }

    func purge(id: UUID) async throws {
        try await repository.purge(id: id)
    }
}
