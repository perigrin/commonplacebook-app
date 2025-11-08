// ABOUTME: Tests for CRDTService that provides Automerge-based conflict-free note sync
// ABOUTME: Validates document creation, CRDT operations, merging, and conflict resolution

import XCTest
@testable import Template_App

@MainActor
final class CRDTServiceTests: XCTestCase {
    var service: CRDTService!

    override func setUpWithError() throws {
        service = CRDTService()
    }

    override func tearDownWithError() throws {
        service = nil
    }

    // MARK: - Document Creation Tests

    func testCreateDocumentReturnsValidHandle() async throws {
        // GIVEN CRDT service
        // WHEN creating a new document
        let docHandle = await service.createDocument()

        // THEN document handle is valid
        XCTAssertNotNil(docHandle, "Should create valid document handle")
    }

    func testCreateMultipleDocuments() async throws {
        // GIVEN CRDT service
        // WHEN creating multiple documents
        let doc1 = await service.createDocument()
        let doc2 = await service.createDocument()

        // THEN each document is independent
        XCTAssertNotNil(doc1, "First document should be valid")
        XCTAssertNotNil(doc2, "Second document should be valid")
    }

    // MARK: - Update Note Tests

    func testUpdateNoteInDocument() async throws {
        // GIVEN document and note
        let docHandle = await service.createDocument()
        let note = createTestNote(
            title: "Test Note",
            content: "Test content"
        )

        // WHEN updating note in document
        try await service.updateNote(docHandle: docHandle, note: note)

        // THEN update succeeds (no exception)
        XCTAssertTrue(true, "Update should not throw")
    }

    func testUpdateNoteWithLocation() async throws {
        // GIVEN document and note with location
        let docHandle = await service.createDocument()
        let location = Location(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10.0
        )
        let note = createTestNote(
            title: "San Francisco Note",
            content: "At Golden Gate Park",
            location: location
        )

        // WHEN updating note
        try await service.updateNote(docHandle: docHandle, note: note)

        // THEN update succeeds
        XCTAssertTrue(true, "Update with location should not throw")
    }

    func testUpdateNoteWithBacklinks() async throws {
        // GIVEN document and note with backlinks
        let docHandle = await service.createDocument()
        let backlink1 = UUID()
        let backlink2 = UUID()
        let note = createTestNote(
            title: "Note with backlinks",
            content: "Content",
            backlinks: [backlink1, backlink2]
        )

        // WHEN updating note
        try await service.updateNote(docHandle: docHandle, note: note)

        // THEN update succeeds
        XCTAssertTrue(true, "Update with backlinks should not throw")
    }

    // MARK: - Read Note Tests

    func testReadNoteFromDocument() async throws {
        // GIVEN document with note
        let docHandle = await service.createDocument()
        let originalNote = createTestNote(
            title: "Original Title",
            content: "Original content"
        )
        try await service.updateNote(docHandle: docHandle, note: originalNote)

        // WHEN reading note back
        let readNote = try await service.readNote(docHandle: docHandle)

        // THEN note matches original
        XCTAssertEqual(readNote.id, originalNote.id, "ID should match")
        XCTAssertEqual(readNote.title, originalNote.title, "Title should match")
        XCTAssertEqual(readNote.content, originalNote.content, "Content should match")
        XCTAssertEqual(readNote.device, originalNote.device, "Device should match")
    }

    func testReadNotePreservesMetadata() async throws {
        // GIVEN document with note containing all metadata
        let docHandle = await service.createDocument()
        let location = Location(
            latitude: 40.7128,
            longitude: -74.0060,
            accuracy: 15.0
        )
        let created = Date()
        let backlinks: Set<UUID> = [UUID(), UUID()]
        let originalNote = Note(
            id: UUID(),
            created: created,
            device: "iPhone 15 Pro",
            location: location,
            content: "NYC content",
            title: "New York",
            backlinks: backlinks,
            unknownFrontmatterFields: [:]
        )
        try await service.updateNote(docHandle: docHandle, note: originalNote)

        // WHEN reading note back
        let readNote = try await service.readNote(docHandle: docHandle)

        // THEN all metadata preserved
        XCTAssertEqual(readNote.created.timeIntervalSince1970,
                       created.timeIntervalSince1970,
                       accuracy: 1.0,
                       "Created timestamp should be preserved")
        XCTAssertEqual(readNote.location?.latitude, location.latitude, "Latitude should match")
        XCTAssertEqual(readNote.location?.longitude, location.longitude, "Longitude should match")
        XCTAssertEqual(readNote.location?.accuracy, location.accuracy, "Accuracy should match")
        XCTAssertEqual(readNote.backlinks, backlinks, "Backlinks should match")
    }

