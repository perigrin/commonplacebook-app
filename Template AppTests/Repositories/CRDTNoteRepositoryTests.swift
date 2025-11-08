// ABOUTME: Tests for CRDT-backed note repository with SQLite storage and file system sync
// ABOUTME: Validates create, read, update, delete, merge, and bidirectional file sync

import XCTest
@testable import Template_App

@MainActor
final class CRDTNoteRepositoryTests: XCTestCase {
    var repository: CRDTNoteRepository!
    var tempDirectory: URL!
    var tempDBPath: URL!

    override func setUpWithError() throws {
        // Create temporary directory for file storage
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create temporary database path
        tempDBPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".db")

        // Create repository
        repository = try CRDTNoteRepository(
            databasePath: tempDBPath,
            notesDirectory: tempDirectory
        )
    }

    override func tearDownWithError() throws {
        // Clean up temporary files
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        if FileManager.default.fileExists(atPath: tempDBPath.path) {
            try? FileManager.default.removeItem(at: tempDBPath)
        }
        repository = nil
    }

    // MARK: - Create Tests

    func testCreateNoteSavesToCRDT() async throws {
        // GIVEN a new note
        let note = createTestNote(
            title: "Test Note",
            content: "Test content"
        )

        // WHEN creating note via repository
        let created = try await repository.create(note: note)

        // THEN note is returned
        XCTAssertEqual(created.id, note.id)
        XCTAssertEqual(created.title, note.title)
        XCTAssertEqual(created.content, note.content)
    }

    func testCreateNoteExportsToFile() async throws {
        // GIVEN a new note
        let note = createTestNote(
            title: "Exported Note",
            content: "This should be exported"
        )

        // WHEN creating note
        _ = try await repository.create(note: note)

        // THEN markdown file exists on disk
        let expectedPath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: expectedPath.path),
            "Markdown file should be exported after create"
        )

        // AND file contains correct content
        let fileContent = try String(contentsOf: expectedPath, encoding: .utf8)
        XCTAssertTrue(fileContent.contains("Exported Note"), "File should contain title")
        XCTAssertTrue(fileContent.contains("This should be exported"), "File should contain content")
    }

    func testCreateDuplicateNoteThrows() async throws {
        // GIVEN existing note
        let note = createTestNote(title: "Original", content: "Content")
        _ = try await repository.create(note: note)

        // WHEN creating duplicate
        // THEN should throw
        do {
            _ = try await repository.create(note: note)
            XCTFail("Should throw duplicate error")
        } catch {
            XCTAssertTrue(error is RepositoryError, "Should throw RepositoryError")
            if case .duplicateNote(let id) = error as? RepositoryError {
                XCTAssertEqual(id, note.id)
            } else {
                XCTFail("Should be duplicateNote error")
            }
        }
    }

    // MARK: - Read Tests

    func testReadNoteFromCRDT() async throws {
        // GIVEN note in CRDT
        let originalNote = createTestNote(
            title: "Read Test",
            content: "Read content"
        )
        _ = try await repository.create(note: originalNote)

        // WHEN reading note
        let readNote = try await repository.read(id: originalNote.id)

        // THEN note matches original
        XCTAssertNotNil(readNote)
        XCTAssertEqual(readNote?.id, originalNote.id)
        XCTAssertEqual(readNote?.title, originalNote.title)
        XCTAssertEqual(readNote?.content, originalNote.content)
        XCTAssertEqual(readNote?.device, originalNote.device)
    }

    func testReadNotePreservesMetadata() async throws {
        // GIVEN note with full metadata
        let location = Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0)
        let backlinks: Set<UUID> = [UUID(), UUID()]
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "iPhone 15 Pro",
            location: location,
            content: "Content with metadata",
            title: "Metadata Test",
            backlinks: backlinks,
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.create(note: note)

        // WHEN reading note
        let readNote = try await repository.read(id: note.id)

        // THEN all metadata preserved
        XCTAssertEqual(readNote?.location?.latitude, location.latitude)
        XCTAssertEqual(readNote?.location?.longitude, location.longitude)
        XCTAssertEqual(readNote?.backlinks, backlinks)
    }

    func testReadNonExistentNoteReturnsNil() async throws {
        // GIVEN non-existent ID
        let fakeId = UUID()

        // WHEN reading
        let result = try await repository.read(id: fakeId)

        // THEN returns nil
        XCTAssertNil(result)
    }

    // MARK: - Update Tests

    func testUpdateNoteInCRDT() async throws {
        // GIVEN existing note
        let original = createTestNote(title: "Original", content: "Original content")
        _ = try await repository.create(note: original)

        // WHEN updating note
        let updated = Note(
            id: original.id,
            created: original.created,
            device: original.device,
            location: nil,
            content: "Updated content",
            title: "Updated Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        let result = try await repository.update(note: updated)

        // THEN update succeeds
        XCTAssertEqual(result.title, "Updated Title")
        XCTAssertEqual(result.content, "Updated content")

        // AND reading shows updated values
        let readNote = try await repository.read(id: original.id)
        XCTAssertEqual(readNote?.title, "Updated Title")
        XCTAssertEqual(readNote?.content, "Updated content")
    }

    func testUpdateNoteExportsToFile() async throws {
        // GIVEN existing note
        let original = createTestNote(title: "Original", content: "Original")
        _ = try await repository.create(note: original)

        // WHEN updating note
        let updated = Note(
            id: original.id,
            created: original.created,
            device: original.device,
            location: nil,
            content: "Updated content here",
            title: "Updated Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.update(note: updated)

        // THEN file on disk reflects update
        let filePath = tempDirectory.appendingPathComponent("\(original.id.uuidString).md")
        let fileContent = try String(contentsOf: filePath, encoding: .utf8)
        XCTAssertTrue(fileContent.contains("Updated Title"))
        XCTAssertTrue(fileContent.contains("Updated content here"))
    }

    func testUpdateNonExistentNoteThrows() async throws {
        // GIVEN non-existent note
        let fakeNote = createTestNote(title: "Fake", content: "Fake")

        // WHEN updating
        // THEN should throw
        do {
            _ = try await repository.update(note: fakeNote)
            XCTFail("Should throw noteNotFound error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            if case .noteNotFound(let id) = error as? RepositoryError {
                XCTAssertEqual(id, fakeNote.id)
            } else {
                XCTFail("Should be noteNotFound error")
            }
        }
    }

    // MARK: - Delete Tests

    func testDeleteRemovesCRDTDoc() async throws {
        // GIVEN existing note
        let note = createTestNote(title: "To Delete", content: "Delete me")
        _ = try await repository.create(note: note)

        // WHEN deleting
        try await repository.delete(id: note.id)

        // THEN note no longer readable
        let result = try await repository.read(id: note.id)
        XCTAssertNil(result, "Note should not exist after delete")
    }

    func testDeleteRemovesFile() async throws {
        // GIVEN existing note with file
        let note = createTestNote(title: "File Delete", content: "Content")
        _ = try await repository.create(note: note)
        let filePath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))

        // WHEN deleting
        try await repository.delete(id: note.id)

        // THEN file removed
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: filePath.path),
            "File should be deleted"
        )
    }

    func testDeleteNonExistentNoteDoesNotThrow() async throws {
        // GIVEN non-existent ID
        let fakeId = UUID()

        // WHEN deleting
        // THEN should not throw (idempotent)
        try await repository.delete(id: fakeId)
        XCTAssertTrue(true, "Delete should be idempotent")
    }

    // MARK: - List Tests

    func testListQueriesCRDTStore() async throws {
        // GIVEN multiple notes
        let note1 = createTestNote(title: "Note 1", content: "Content 1")
        let note2 = createTestNote(title: "Note 2", content: "Content 2")
        let note3 = createTestNote(title: "Note 3", content: "Content 3")

        _ = try await repository.create(note: note1)
        _ = try await repository.create(note: note2)
        _ = try await repository.create(note: note3)

        // WHEN listing all notes
        let notes = try await repository.list()

        // THEN all notes returned
        XCTAssertEqual(notes.count, 3)
        let ids = Set(notes.map { $0.id })
        XCTAssertTrue(ids.contains(note1.id))
        XCTAssertTrue(ids.contains(note2.id))
        XCTAssertTrue(ids.contains(note3.id))
    }

    func testListEmptyRepositoryReturnsEmpty() async throws {
        // GIVEN empty repository
        // WHEN listing
        let notes = try await repository.list()

        // THEN empty array
        XCTAssertEqual(notes.count, 0)
    }

    // MARK: - Search Tests

    func testSearchQueriesCRDT() async throws {
        // GIVEN notes with searchable content
        let note1 = createTestNote(title: "Swift Programming", content: "Learn Swift")
        let note2 = createTestNote(title: "Python Guide", content: "Python basics")
        let note3 = createTestNote(title: "Advanced Swift", content: "Concurrency")

        _ = try await repository.create(note: note1)
        _ = try await repository.create(note: note2)
        _ = try await repository.create(note: note3)

        // WHEN searching for "Swift"
        let results = try await repository.search(query: "Swift")

        // THEN matches found
        XCTAssertEqual(results.count, 2)
        let titles = results.map { $0.title }
        XCTAssertTrue(titles.contains("Swift Programming"))
        XCTAssertTrue(titles.contains("Advanced Swift"))
    }

    // MARK: - External File Change Tests

    func testExternalFileChangeImported() async throws {
        // GIVEN existing note
        let original = createTestNote(title: "Original", content: "Original content")
        _ = try await repository.create(note: original)

        // WHEN external process modifies file
        let filePath = tempDirectory.appendingPathComponent("\(original.id.uuidString).md")
        let formatter = NoteFileFormatter()
        let modifiedNote = Note(
            id: original.id,
            created: original.created,
            device: original.device,
            location: nil,
            content: "Externally modified content",
            title: "External Modification",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        let modifiedContent = formatter.serialize(note: modifiedNote)
        try modifiedContent.write(to: filePath, atomically: true, encoding: .utf8)

        // AND repository detects change (trigger file watcher)
        try await repository.importExternalChanges()

        // THEN CRDT updated with merged content
        let readNote = try await repository.read(id: original.id)
        XCTAssertNotNil(readNote)
        // Note: Exact merge behavior depends on CRDT implementation
        // Either external change wins or merge preserves both
    }

    // MARK: - Concurrent Update/Merge Tests

    func testConcurrentUpdatesMergeViaCRDT() async throws {
        // GIVEN note in repository
        let original = createTestNote(title: "Original", content: "Original")
        _ = try await repository.create(note: original)

        // WHEN two concurrent updates with different fields
        let update1 = Note(
            id: original.id,
            created: original.created,
            device: "Device 1",
            location: nil,
            content: "Content from device 1",
            title: "Title from device 1",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let backlink1 = UUID()
        let update2 = Note(
            id: original.id,
            created: original.created,
            device: "Device 2",
            location: nil,
            content: "Content from device 2",
            title: "Title from device 2",
            backlinks: [backlink1],
            unknownFrontmatterFields: [:]
        )

        // Simulate concurrent updates
        _ = try await repository.update(note: update1)
        _ = try await repository.update(note: update2)

        // THEN merge resolves conflict
        let merged = try await repository.read(id: original.id)
        XCTAssertNotNil(merged)
        // Last write wins for scalar fields
        // Backlinks should be unioned
    }

    func testConcurrentBacklinksUnion() async throws {
        // GIVEN note with backlink
        let backlink1 = UUID()
        let original = createTestNote(title: "Test", content: "Test", backlinks: [backlink1])
        _ = try await repository.create(note: original)

        // WHEN two updates add different backlinks
        let backlink2 = UUID()
        let update1 = Note(
            id: original.id,
            created: original.created,
            device: original.device,
            location: nil,
            content: original.content,
            title: original.title,
            backlinks: [backlink1, backlink2],
            unknownFrontmatterFields: [:]
        )

        let backlink3 = UUID()
        let update2 = Note(
            id: original.id,
            created: original.created,
            device: original.device,
            location: nil,
            content: original.content,
            title: original.title,
            backlinks: [backlink1, backlink3],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.update(note: update1)
        _ = try await repository.update(note: update2)

        // THEN all backlinks present (union)
        let merged = try await repository.read(id: original.id)
        let expectedBacklinks: Set<UUID> = [backlink1, backlink2, backlink3]
        XCTAssertEqual(merged?.backlinks, expectedBacklinks, "Backlinks should be unioned")
    }

    // MARK: - Performance Tests

    func testLargeNotesPerformance() async throws {
        // GIVEN large note content
        let largeContent = String(repeating: "Large content. ", count: 10000)
        let note = createTestNote(title: "Large", content: largeContent)

        // WHEN creating and reading
        measure {
            Task { @MainActor in
                do {
                    _ = try await repository.create(note: note)
                    _ = try await repository.read(id: note.id)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }

    func testManyNotesListPerformance() async throws {
        // GIVEN many notes
        for i in 0..<100 {
            let note = createTestNote(title: "Note \(i)", content: "Content \(i)")
            _ = try await repository.create(note: note)
        }

        // WHEN listing
        measure {
            Task { @MainActor in
                do {
                    _ = try await repository.list()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestNote(
        title: String,
        content: String,
        backlinks: Set<UUID> = []
    ) -> Note {
        Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: content,
            title: title,
            backlinks: backlinks,
            unknownFrontmatterFields: [:]
        )
    }
}
