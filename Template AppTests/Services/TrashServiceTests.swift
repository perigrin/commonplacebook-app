// ABOUTME: Tests for trash management service
// ABOUTME: Validates soft delete, restore, purge, and auto-purge functionality

import XCTest
@testable import Template_App

@MainActor
final class TrashServiceTests: XCTestCase {
    var trashService: TrashService!
    var mockRepository: MockNoteRepository!

    override func setUpWithError() throws {
        mockRepository = MockNoteRepository()
        trashService = TrashService(repository: mockRepository)
    }

    override func tearDownWithError() throws {
        trashService = nil
        mockRepository = nil
    }

    // MARK: - List Trashed Tests

    func testListTrashedReturnsDeletedNotes() async throws {
        // GIVEN repository with deleted and non-deleted notes
        let deletedNote = createTestNote(title: "Deleted", deletedAt: Date())
        let activeNote = createTestNote(title: "Active", deletedAt: nil)

        mockRepository.notes = [deletedNote, activeNote]

        // WHEN listing trashed notes
        let trashed = try await trashService.listTrashed()

        // THEN should return only deleted note
        XCTAssertEqual(trashed.count, 1, "Should return 1 trashed note")
        XCTAssertEqual(trashed.first?.id, deletedNote.id)
    }

    func testListTrashedReturnsEmptyWhenNoDeleted() async throws {
        // GIVEN repository with only active notes
        let activeNote = createTestNote(title: "Active", deletedAt: nil)
        mockRepository.notes = [activeNote]

        // WHEN listing trashed notes
        let trashed = try await trashService.listTrashed()

        // THEN should return empty array
        XCTAssertEqual(trashed.count, 0, "Should return no trashed notes")
    }

    // MARK: - Restore Tests

    func testRestoreNoteRemovesDeletedAt() async throws {
        // GIVEN a deleted note
        let deletedNote = createTestNote(title: "Deleted", deletedAt: Date())
        mockRepository.notes = [deletedNote]

        // WHEN restoring the note
        try await trashService.restore(id: deletedNote.id)

        // THEN should clear deletedAt
        let restored = try await mockRepository.read(id: deletedNote.id)
        XCTAssertNotNil(restored, "Note should exist")
        XCTAssertNil(restored?.deletedAt, "deletedAt should be nil after restore")
        XCTAssertFalse(restored!.isDeleted, "Note should not be deleted")
    }

    func testRestoreNonExistentNoteFails() async throws {
        // GIVEN empty repository
        mockRepository.notes = []

        // WHEN restoring non-existent note
        do {
            try await trashService.restore(id: UUID())
            XCTFail("Should throw error for non-existent note")
        } catch {
            // THEN should throw noteNotFound error
            XCTAssertTrue(error is RepositoryError)
        }
    }

    // MARK: - Purge Tests

    func testPurgeRemovesNoteCompletely() async throws {
        // GIVEN a deleted note
        let deletedNote = createTestNote(title: "Deleted", deletedAt: Date())
        mockRepository.notes = [deletedNote]

        // WHEN purging the note
        try await trashService.purge(id: deletedNote.id)

        // THEN should hard delete
        let note = try await mockRepository.read(id: deletedNote.id)
        XCTAssertNil(note, "Note should not exist after purge")
    }

    func testPurgeIsIdempotent() async throws {
        // GIVEN non-existent note
        let noteId = UUID()

        // WHEN purging non-existent note
        // THEN should not throw
        try await trashService.purge(id: noteId)
    }

    // MARK: - Auto-Purge Tests

    func testAutoPurgeAfterDefaultsTo30Days() async throws {
        // WHEN creating trash service
        // THEN default should be 30 days
        XCTAssertEqual(
            trashService.autoPurgeAfter,
            30 * 24 * 60 * 60,
            "Default auto-purge should be 30 days"
        )
    }

    func testSetAutoPurgeAfterPersists() async throws {
        // GIVEN custom purge duration
        let customDuration: TimeInterval = 7 * 24 * 60 * 60  // 7 days

        // WHEN setting auto-purge duration
        await trashService.setAutoPurgeAfter(customDuration)

        // THEN should persist
        XCTAssertEqual(trashService.autoPurgeAfter, customDuration)

        // AND should persist across instances
        let newService = TrashService(repository: mockRepository)
        XCTAssertEqual(newService.autoPurgeAfter, customDuration)
    }