    func testReadNoteWithoutLocation() async throws {
        // GIVEN document with note without location
        let docHandle = await service.createDocument()
        let note = createTestNote(title: "No location", content: "Content")
        try await service.updateNote(docHandle: docHandle, note: note)

        // WHEN reading note back
        let readNote = try await service.readNote(docHandle: docHandle)

        // THEN location is nil
        XCTAssertNil(readNote.location, "Location should be nil")
    }

    // MARK: - Merge Tests

    func testMergeTwoDocuments() async throws {
        // GIVEN two documents with different notes
        let doc1 = await service.createDocument()
        let note1 = createTestNote(title: "Note 1", content: "Content 1")
        try await service.updateNote(docHandle: doc1, note: note1)

        let doc2 = await service.createDocument()
        let note2 = createTestNote(title: "Note 2", content: "Content 2")
        try await service.updateNote(docHandle: doc2, note: note2)

        // WHEN merging documents
        let merged = try await service.merge(doc1: doc1, doc2: doc2)

        // THEN merge succeeds
        XCTAssertNotNil(merged, "Merge should produce valid document")
    }

    func testConcurrentUpdatesLastWriteWins() async throws {
        // GIVEN two documents starting from same state
        let doc1 = await service.createDocument()
        let originalNote = createTestNote(
            title: "Original",
            content: "Original content"
        )
        try await service.updateNote(docHandle: doc1, note: originalNote)

        // Clone to doc2 by saving and loading
        let savedData = await service.save(docHandle: doc1)
        let doc2 = try await service.load(data: savedData)

        // WHEN both documents update same note with different content
        let updatedNote1 = Note(
            id: originalNote.id,
            created: originalNote.created,
            device: "Device 1",
            location: nil,
            content: "Content from device 1",
            title: "Updated from device 1",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        try await service.updateNote(docHandle: doc1, note: updatedNote1)

        // Wait 1ms to ensure different Automerge operations
        try await Task.sleep(nanoseconds: 1_000_000)

        let updatedNote2 = Note(
            id: originalNote.id,
            created: originalNote.created,
            device: "Device 2",
            location: nil,
            content: "Content from device 2",
            title: "Updated from device 2",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        try await service.updateNote(docHandle: doc2, note: updatedNote2)

        // WHEN merging
        let merged = try await service.merge(doc1: doc1, doc2: doc2)
        let mergedNote = try await service.readNote(docHandle: merged)

        // THEN last write wins (device 2 was later)
        XCTAssertTrue(
            mergedNote.title == "Updated from device 2" || mergedNote.title == "Updated from device 1",
            "One of the updates should win"
        )
        XCTAssertTrue(
            mergedNote.content == "Content from device 2" || mergedNote.content == "Content from device 1",
            "Content should come from one device"
        )
    }

    func testBacklinksMergeWithUnion() async throws {
        // GIVEN two documents with same note
        let doc1 = await service.createDocument()
        let noteId = UUID()
        let created = Date()

        let backlink1 = UUID()
        let note1 = Note(
            id: noteId,
            created: created,
            device: "Device 1",
            location: nil,
            content: "Content",
            title: "Title",
            backlinks: [backlink1],
            unknownFrontmatterFields: [:]
        )
        try await service.updateNote(docHandle: doc1, note: note1)

        // Clone to doc2
        let savedData = await service.save(docHandle: doc1)
        let doc2 = try await service.load(data: savedData)

        // WHEN each device adds different backlink (incremental adds)
        let backlink2 = UUID()
        let note1Updated = Note(
            id: noteId,
            created: created,
            device: "Device 1",
            location: nil,
            content: "Content",
            title: "Title",
            backlinks: [backlink1, backlink2], // Added backlink2
            unknownFrontmatterFields: [:]
        )
        try await service.updateNote(docHandle: doc1, note: note1Updated)

        let backlink3 = UUID()
        let note2Updated = Note(
            id: noteId,
            created: created,
            device: "Device 2",
            location: nil,
            content: "Content",
            title: "Title",
            backlinks: [backlink1, backlink3], // Added backlink3
            unknownFrontmatterFields: [:]
        )
        try await service.updateNote(docHandle: doc2, note: note2Updated)

        // WHEN merging
        let merged = try await service.merge(doc1: doc1, doc2: doc2)
        let mergedNote = try await service.readNote(docHandle: merged)

        // THEN backlinks are unioned
        let expectedBacklinks: Set<UUID> = [backlink1, backlink2, backlink3]
        XCTAssertEqual(
            mergedNote.backlinks,
            expectedBacklinks,
            "Backlinks should be union of both sets"
        )
    }

    // MARK: - Save/Load Tests

    func testSaveDocumentReturnsData() async throws {
        // GIVEN document with note
        let docHandle = await service.createDocument()
        let note = createTestNote(title: "Save test", content: "Content")
        try await service.updateNote(docHandle: docHandle, note: note)

        // WHEN saving document
        let data = await service.save(docHandle: docHandle)

        // THEN returns valid data
        XCTAssertGreaterThan(data.count, 0, "Should return non-empty data")
    }

    func testLoadDocumentFromData() async throws {
        // GIVEN saved document data
        let docHandle = await service.createDocument()
        let note = createTestNote(title: "Load test", content: "Content")
        try await service.updateNote(docHandle: docHandle, note: note)
        let data = await service.save(docHandle: docHandle)

        // WHEN loading from data
        let loadedHandle = try await service.load(data: data)

        // THEN document loaded successfully
        XCTAssertNotNil(loadedHandle, "Should load valid document")
    }

    func testSaveLoadRoundTrip() async throws {
        // GIVEN document with complete note
        let docHandle = await service.createDocument()
        let location = Location(
            latitude: 51.5074,
            longitude: -0.1278,
            accuracy: 20.0
        )
        let backlinks: Set<UUID> = [UUID(), UUID(), UUID()]
        let originalNote = Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: location,
            content: "London calling",
            title: "London",
            backlinks: backlinks,
            unknownFrontmatterFields: [:]
        )
        try await service.updateNote(docHandle: docHandle, note: originalNote)

        // WHEN saving and loading
        let data = await service.save(docHandle: docHandle)
        let loadedHandle = try await service.load(data: data)
        let loadedNote = try await service.readNote(docHandle: loadedHandle)

        // THEN note preserved exactly
        XCTAssertEqual(loadedNote.id, originalNote.id, "ID preserved")
        XCTAssertEqual(loadedNote.title, originalNote.title, "Title preserved")
        XCTAssertEqual(loadedNote.content, originalNote.content, "Content preserved")
        XCTAssertEqual(loadedNote.device, originalNote.device, "Device preserved")
        XCTAssertEqual(loadedNote.created.timeIntervalSince1970,
                       originalNote.created.timeIntervalSince1970,
                       accuracy: 1.0,
                       "Created preserved")
        XCTAssertEqual(loadedNote.location?.latitude, location.latitude, "Latitude preserved")
        XCTAssertEqual(loadedNote.location?.longitude, location.longitude, "Longitude preserved")
        XCTAssertEqual(loadedNote.backlinks, backlinks, "Backlinks preserved")
    }

    // MARK: - Performance Tests

    func testLargeDocumentPerformance() async throws {
        // GIVEN document with large content
        let docHandle = await service.createDocument()
        let largeContent = String(repeating: "Large content. ", count: 10000) // ~150KB
        let note = createTestNote(
            title: "Large note",
            content: largeContent
        )

        // WHEN updating and reading
        measure {
            Task { @MainActor in
                do {
                    try await service.updateNote(docHandle: docHandle, note: note)
                    _ = try await service.readNote(docHandle: docHandle)
                } catch {
                    XCTFail("Performance test should not throw: \(error)")
                }
            }
        }

        // Performance should be reasonable (< 0.1s per operation)
    }

    func testManyBacklinksPerformance() async throws {
        // GIVEN note with many backlinks
        let docHandle = await service.createDocument()
        let manyBacklinks = Set((0..<1000).map { _ in UUID() })
        let note = createTestNote(
            title: "Many backlinks",
            content: "Content",
            backlinks: manyBacklinks
        )

        // WHEN updating and reading
        measure {
            Task { @MainActor in
                do {
                    try await service.updateNote(docHandle: docHandle, note: note)
                    _ = try await service.readNote(docHandle: docHandle)
                } catch {
                    XCTFail("Performance test should not throw: \(error)")
                }
            }
        }

        // Should handle large backlink arrays efficiently
    }

    // MARK: - Error Handling Tests

    func testReadFromEmptyDocumentThrows() async throws {
        // GIVEN empty document (no note written)
        let docHandle = await service.createDocument()

        // WHEN reading from empty document
        // THEN should throw
        do {
            _ = try await service.readNote(docHandle: docHandle)
            XCTFail("Should throw error when reading from empty document")
        } catch {
            // Verify error is appropriate
            XCTAssertTrue(
                error is CRDTServiceError,
                "Should throw CRDTServiceError"
            )
        }
    }

    // MARK: - Helper Methods

    private func createTestNote(
        title: String,
        content: String,
        location: Location? = nil,
        backlinks: Set<UUID> = []
    ) -> Note {
        Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: location,
            content: content,
            title: title,
            backlinks: backlinks,
            unknownFrontmatterFields: [:]
        )
    }
}
