// ABOUTME: Tests for NoteRepository protocol and InMemoryNoteRepository implementation
// ABOUTME: Validates CRUD operations, search functionality, and thread safety

import Testing
import Foundation
@testable import Template_App

struct NoteRepositoryTests {

    // MARK: - Create Tests

    @Test func createNoteSuccessfully() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Test content",
            title: "Test"
        )

        let createdNote = try await repository.create(note: note)

        #expect(createdNote.id == note.id)
        #expect(createdNote.title == note.title)
        #expect(createdNote.content == note.content)
    }

    @Test func createDuplicateNoteFails() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Test content",
            title: "Test"
        )

        // Create once - should succeed
        _ = try await repository.create(note: note)

        // Create again with same ID - should fail
        await #expect(throws: RepositoryError.duplicateNote) {
            try await repository.create(note: note)
        }
    }

    // MARK: - Read Tests

    @Test func readExistingNote() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Test content",
            title: "Test"
        )

        _ = try await repository.create(note: note)

        let retrievedNote = try await repository.read(id: note.id)

        #expect(retrievedNote != nil)
        #expect(retrievedNote?.id == note.id)
        #expect(retrievedNote?.title == note.title)
    }

    @Test func readNonExistentNoteReturnsNil() async throws {
        let repository = InMemoryNoteRepository()

        let nonExistentId = UUID()
        let retrievedNote = try await repository.read(id: nonExistentId)

        #expect(retrievedNote == nil)
    }

    // MARK: - Update Tests

    @Test func updateExistingNote() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Original content",
            title: "Original"
        )

        _ = try await repository.create(note: note)

        var updatedNote = note
        updatedNote.content = "Updated content"
        updatedNote.title = "Updated"

        let result = try await repository.update(note: updatedNote)

        #expect(result.id == note.id)
        #expect(result.content == "Updated content")
        #expect(result.title == "Updated")

        // Verify persistence
        let retrieved = try await repository.read(id: note.id)
        #expect(retrieved?.content == "Updated content")
    }

    @Test func updateNonExistentNoteFails() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUID(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Test content",
            title: "Test"
        )

        await #expect(throws: RepositoryError.noteNotFound) {
            try await repository.update(note: note)
        }
    }

    // MARK: - Delete Tests

    @Test func deleteExistingNote() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Test content",
            title: "Test"
        )

        _ = try await repository.create(note: note)

        // Delete should succeed
        try await repository.delete(id: note.id)

        // Verify note is gone
        let retrieved = try await repository.read(id: note.id)
        #expect(retrieved == nil)
    }

    @Test func deleteNonExistentNoteSucceeds() async throws {
        let repository = InMemoryNoteRepository()

        let nonExistentId = UUID()

        // Delete non-existent note - should be idempotent (not throw)
        try await repository.delete(id: nonExistentId)

        // Should not throw - deletion is idempotent
        #expect(true)
    }

    // MARK: - List Tests

    @Test func listAllNotes() async throws {
        let repository = InMemoryNoteRepository()

        // Create multiple notes
        let note1 = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Content 1",
            title: "Note 1"
        )

        let note2 = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Content 2",
            title: "Note 2"
        )

        let note3 = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Content 3",
            title: "Note 3"
        )

        _ = try await repository.create(note: note1)
        _ = try await repository.create(note: note2)
        _ = try await repository.create(note: note3)

        let allNotes = try await repository.list()

        #expect(allNotes.count == 3)
        #expect(allNotes.contains { $0.id == note1.id })
        #expect(allNotes.contains { $0.id == note2.id })
        #expect(allNotes.contains { $0.id == note3.id })
    }

    @Test func listEmptyRepository() async throws {
        let repository = InMemoryNoteRepository()

        let allNotes = try await repository.list()

        #expect(allNotes.isEmpty)
    }

    // MARK: - Search Tests

    @Test func searchFindsMatchingNotes() async throws {
        let repository = InMemoryNoteRepository()

        let note1 = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "This is about Swift programming",
            title: "Swift Guide"
        )

        let note2 = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Learning Python basics",
            title: "Python Tutorial"
        )

        let note3 = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Swift UI components",
            title: "SwiftUI Reference"
        )

        _ = try await repository.create(note: note1)
        _ = try await repository.create(note: note2)
        _ = try await repository.create(note: note3)

        let results = try await repository.search(query: "Swift")

        #expect(results.count == 2)
        #expect(results.contains { $0.id == note1.id })
        #expect(results.contains { $0.id == note3.id })
    }

    @Test func searchReturnsEmptyForNoMatches() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "This is about Swift",
            title: "Swift Guide"
        )

        _ = try await repository.create(note: note)

        let results = try await repository.search(query: "Rust")

        #expect(results.isEmpty)
    }

    @Test func searchIsCaseInsensitive() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "This is about SWIFT programming",
            title: "Swift Guide"
        )

        _ = try await repository.create(note: note)

        let results = try await repository.search(query: "swift")

        #expect(results.count == 1)
        #expect(results.first?.id == note.id)
    }

    // MARK: - Thread Safety Tests

    @Test func concurrentAccessSafety() async throws {
        let repository = InMemoryNoteRepository()

        // Create multiple notes concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let note = Note(
                        id: UUIDv7.generate(),
                        created: Date(),
                        device: "iPhone",
                        location: nil,
                        content: "Content \(i)",
                        title: "Note \(i)"
                    )
                    _ = try? await repository.create(note: note)
                }
            }
        }

        // All notes should be created
        let allNotes = try await repository.list()
        #expect(allNotes.count == 50)
    }

    @Test func concurrentReadWriteSafety() async throws {
        let repository = InMemoryNoteRepository()

        // Create initial note
        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Original content",
            title: "Test Note"
        )
        _ = try await repository.create(note: note)

        // Perform concurrent reads and updates
        await withTaskGroup(of: Void.self) { group in
            // Readers
            for _ in 0..<25 {
                group.addTask {
                    _ = try? await repository.read(id: note.id)
                }
            }

            // Writers
            for i in 0..<25 {
                group.addTask {
                    var updatedNote = note
                    updatedNote.content = "Updated content \(i)"
                    _ = try? await repository.update(note: updatedNote)
                }
            }
        }

        // Should complete without crashes or data corruption
        let finalNote = try await repository.read(id: note.id)
        #expect(finalNote != nil)
    }

    // MARK: - Data Isolation Tests

    @Test func repositoryReturnsCopies() async throws {
        let repository = InMemoryNoteRepository()

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Original content",
            title: "Test"
        )

        _ = try await repository.create(note: note)

        var retrievedNote = try await repository.read(id: note.id)!
        retrievedNote.content = "Modified content"

        // Original in repository should be unchanged
        let originalNote = try await repository.read(id: note.id)
        #expect(originalNote?.content == "Original content")
    }
}
