// ABOUTME: Tests for ManualNoteCreator service that creates notes from manual text input
// ABOUTME: Validates title generation, metadata addition, and note creation logic

import XCTest
@testable import Template_App

final class ManualNoteCreatorTests: XCTestCase {
    var creator: ManualNoteCreator!
    var mockRepository: InMemoryNoteRepository!
    var mockMetadataCollector: MockMetadataCollector!

    override func setUpWithError() throws {
        mockRepository = InMemoryNoteRepository()
        mockMetadataCollector = MockMetadataCollector()
        creator = ManualNoteCreator(
            repository: mockRepository,
            metadataCollector: mockMetadataCollector
        )
    }

    override func tearDownWithError() throws {
        creator = nil
        mockRepository = nil
        mockMetadataCollector = nil
    }

    // MARK: - Note Creation Tests

    func testCreateNoteWithTitle() async throws {
        // GIVEN title and content
        let title = "My Note Title"
        let content = "This is the note content."

        // WHEN creating note
        let note = try await creator.createNote(title: title, content: content)

        // THEN note has correct title and content
        XCTAssertEqual(note.title, title)
        XCTAssertEqual(note.content, content)
    }

    func testCreateNoteWithoutTitle() async throws {
        // GIVEN only content (no title)
        let content = "First line of content\nSecond line of content"

        // WHEN creating note with nil title
        let note = try await creator.createNote(title: nil, content: content)

        // THEN title is auto-generated from first line
        XCTAssertEqual(note.title, "First line of content")
        XCTAssertEqual(note.content, content)
    }

    func testCreateNoteWithEmptyTitle() async throws {
        // GIVEN empty title
        let content = "Some content here"

        // WHEN creating note with empty string title
        let note = try await creator.createNote(title: "", content: content)

        // THEN title is auto-generated
        XCTAssertEqual(note.title, "Some content here")
    }

    func testCreateNoteWithWhitespaceTitle() async throws {
        // GIVEN whitespace-only title
        let content = "Content goes here"

        // WHEN creating note with whitespace title
        let note = try await creator.createNote(title: "   ", content: content)

        // THEN title is auto-generated (whitespace trimmed)
        XCTAssertEqual(note.title, "Content goes here")
    }

    // MARK: - Auto-Title Generation Tests

    func testAutoTitleFromFirstLine() async throws {
        // GIVEN multi-line content
        let content = "This is the first line\nThis is the second line\nThird line"

        // WHEN creating note without title
        let note = try await creator.createNote(title: nil, content: content)

        // THEN title is first line
        XCTAssertEqual(note.title, "This is the first line")
    }

    func testAutoTitleStripsMarkdownHeaders() async throws {
        // GIVEN content starting with markdown header
        let content = "# Main Heading\nContent follows"

        // WHEN creating note without title
        let note = try await creator.createNote(title: nil, content: content)

        // THEN title has markdown stripped
        XCTAssertEqual(note.title, "Main Heading")
    }

    func testAutoTitleTrimsWhitespace() async throws {
        // GIVEN content with leading/trailing whitespace
        let content = "   Whitespace Title   \nMore content"

        // WHEN creating note without title
        let note = try await creator.createNote(title: nil, content: content)

        // THEN title is trimmed
        XCTAssertEqual(note.title, "Whitespace Title")
    }

    func testAutoTitleLimitedLength() async throws {
        // GIVEN very long first line
        let longTitle = String(repeating: "a", count: 150)
        let content = "\(longTitle)\nSecond line"

        // WHEN creating note without title
        let note = try await creator.createNote(title: nil, content: content)

        // THEN title is truncated to 100 characters
        XCTAssertEqual(note.title.count, 100)
    }

    func testAutoTitleFallbackToTimestamp() async throws {
        // GIVEN content with only whitespace on first line
        let content = "   \nSecond line with content"

        // WHEN creating note without title
        let note = try await creator.createNote(title: nil, content: content)

        // THEN title falls back to timestamp-based format
        XCTAssertTrue(note.title.contains("Note"))
    }

    // MARK: - Metadata Tests

    func testCreatedNoteHasDevice() async throws {
        // GIVEN metadata collector provides device
        mockMetadataCollector.device = "iPhone 15 Pro"

        // WHEN creating note
        let note = try await creator.createNote(title: "Test", content: "Content")

        // THEN note has device metadata
        XCTAssertEqual(note.device, "iPhone 15 Pro")
    }

    func testCreatedNoteHasTimestamp() async throws {
        // GIVEN metadata collector provides timestamp
        let now = Date()
        mockMetadataCollector.timestamp = now

        // WHEN creating note
        let note = try await creator.createNote(title: "Test", content: "Content")

        // THEN note has timestamp
        XCTAssertEqual(note.created, now)
    }

    func testCreatedNoteHasLocation() async throws {
        // GIVEN metadata collector provides location
        let location = Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0)
        mockMetadataCollector.location = location

        // WHEN creating note
        let note = try await creator.createNote(title: "Test", content: "Content")

        // THEN note has location
        XCTAssertNotNil(note.location)
        XCTAssertEqual(note.location?.latitude, 37.7749)
        XCTAssertEqual(note.location?.longitude, -122.4194)
    }

    func testCreatedNoteWithoutLocation() async throws {
        // GIVEN metadata collector has no location
        mockMetadataCollector.location = nil

        // WHEN creating note
        let note = try await creator.createNote(title: "Test", content: "Content")

        // THEN note has nil location
        XCTAssertNil(note.location)
    }

    // MARK: - Validation Tests

    func testEmptyContentThrowsError() async throws {
        // GIVEN empty content
        let content = ""

        // WHEN creating note with empty content
        // THEN error is thrown
        do {
            _ = try await creator.createNote(title: "Title", content: content)
            XCTFail("Should have thrown error for empty content")
        } catch ManualNoteCreatorError.emptyContent {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testWhitespaceOnlyContentThrowsError() async throws {
        // GIVEN whitespace-only content
        let content = "   \n  \n   "

        // WHEN creating note with whitespace content
        // THEN error is thrown
        do {
            _ = try await creator.createNote(title: "Title", content: content)
            XCTFail("Should have thrown error for whitespace-only content")
        } catch ManualNoteCreatorError.emptyContent {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Repository Integration Tests

    func testCreatedNoteSavedToRepository() async throws {
        // GIVEN title and content
        let title = "Test Note"
        let content = "Test content"

        // WHEN creating note
        let note = try await creator.createNote(title: title, content: content)

        // THEN note is saved to repository
        let retrieved = try await mockRepository.read(id: note.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, title)
        XCTAssertEqual(retrieved?.content, content)
    }

    func testCreatedNoteHasUUID() async throws {
        // WHEN creating note
        let note = try await creator.createNote(title: "Test", content: "Content")

        // THEN note has valid UUID
        XCTAssertNotNil(note.id)
    }
}

// MARK: - Mock Metadata Collector

class MockMetadataCollector: MetadataCollector {
    var device: String = "Test Device"
    var timestamp: Date = Date()
    var location: Location?

    override func getCurrentDevice() -> String {
        return device
    }

    override func generateTimestamp() -> Date {
        return timestamp
    }

    override func getCurrentLocation() async -> Location? {
        return location
    }
}
