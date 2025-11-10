// ABOUTME: Tests for file system-based note repository
// ABOUTME: Covers disk persistence, atomic writes, directory management, and concurrent access

import XCTest
@testable import CommonplaceBook

final class FileSystemNoteRepositoryTests: XCTestCase {

    var tempDirectory: URL!
    var repository: FileSystemNoteRepository!
    var formatter: NoteFileFormatter!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        formatter = NoteFileFormatter()
        repository = await FileSystemNoteRepository(directory: tempDirectory)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }

        try await super.tearDown()
    }

    // MARK: - Create Tests

    func testCreateNoteWritesFileToDisk() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Test content",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // When
        _ = try await repository.create(note: note)

        // Then
        let expectedPath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path),
                      "Note file should exist on disk")
    }

    func testCreateNoteHasCorrectFileName() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Test content",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // When
        _ = try await repository.create(note: note)

        // Then
        let expectedFileName = "\(note.id.uuidString).md"
        let files = try FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)
        XCTAssertTrue(files.contains(expectedFileName),
                      "File name should be <uuid>.md")
    }

    func testCreateNoteFileContentMatchesSerialization() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
            content: "# Test Note\n\nThis is test content.",
            title: "Test Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // When
        _ = try await repository.create(note: note)

        // Then
        let filePath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        let fileContent = try String(contentsOf: filePath, encoding: .utf8)
        let expectedContent = formatter.serialize(note: note)
        XCTAssertEqual(fileContent, expectedContent,
                       "File content should match serialization")
    }

    func testCreateDuplicateNoteThrowsError() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Test",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.create(note: note)

        // When/Then
        do {
            _ = try await repository.create(note: note)
            XCTFail("Should throw duplicateNote error")
        } catch let error as RepositoryError {
            if case .duplicateNote(let id) = error {
                XCTAssertEqual(id, note.id)
            } else {
                XCTFail("Should throw duplicateNote error, got \(error)")
            }
        }
    }

    // MARK: - Read Tests

    func testReadNoteFromExistingFile() async throws {
        // Given
        let originalNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
            content: "# Original\n\nContent here.",
            title: "Original",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // Write file directly to disk
        let filePath = tempDirectory.appendingPathComponent("\(originalNote.id.uuidString).md")
        let content = formatter.serialize(note: originalNote)
        try content.write(to: filePath, atomically: true, encoding: .utf8)

        // When
        let readNote = try await repository.read(id: originalNote.id)

        // Then
        XCTAssertNotNil(readNote, "Should read note from disk")
        XCTAssertEqual(readNote?.id, originalNote.id)
        XCTAssertEqual(readNote?.content, originalNote.content)
        XCTAssertEqual(readNote?.title, originalNote.title)
    }

    func testReadNonExistentNoteReturnsNil() async throws {
        // Given
        let nonExistentId = UUID()

        // When
        let note = try await repository.read(id: nonExistentId)

        // Then
        XCTAssertNil(note, "Should return nil for non-existent note")
    }

    func testReadCorruptFileThrowsError() async throws {
        // Given
        let noteId = UUID()
        let filePath = tempDirectory.appendingPathComponent("\(noteId.uuidString).md")

        // Write corrupt content (invalid YAML frontmatter)
        try "This is not valid frontmatter".write(to: filePath, atomically: true, encoding: .utf8)

        // When/Then
        do {
            _ = try await repository.read(id: noteId)
            XCTFail("Should throw error for corrupt file")
        } catch {
            // Expected - corrupt file should throw
            XCTAssertTrue(error is NoteFileFormatterError || error is RepositoryError)
        }
    }

    // MARK: - Update Tests

    func testUpdateNoteOverwritesFile() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Original content",
            title: "Original",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.create(note: note)

        // When
        var updatedNote = note
        updatedNote.content = "Updated content"
        updatedNote.title = "Updated"
        _ = try await repository.update(note: updatedNote)

        // Then
        let filePath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        let fileContent = try String(contentsOf: filePath, encoding: .utf8)
        XCTAssertTrue(fileContent.contains("Updated content"),
                      "File should contain updated content")
        XCTAssertFalse(fileContent.contains("Original content"),
                       "File should not contain original content")
    }

    func testUpdateNonExistentNoteThrowsError() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Test",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // When/Then
        do {
            _ = try await repository.update(note: note)
            XCTFail("Should throw noteNotFound error")
        } catch let error as RepositoryError {
            if case .noteNotFound(let id) = error {
                XCTAssertEqual(id, note.id)
            } else {
                XCTFail("Should throw noteNotFound error, got \(error)")
            }
        }
    }

    func testUpdateUsesAtomicWrites() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Original",
            title: "Original",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.create(note: note)

        // When
        var updated = note
        updated.content = "Updated"
        _ = try await repository.update(note: updated)

        // Then
        let filePath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        let content = try String(contentsOf: filePath, encoding: .utf8)

        // Atomic write means file is never in partial state
        // If we can read it, it should be complete and valid
        let parsedNote = try formatter.deserialize(content: content)
        XCTAssertEqual(parsedNote.content, "Updated")
    }

    // MARK: - Delete Tests

    func testDeleteNoteRemovesFile() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Test",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.create(note: note)
        let filePath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))

        // When
        try await repository.delete(id: note.id)

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath.path),
                       "File should be deleted")
    }

    func testDeleteIsIdempotent() async throws {
        // Given
        let noteId = UUID()

        // When/Then
        try await repository.delete(id: noteId)
        try await repository.delete(id: noteId) // Should not throw
    }

    // MARK: - List Tests

    func testListScansDirectoryAndReturnsAllNotes() async throws {
        // Given
        let note1 = Note(
            id: UUID(),
            created: Date(),
            device: "Device1",
            location: nil,
            content: "Content 1",
            title: "Note 1",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        let note2 = Note(
            id: UUID(),
            created: Date(),
            device: "Device2",
            location: nil,
            content: "Content 2",
            title: "Note 2",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        let note3 = Note(
            id: UUID(),
            created: Date(),
            device: "Device3",
            location: nil,
            content: "Content 3",
            title: "Note 3",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note1)
        _ = try await repository.create(note: note2)
        _ = try await repository.create(note: note3)

        // When
        let notes = try await repository.list()

        // Then
        XCTAssertEqual(notes.count, 3, "Should return all notes")
        XCTAssertTrue(notes.contains { $0.id == note1.id })
        XCTAssertTrue(notes.contains { $0.id == note2.id })
        XCTAssertTrue(notes.contains { $0.id == note3.id })
    }

    func testListReturnsEmptyArrayForEmptyDirectory() async throws {
        // When
        let notes = try await repository.list()

        // Then
        XCTAssertEqual(notes.count, 0, "Should return empty array")
    }

    // MARK: - Search Tests

    func testSearchWorksAcrossAllFiles() async throws {
        // Given
        let note1 = Note(
            id: UUID(),
            created: Date(),
            device: "Device1",
            location: nil,
            content: "Swift is a programming language",
            title: "Swift",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        let note2 = Note(
            id: UUID(),
            created: Date(),
            device: "Device2",
            location: nil,
            content: "Python is also a programming language",
            title: "Python",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        let note3 = Note(
            id: UUID(),
            created: Date(),
            device: "Device3",
            location: nil,
            content: "Rust is fast",
            title: "Rust",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try await repository.create(note: note1)
        _ = try await repository.create(note: note2)
        _ = try await repository.create(note: note3)

        // When
        let results = try await repository.search(query: "programming")

        // Then
        XCTAssertEqual(results.count, 2, "Should find notes containing 'programming'")
        XCTAssertTrue(results.contains { $0.id == note1.id })
        XCTAssertTrue(results.contains { $0.id == note2.id })
        XCTAssertFalse(results.contains { $0.id == note3.id })
    }

    func testSearchIsCaseInsensitive() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Device",
            location: nil,
            content: "UPPERCASE content",
            title: "Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.create(note: note)

        // When
        let results = try await repository.search(query: "uppercase")

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, note.id)
    }

    // MARK: - Directory Management Tests

    func testHandlesMissingDirectoryByCreatingIt() async throws {
        // Given
        let newDirectory = tempDirectory.appendingPathComponent("new_subdir")
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDirectory.path))

        // When
        let newRepo = await FileSystemNoteRepository(directory: newDirectory)
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Device",
            location: nil,
            content: "Test",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await newRepo.create(note: note)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.path),
                      "Directory should be created")
        let filePath = newDirectory.appendingPathComponent("\(note.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path),
                      "Note should be created in new directory")
    }

    // MARK: - Concurrency Tests

    func testConcurrentWritesDoNotCorruptData() async throws {
        // Given
        let noteCount = 50
        var notes: [Note] = []

        for i in 0..<noteCount {
            notes.append(Note(
                id: UUID(),
                created: Date(),
                device: "Device\(i)",
                location: nil,
                content: "Content \(i)",
                title: "Note \(i)",
                backlinks: [],
                unknownFrontmatterFields: [:]
            ))
        }

        // When - Create all notes concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for note in notes {
                group.addTask {
                    _ = try await self.repository.create(note: note)
                }
            }
            try await group.waitForAll()
        }

        // Then - All notes should exist
        let savedNotes = try await repository.list()
        XCTAssertEqual(savedNotes.count, noteCount, "All notes should be saved")

        // Verify each note can be read and is not corrupted
        for note in notes {
            let filePath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
            let content = try String(contentsOf: filePath, encoding: .utf8)
            let parsedNote = try formatter.deserialize(content: content)
            XCTAssertEqual(parsedNote.id, note.id)
            XCTAssertEqual(parsedNote.content, note.content)
        }
    }

    func testConcurrentReadsAndWrites() async throws {
        // Given
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "Device",
            location: nil,
            content: "Initial content",
            title: "Initial",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        _ = try await repository.create(note: note)

        // When - Perform concurrent reads and writes
        try await withThrowingTaskGroup(of: Void.self) { group in
            // 25 concurrent reads
            for _ in 0..<25 {
                group.addTask {
                    _ = try await self.repository.read(id: note.id)
                }
            }

            // 25 concurrent updates
            for i in 0..<25 {
                group.addTask {
                    var updated = note
                    updated.content = "Updated \(i)"
                    _ = try await self.repository.update(note: updated)
                }
            }

            try await group.waitForAll()
        }

        // Then - Note should still be valid and not corrupted
        let finalNote = try await repository.read(id: note.id)
        XCTAssertNotNil(finalNote, "Note should still exist")
        XCTAssertEqual(finalNote?.id, note.id)

        // Verify file is not corrupted
        let filePath = tempDirectory.appendingPathComponent("\(note.id.uuidString).md")
        let content = try String(contentsOf: filePath, encoding: .utf8)
        _ = try formatter.deserialize(content: content) // Should not throw
    }

    func testConcurrentCacheLoadingDoesNotCauseRaceCondition() async throws {
        // Given - Create some notes on disk before creating repository
        let note1 = Note(
            id: UUID(),
            created: Date(),
            device: "Device1",
            location: nil,
            content: "Content 1",
            title: "Note 1",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        let note2 = Note(
            id: UUID(),
            created: Date(),
            device: "Device2",
            location: nil,
            content: "Content 2",
            title: "Note 2",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // Write notes directly to disk
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let content1 = formatter.serialize(note: note1)
        let content2 = formatter.serialize(note: note2)
        try content1.write(to: tempDirectory.appendingPathComponent("\(note1.id.uuidString).md"),
                          atomically: true, encoding: .utf8)
        try content2.write(to: tempDirectory.appendingPathComponent("\(note2.id.uuidString).md"),
                          atomically: true, encoding: .utf8)

        // Create a fresh repository that hasn't loaded cache yet
        let freshRepo = await FileSystemNoteRepository(directory: tempDirectory)

        // When - Trigger 50 concurrent operations that all require cache loading
        try await withThrowingTaskGroup(of: Note?.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    // Each of these will call loadCacheIfNeeded()
                    return try await freshRepo.read(id: note1.id)
                }
            }

            // Collect all results
            var results: [Note?] = []
            for try await result in group {
                results.append(result)
            }

            // Then - All reads should succeed and return the same note
            XCTAssertEqual(results.count, 50, "All concurrent reads should complete")
            for result in results {
                XCTAssertNotNil(result)
                XCTAssertEqual(result?.id, note1.id)
                XCTAssertEqual(result?.content, "Content 1")
            }
        }

        // Verify the cache was loaded correctly and contains both notes
        let allNotes = try await freshRepo.list()
        XCTAssertEqual(allNotes.count, 2, "Cache should contain both notes")
    }
}
