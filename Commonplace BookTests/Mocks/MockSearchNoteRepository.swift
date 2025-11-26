// ABOUTME: Shared mock note repository for search testing
// ABOUTME: Provides in-memory note storage with search functionality for tests

import Foundation
@testable import Commonplace_Book

actor MockSearchNoteRepository: NoteRepository {
    private var notes: [UUID: Note] = [:]

    func addNote(_ note: Note) {
        notes[note.id] = note
    }

    func create(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }

    func read(id: UUID) async throws -> Note? {
        return notes[id]
    }

    func update(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }

    func delete(id: UUID) async throws {
        notes.removeValue(forKey: id)
    }

    func list() async throws -> [Note] {
        return Array(notes.values)
    }

    func search(query: String) async throws -> [Note] {
        return Array(notes.values).filter { note in
            (note.title ?? "").localizedCaseInsensitiveContains(query) ||
            note.content.localizedCaseInsensitiveContains(query)
        }
    }

    func listTrashed() async throws -> [Note] {
        return []
    }

    func restore(id: UUID) async throws {
        // No-op for search tests
    }

    func purge(id: UUID) async throws {
        notes.removeValue(forKey: id)
    }

    func clear() async {
        notes.removeAll()
    }

    func count() throws -> Int {
        return notes.count
    }

    func list(limit: Int, offset: Int) async throws -> [Note] {
        return Array(notes.values.dropFirst(offset).prefix(limit))
    }
}