    func testPurgeOldDeletesNotesOlderThanThreshold() async throws {
        // GIVEN notes deleted at different times
        let now = Date()
        let oldDeleted = createTestNote(
            title: "Old",
            deletedAt: now.addingTimeInterval(-31 * 24 * 60 * 60)  // 31 days ago
        )
        let recentDeleted = createTestNote(
            title: "Recent",
            deletedAt: now.addingTimeInterval(-5 * 24 * 60 * 60)  // 5 days ago
        )
        mockRepository.notes = [oldDeleted, recentDeleted]

        // WHEN purging old notes
        let purgeCount = try await trashService.purgeOld()

        // THEN should purge old note
        XCTAssertEqual(purgeCount, 1, "Should purge 1 old note")

        let remaining = try await trashService.listTrashed()
        XCTAssertEqual(remaining.count, 1, "Should have 1 note remaining")
        XCTAssertEqual(remaining.first?.id, recentDeleted.id, "Recent note should remain")
    }

    func testPurgeOldRespectsCustomThreshold() async throws {
        // GIVEN custom 7-day threshold
        await trashService.setAutoPurgeAfter(7 * 24 * 60 * 60)

        // AND notes deleted at different times
        let now = Date()
        let old8Days = createTestNote(
            title: "8 days old",
            deletedAt: now.addingTimeInterval(-8 * 24 * 60 * 60)
        )
        let old5Days = createTestNote(
            title: "5 days old",
            deletedAt: now.addingTimeInterval(-5 * 24 * 60 * 60)
        )
        mockRepository.notes = [old8Days, old5Days]

        // WHEN purging old notes
        let purgeCount = try await trashService.purgeOld()

        // THEN should purge note older than 7 days
        XCTAssertEqual(purgeCount, 1, "Should purge 1 note")

        let remaining = try await trashService.listTrashed()
        XCTAssertEqual(remaining.first?.id, old5Days.id, "5-day-old note should remain")
    }

    func testPurgeOldReturnsZeroWhenNoOldNotes() async throws {
        // GIVEN no old notes
        let recentDeleted = createTestNote(
            title: "Recent",
            deletedAt: Date().addingTimeInterval(-5 * 24 * 60 * 60)
        )
        mockRepository.notes = [recentDeleted]

        // WHEN purging old notes
        let purgeCount = try await trashService.purgeOld()

        // THEN should purge nothing
        XCTAssertEqual(purgeCount, 0, "Should not purge recent notes")
    }

    // MARK: - Helper Methods

    private func createTestNote(title: String, deletedAt: Date?) -> Note {
        return Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "Test content for \(title)",
            title: title,
            backlinks: [],
            unknownFrontmatterFields: [:],
            modified: Date(),
            deletedAt: deletedAt
        )
    }
}

// MARK: - Mock Repository

class MockNoteRepository: NoteRepository {
    var notes: [Note] = []

    func create(note: Note) async throws -> Note {
        if notes.contains(where: { $0.id == note.id }) {
            throw RepositoryError.duplicateNote(note.id)
        }
        notes.append(note)
        return note
    }

    func read(id: UUID) async throws -> Note? {
        return notes.first(where: { $0.id == id })
    }

    func update(note: Note) async throws -> Note {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else {
            throw RepositoryError.noteNotFound(note.id)
        }
        notes[index] = note
        return note
    }

    func delete(id: UUID) async throws {
        guard let index = notes.firstIndex(where: { $0.id == id }) else {
            return  // Idempotent
        }
        var note = notes[index]
        note.deletedAt = Date()
        notes[index] = note
    }

    func list() async throws -> [Note] {
        return notes.filter { !$0.isDeleted }
    }

    func search(query: String) async throws -> [Note] {
        return notes.filter { note in
            !note.isDeleted &&
            (note.title.localizedCaseInsensitiveContains(query) ||
             note.content.localizedCaseInsensitiveContains(query))
        }
    }

    func listTrashed() async throws -> [Note] {
        return notes.filter { $0.isDeleted }
    }

    func restore(id: UUID) async throws {
        guard let index = notes.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.noteNotFound(id)
        }
        var note = notes[index]
        note.deletedAt = nil
        notes[index] = note
    }

    func purge(id: UUID) async throws {
        notes.removeAll(where: { $0.id == id })
    }
}
